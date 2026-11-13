// Isolated API tests and optional private emulator fixture. Never uses hosted config.
const fs=require('fs'),cp=require('child_process'),crypto=require('crypto');
const cfg=JSON.parse(fs.readFileSync('config/backend.auth-test.local.json','utf8').replace(/^\uFEFF/,''));
const base='http://127.0.0.1:55321',callback='com.msgi.one.dev://auth-callback/';
if(cfg.SUPABASE_URL!==base)throw Error('Only isolated local API permitted');
const stamp=Date.now(),domain='[SYNTHETIC LOCAL] Career '+stamp;
let total=0;function ok(v,label){if(!v)throw Error(label);total++;console.log('PASS: '+label);}
function sql(text){return cp.execFileSync('docker',['exec','-i','supabase_db_msgi_one_clean_9a7b7923','psql','-X','-qAt','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],{input:text,encoding:'utf8',stdio:['pipe','pipe','pipe']});}
async function api(path,body,token,method=body?'POST':'GET'){const r=await fetch(base+path,{method,headers:{apikey:cfg.SUPABASE_PUBLISHABLE_KEY,'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:body?JSON.stringify(body):undefined,redirect:'manual'});return {status:r.status,data:await r.json().catch(()=>null)};}
async function rpc(name,body,account){return api('/rest/v1/rpc/'+name,body,account?.token);}
async function account(tag){
 const email='task07-'+tag+'-'+Date.now()+'@example.test',password=crypto.randomBytes(24).toString('base64url');
 let r=await api('/auth/v1/signup?redirect_to='+encodeURIComponent(callback),{email,password});ok(r.status===200,'Synthetic '+tag+' signup');
 let link;for(let i=0;i<20&&!link;i++){const box=await(await fetch('http://127.0.0.1:55324/api/v1/messages')).json();const m=box.messages.find(x=>x.To.some(t=>t.Address===email));if(m){const msg=await(await fetch('http://127.0.0.1:55324/api/v1/message/'+m.ID)).json();link=msg.HTML.match(/href="([^"]*\/auth\/v1\/verify[^\"]*)"/)?.[1]?.replaceAll('&amp;','&');}if(!link)await new Promise(r=>setTimeout(r,250));}
 if(!link||new URL(link).origin!==base)throw Error('Local confirmation missing');await fetch(link,{redirect:'manual'});
 r=await api('/auth/v1/token?grant_type=password',{email,password});ok(r.status===200,'Confirmed '+tag+' login');return {email,password,id:r.data.user.id,token:r.data.access_token};
}

function profile(name,kind,inst,dept){return {display_name:'[SYNTHETIC LOCAL] '+name+' '+stamp,kind,institution_id:inst,department_id:dept,joining_year:2020,graduation_year:2024,designation:'Synthetic engineer',company:'Synthetic organization',professional_domain:domain,degree:'Synthetic qualification',biography:'Local Career Bridge fixture only',interests:['Engineering'],skill_ids:['42000000-0000-4000-8000-000000000001'],city_id:null,directory_visible:true,map_opt_in:false,mentoring:false};}
function post(title){return {title:'[SYNTHETIC LOCAL] '+title+' '+stamp,description:'Synthetic local career opportunity for API and emulator acceptance.',kind:'job',location_text:'Synthetic city',external_url:'https://example.com/apply',status:'published',professional_domain:domain,organization:'Synthetic organization',remote:true,referral:true,audience:'community',skill_ids:['42000000-0000-4000-8000-000000000001']};}
async function save(id,input,u,expected=null){return rpc('save_career_opportunity',{p_id:id,p_input:input,p_expected:expected},u);}
async function list(u,filters={},extra={}){return rpc('career_opportunities',{p_filters:{domain,...filters},...extra},u);}
async function detail(id,u){return rpc('career_opportunities',{p_id:id,p_filters:{status:'all'},p_limit:1},u);}
(async()=>{
 sql("set msgi.synthetic_local='yes';\n"+fs.readFileSync('supabase/dev/synthetic_catalogs.sql','utf8'));
 const instA='40000000-0000-4000-8000-000000000001',deptA='41000000-0000-4000-8000-000000000001',instB=crypto.randomUUID(),deptB=crypto.randomUUID();
 sql(`insert into public.institutions(id,name) values('${instB}','[SYNTHETIC LOCAL] Career Institute ${stamp}');insert into public.departments(id,institution_id,name) values('${deptB}','${instB}','[SYNTHETIC LOCAL] Career Department ${stamp}');`);
 const writer=await account('writer'),reader=await account('reader'),peer=await account('peer');
 const wp=profile('Career writer','alumni',instA,deptA),rp=profile('Career reader','student',instA,deptA),pp=profile('Career partner','alumni',instB,deptB);
 for(const [u,p]of [[writer,wp],[reader,rp],[peer,pp]]){let r=await rpc('save_member_profile',{p_input:p},u);ok([200,204].includes(r.status),'Synthetic profile saved');}
 let r=await list(writer);ok(r.status===403,'Pending career discovery denied');
 for(const [u,kind]of [[writer,'alumni'],[reader,'student'],[peer,'alumni']]){if(!/^[a-f0-9-]{36}$/.test(u.id))throw Error('Bad fixture');sql(`update private.memberships set status='verified',verified_kind='${kind}' where user_id='${u.id}';`);}
 r=await rpc('career_can_publish',{},writer);ok(r.status===200&&r.data===true,'Verified alumnus publisher capability');
 r=await rpc('career_can_publish',{},reader);ok(r.status===200&&r.data===false,'Student publisher capability remains false');
 const own=crypto.randomUUID(),draft=crypto.randomUUID(),external=crypto.randomUUID();const input=post('Career API role'),partner=post('Career partner role');partner.kind='collaboration';partner.referral=false;
 r=await save(own,input,reader);ok(r.status===403,'Verified student cannot publish');
 r=await save(own,input,writer);ok(r.status===200&&r.data===own,'Writer creates opportunity');
 r=await save(own,input,writer);ok(r.status===200&&r.data===own,'Duplicate submit returns same post');
 r=await api('/rest/v1/opportunities?id=eq.'+own+'&select=id',null,writer.token);ok(r.status===200&&r.data.length===1,'Duplicate did not add rows');
 r=await save(own,input,peer);ok(r.status===403,'Other verified publisher cannot impersonate author');
 r=await save(crypto.randomUUID(),{...input,author_id:peer.id},writer);ok(r.status===400,'Forged author input denied');
 r=await save(crypto.randomUUID(),{...input,external_url:'https://user:secret@example.com/job'},writer);ok(r.status===400,'Invalid application URL denied');
 let row=(await detail(own,writer)).data[0];input.title+=' edited';r=await save(own,input,writer,row.updated_at);ok(r.status===200,'Author edit with current version');
 r=await save(own,input,writer,'2000-01-01T00:00:00Z');ok(r.status>=400&&r.data.code==='40001','Stale update rejected without overwrite');
 row=(await detail(own,writer)).data[0];input.audience='institution';await save(own,input,writer,row.updated_at);
 r=await list(reader);ok(r.status===200&&r.data.length===1,'Same-institution reader sees scoped post');
 r=await list(peer);ok(r.status===200&&r.data.length===0,'Other institution cannot see scoped post');
 row=(await detail(own,writer)).data[0];input.audience='community';await save(own,input,writer,row.updated_at);
 r=await save(draft,{...input,status:'draft'},writer);ok(r.status===200,'Author draft persisted');
 r=await detail(draft,reader);ok(r.status===200&&r.data.length===0,'Draft hidden from another user');
 r=await api('/rest/v1/opportunity_skills?opportunity_id=eq.'+draft+'&select=*',null,reader.token);ok(r.status===200&&r.data.length===0,'Draft required skills hidden by RLS');
 r=await save(external,partner,peer);ok(r.status===200,'Second author collaboration published');
 r=await list(reader,{kind:'collaboration'});ok(r.status===200&&r.data.length===1,'Category filtering');
 r=await list(reader,{referral:true});ok(r.status===200&&r.data.length===1,'Referral filter');
 r=await list(reader,{remote:true,skill:input.skill_ids[0]});ok(r.status===200&&r.data.length===2,'Remote and skill filtering');
 r=await list(reader,{location:'Missing place'});ok(r.status===200&&r.data.length===0,'Location empty state');
 r=await list(reader,{sort:'relevance'},{p_limit:1});ok(r.status===200&&r.data[0].rank===100&&r.data[0].shared_count===1,'Meaningful server-side skill overlap');
 const first=r.data[0];r=await list(reader,{sort:'relevance'},{p_after:{rank:first.rank,created_at:first.created_at,id:first.id},p_limit:1});ok(r.status===200&&r.data.length===1&&r.data[0].id!==first.id,'Stable cursor continuation');
 ok(!('email'in first)&&!('biography'in first)&&!('author_goals'in first),'No private author projection');
 r=await rpc('report_career_opportunity',{p_id:own,p_reason:'other',p_details:'Explicitly synthetic career moderation report.'},reader);ok(r.status===200,'Visible post report stored');const report=r.data;
 r=await rpc('report_career_opportunity',{p_id:own,p_reason:'other',p_details:'Repeated synthetic moderation report details.'},reader);ok(r.status===200&&r.data===report,'Report retry is idempotent');
 r=await rpc('moderate_report',{p_id:report,p_status:'resolved'},writer);ok(r.status===403,'Ordinary author cannot moderate reports');
 pp.directory_visible=false;await rpc('save_member_profile',{p_input:pp},peer);
 r=await detail(external,reader);ok(r.status===200&&r.data[0].author_name===null&&r.data[0].author_available===false,'Private author remains undisclosed');
 pp.directory_visible=true;await rpc('save_member_profile',{p_input:pp},peer);
 r=await rpc('transition_career_opportunity',{p_id:own,p_action:'close'},peer);ok(r.status===403,'Unauthorized close denied');
 r=await rpc('transition_career_opportunity',{p_id:own,p_action:'close'},writer);ok([200,204].includes(r.status),'Author closes own post');
 r=await detail(own,reader);ok(r.status===200&&r.data.length===0,'Closed post remains author-only');
 r=await rpc('transition_career_opportunity',{p_id:own,p_action:'archive'},writer);ok([200,204].includes(r.status),'Reported post archived without deletion');
 r=await detail(own,writer);ok(r.status===200&&r.data[0].archived===true,'Author can inspect retained archive');
 r=await api('/rest/v1/reports?target_opportunity_id=eq.'+own+'&select=id',null,reader.token);ok(r.status===200&&r.data.length===1,'Archive preserves moderation report');
 sql(`update private.memberships set status='suspended',verified_kind=null where user_id='${peer.id}';`);
 r=await list(reader);ok(r.status===200&&r.data.length===0,'Suspended author posts hidden');
 r=await save(crypto.randomUUID(),partner,peer);ok(r.status===403,'Existing suspended JWT cannot publish');
 sql(`update private.memberships set status='verified',verified_kind='alumni' where user_id='${peer.id}';`);
 if(process.argv[2])fs.writeFileSync(process.argv[2],JSON.stringify({email:writer.email,password:writer.password,domain,externalPostId:external,externalTitle:partner.title,skillName:sql("select name from public.skills where id='42000000-0000-4000-8000-000000000001';").trim()}));
 console.log('LOCAL_CAREER_API_CHECKS='+total);
})().catch(()=>{console.error('LOCAL_CAREER_API_FAILURE; private response suppressed');process.exitCode=1;});
