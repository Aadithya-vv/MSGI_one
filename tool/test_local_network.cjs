// Isolated API tests and optional private emulator fixture. Never uses hosted config.
const fs=require('fs'),cp=require('child_process'),crypto=require('crypto');
const cfg=JSON.parse(fs.readFileSync('config/backend.auth-test.local.json','utf8').replace(/^\uFEFF/,''));
const base='http://127.0.0.1:55321',callback='com.msgi.one.dev://auth-callback/';
if(cfg.SUPABASE_URL!==base)throw Error('Only isolated local API permitted');
const fixtureCity=crypto.randomUUID(),fixtureCityName='[SYNTHETIC LOCAL] Task05 City '+Date.now();
let total=0;function ok(v,label){if(!v)throw Error(label);total++;console.log('PASS: '+label);}
function sql(text){return cp.execFileSync('docker',['exec','-i','supabase_db_msgi_one_clean_9a7b7923','psql','-X','-qAt','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],{input:text,encoding:'utf8',stdio:['pipe','pipe','pipe']});}
async function api(path,body,token,method=body?'POST':'GET'){const r=await fetch(base+path,{method,headers:{apikey:cfg.SUPABASE_PUBLISHABLE_KEY,'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:body?JSON.stringify(body):undefined,redirect:'manual'});return {status:r.status,data:await r.json().catch(()=>null)};}
async function rpc(name,body,account){return api('/rest/v1/rpc/'+name,body,account?.token);}
async function account(tag){
 const email='task05-'+tag+'-'+Date.now()+'@example.test',password=crypto.randomBytes(24).toString('base64url');
 let r=await api('/auth/v1/signup?redirect_to='+encodeURIComponent(callback),{email,password});ok(r.status===200,'Synthetic '+tag+' signup');
 let link;for(let i=0;i<20&&!link;i++){const box=await(await fetch('http://127.0.0.1:55324/api/v1/messages')).json();const m=box.messages.find(x=>x.To.some(t=>t.Address===email));if(m){const msg=await(await fetch('http://127.0.0.1:55324/api/v1/message/'+m.ID)).json();link=msg.HTML.match(/href="([^"]*\/auth\/v1\/verify[^\"]*)"/)?.[1]?.replaceAll('&amp;','&');}if(!link)await new Promise(r=>setTimeout(r,250));}
 if(!link||new URL(link).origin!==base)throw Error('Local confirmation missing');await fetch(link,{redirect:'manual'});
 r=await api('/auth/v1/token?grant_type=password',{email,password});ok(r.status===200,'Confirmed '+tag+' login');return {email,password,id:r.data.user.id,token:r.data.access_token};
}
function profile(name,{map=true,domain='Engineering'}={}){return {display_name:'[SYNTHETIC LOCAL] '+name,kind:'alumni',institution_id:'40000000-0000-4000-8000-000000000001',department_id:'41000000-0000-4000-8000-000000000001',joining_year:2020,graduation_year:2024,designation:'Synthetic engineer',company:'Synthetic organization',professional_domain:domain,degree:'Synthetic qualification',biography:'Local testing only',interests:['Research'],skill_ids:['42000000-0000-4000-8000-000000000001'],city_id:fixtureCity,directory_visible:true,map_opt_in:map,mentoring:false};}
(async()=>{
 sql("set msgi.synthetic_local='yes';\n"+fs.readFileSync('supabase/dev/synthetic_catalogs.sql','utf8'));
 sql(`insert into public.cities(id,name,country_code,centroid_latitude,centroid_longitude) values('${fixtureCity}','${fixtureCityName}','IN',20,0);`);
 const a=await account('sender'),b=await account('peer'),viewer=await account('viewer');
 const pa=profile('Map sender'),pb=profile('Network partner',{map:false,domain:'Research'}),pv=profile('Emulator viewer',{map:false});
 for(const [u,p] of [[a,pa],[b,pb],[viewer,pv]]){const r=await rpc('save_member_profile',{p_input:p},u);ok(r.status===200||r.status===204,'Synthetic profile saved');}
 let r=await rpc('alumni_city_clusters',{},a);ok(r.status===403,'Pending API map denied');
 for(const u of [a,b,viewer]){if(!/^[a-f0-9-]{36}$/.test(u.id))throw Error('Bad fixture id');sql(`begin;update private.memberships set status='verified',verified_kind='alumni' where user_id='${u.id}';insert into private.verification_audit(subject_id,actor_id,previous_status,new_status,verified_kind,reason) values('${u.id}','${u.id}','pending','verified','alumni','Explicit isolated Task05 membership fixture; not institutional approval');commit;`);}
 const city=fixtureCity;
 r=await rpc('alumni_city_clusters',{p_location:fixtureCityName},a);ok(r.status===200&&r.data.find(x=>x.city_id===city).alumni_count===1,'Map-off peers excluded from counts');
 pb.map_opt_in=true;await rpc('save_member_profile',{p_input:pb},b);
 r=await rpc('alumni_city_clusters',{p_location:fixtureCityName,p_domain:'Research'},a);ok(r.status===200&&r.data[0].alumni_count===1,'Domain aggregate filtered');
 r=await rpc('map_city_members',{p_city:city,p_domain:'Research'},a);ok(r.status===200&&r.data.length===1&&r.data[0].user_id===b.id,'City panel matches filtered aggregate');
 ok(!('email' in r.data[0])&&!('latitude' in r.data[0]),'No private contact or individual coordinates in city members');
 pb.directory_visible=false;pb.map_opt_in=false;await rpc('save_member_profile',{p_input:pb},b);
 r=await rpc('alumni_city_clusters',{p_location:fixtureCityName,p_domain:'Research'},a);ok(r.status===200&&r.data.length===0,'Hidden domain cannot leak via aggregate');
 pb.directory_visible=true;pb.map_opt_in=true;await rpc('save_member_profile',{p_input:pb},b);
 r=await rpc('request_connection',{p_recipient:b.id},a);ok(r.status===200,'Request API creates relation');const id=r.data;
 r=await rpc('request_connection',{p_recipient:b.id},a);ok(r.status===200&&r.data===id,'Duplicate API request idempotent');
 r=await rpc('request_connection',{p_recipient:a.id},b);ok(r.status===200&&r.data===id,'Opposite requests do not duplicate');
 r=await rpc('network_connections',{p_tab:'all'},viewer);ok(r.status===200&&r.data.length===0,'Unrelated user cannot read relationships');
 r=await rpc('manage_connection',{p_id:id,p_action:'accepted'},viewer);ok(r.status===403,'Unrelated user cannot mutate');
 r=await rpc('manage_connection',{p_id:id,p_action:'accepted'},a);ok(r.status===403,'Sender cannot accept request');
 r=await rpc('manage_connection',{p_id:id,p_action:'accepted'},b);ok([200,204].includes(r.status),'Recipient accepts');
 r=await rpc('manage_connection',{p_id:id,p_action:'accepted'},b);ok([200,204].includes(r.status),'Repeated acceptance succeeds safely');
 r=await rpc('network_connections',{p_tab:'accepted'},a);ok(r.status===200&&r.data.some(x=>x.connection_id===id&&x.peer_eligible),'Accepted API projection');
 r=await rpc('manage_connection',{p_id:id,p_action:'removed'},a);ok([200,204].includes(r.status),'Accepted relationship removed');
 r=await rpc('manage_connection',{p_id:id,p_action:'removed'},a);ok([200,204].includes(r.status),'Remove idempotent');
 await rpc('request_connection',{p_recipient:b.id},a);
 r=await rpc('manage_connection',{p_id:id,p_action:'cancelled'},a);ok([200,204].includes(r.status),'Outgoing request cancelled');
 await rpc('request_connection',{p_recipient:b.id},a);
 r=await rpc('manage_connection',{p_id:id,p_action:'rejected'},b);ok([200,204].includes(r.status),'Incoming request declined');
 r=await rpc('request_connection',{p_recipient:b.id},a);ok(r.status===400,'Declined request cannot be spammed open');
 r=await rpc('request_connection',{p_recipient:b.id},b);ok(r.status===400,'Self connection denied');
 sql(`update private.memberships set status='suspended',verified_kind=null where user_id='${a.id}';`);
 r=await rpc('alumni_city_clusters',{},a);ok(r.status===403,'Existing suspended JWT cannot read map');
 r=await rpc('request_connection',{p_recipient:a.id},b);ok(r.status===403,'Suspended target cannot receive request');
 r=await rpc('alumni_city_clusters',{p_location:fixtureCityName},viewer);ok(r.status===200&&r.data[0].alumni_count===1,'Suspension removes map contribution');
 // Preserve one real local incoming request for emulator UI acceptance.
 r=await rpc('request_connection',{p_recipient:viewer.id},b);ok(r.status===200,'Synthetic emulator incoming request prepared');
 if(process.argv[2]){fs.writeFileSync(process.argv[2],JSON.stringify({email:viewer.email,password:viewer.password,peer:b.id,peerName:pb.display_name,cityName:fixtureCityName}));console.log('PRIVATE_LOCAL_EMULATOR_FIXTURE_READY');}
 console.log('LOCAL_MAP_NETWORK_API_CHECKS='+total);
})().catch(()=>{console.error('LOCAL_MAP_NETWORK_API_FAILURE (private response suppressed)');process.exitCode=1;});
