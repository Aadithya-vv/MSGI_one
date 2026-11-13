// Render only. Never connects to Supabase or executes SQL.
const fs=require('node:fs');
const crypto=require('node:crypto');
function literal(value){return "'"+value.replaceAll("'","''")+"'";}
function name(value,max=160,min=2){if(typeof value!=='string'||value!==value.trim()||value.length<min||value.length>max||/[\u0000-\u001f]/.test(value))throw Error('Invalid catalog text');return value;}
function unique(values,key){const seen=new Set();for(const value of values){const k=key(value);if(seen.has(k))throw Error('Duplicate catalog entry');seen.add(k);}}
function render(data){
 if(data.project_ref!=='sbgshejyvkptmrffiwvd')throw Error('Unexpected project reference');
 for(const key of ['institutions','departments','skills','cities'])if(!Array.isArray(data[key]))throw Error('Missing catalog array');
 if(data.review_status==='APPROVED' && data.institutions.length && (!data.institutional_source?.trim() || !data.institutional_approver?.trim()))throw Error('Approved institutional source and approver required');
 if(data.review_status==='APPROVED' && data.cities.length && (!data.city_source?.trim() || !data.city_approver?.trim()))throw Error('Approved city source and approver required');
 data.institutions.forEach(x=>name(x));unique(data.institutions,x=>x.toLowerCase());
 data.skills.forEach(x=>name(x,80,1));unique(data.skills,x=>x.toLowerCase());
 data.departments.forEach(x=>{name(x.institution);name(x.name);if(!data.institutions.some(i=>i.toLowerCase()===x.institution.toLowerCase()))throw Error('Department has no approved parent in this manifest');});
 unique(data.departments,x=>x.institution.toLowerCase()+'\0'+x.name.toLowerCase());
 data.cities.forEach(x=>{name(x.name,100,1);if(!/^[A-Z]{2}$/.test(x.country_code))throw Error('Invalid country code');});unique(data.cities,x=>x.name.toLowerCase()+'\0'+x.country_code);
 const relation=(rows,columns)=>rows.length?'values '+rows.map(row=>'('+row.map(literal).join(',')+')').join(',\n'):'select '+columns.map(()=> 'null::text').join(',')+' where false';
 const delimiter='$msgi_'+crypto.createHash('sha256').update(JSON.stringify(data)).digest('hex')+'$';
 if(JSON.stringify(data).includes(delimiter))throw Error('Unsafe dollar delimiter');
 const institutions=relation(data.institutions.map(x=>[x]),['name']);
 const departments=relation(data.departments.map(x=>[x.institution,x.name]),['institution','name']);
 const skills=relation(data.skills.map(x=>[x]),['name']);
 const cities=relation(data.cities.map(x=>[x.name,x.country_code]),['name','country_code']);
 return `-- REVIEW ONLY: target ${data.project_ref}; manifest status ${data.review_status==='APPROVED'?'APPROVED':'NOT APPROVED'}.
-- No IDs, existing names or active flags are overwritten. No user/admin data.
-- Execution requires separate human approval and this transaction-scoped opt-in.
begin;
set local lock_timeout='5s';
set local standard_conforming_strings=on;
set local statement_timeout='30s';
do ${delimiter} begin
 if ${data.review_status==='APPROVED'?'false':'true'} then raise exception 'Manifest is not approved; regenerate after review'; end if;
 if current_setting('msgi.catalog_approved',true) is distinct from 'yes' then raise exception 'Explicit catalog approval required'; end if;
 perform pg_advisory_xact_lock(hashtextextended('msgi.catalog.seed',0));
end ${delimiter};
with proposed(name) as (${institutions})
insert into public.institutions(name) select name from proposed on conflict(lower(name)) do nothing;
do ${delimiter} begin
 if exists(with proposed(institution,name) as (${departments}) select 1 from proposed d left join public.institutions i on lower(i.name)=lower(d.institution) where i.id is null or not i.active) then raise exception 'Missing/inactive institution; separate review required'; end if;
 perform pg_advisory_xact_lock(hashtextextended('msgi.catalog.seed',0));
end ${delimiter};
with proposed(institution,name) as (${departments})
insert into public.departments(institution_id,name)
select i.id,d.name from proposed d join public.institutions i on lower(i.name)=lower(d.institution) where not exists(select 1 from public.departments existing where existing.institution_id=i.id and lower(existing.name)=lower(d.name))
on conflict(institution_id,name) do nothing;
with proposed(name) as (${skills})
insert into public.skills(name) select name from proposed on conflict(lower(name)) do nothing;
with proposed(name,country_code) as (${cities})
insert into public.cities(name,country_code) select p.name,p.country_code from proposed p where not exists(select 1 from public.cities existing where lower(existing.name)=lower(p.name) and existing.country_code=p.country_code) on conflict(name,country_code) do nothing;
commit;
`;
}
module.exports={render};
if(require.main===module){
 try{const path=process.argv[2]||'supabase/catalogs/development.proposed.json';const data=JSON.parse(fs.readFileSync(path,'utf8').replace(/^\uFEFF/,''));const sql=render(data);const output=process.argv[3];if(output)fs.writeFileSync(output,sql);else process.stdout.write(sql);}
 catch(e){console.error(e.message);process.exitCode=1;}
}
