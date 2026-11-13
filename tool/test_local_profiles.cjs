// Isolated local API acceptance. No hosted endpoints, resets or external mail.
// Requires the reviewed Task 04A migration and existing local Auth/Mailpit stack.
const fs = require('fs');
const cp = require('child_process');
const crypto = require('crypto');
const config = JSON.parse(fs.readFileSync('config/backend.auth-test.local.json','utf8').replace(/^\uFEFF/,''));
const base='http://127.0.0.1:55321', callback='com.msgi.one.dev://auth-callback/';
if(config.SUPABASE_URL !== base) throw Error('Only isolated port 55321 is permitted');
let count=0;
function check(value,label){ if(!value) throw Error(label); count++; console.log('PASS: '+label); }
function sql(query){ return cp.execFileSync('docker',['exec','-i','supabase_db_msgi_one_clean_9a7b7923','psql','-X','-qAt','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],{input:query,encoding:'utf8',stdio:['pipe','pipe','pipe']}); }
async function request(path,{method='GET',body,token}={}){
 const response=await fetch(base+path,{method,headers:{apikey:config.SUPABASE_PUBLISHABLE_KEY,'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:body?JSON.stringify(body):undefined,redirect:'manual'});
 return {status:response.status,body:await response.json().catch(()=>null)};
}
async function account(tag){
 const email='task04a-'+tag+'-'+Date.now()+'@example.test',password=crypto.randomBytes(24).toString('base64url');
 const signup=await request('/auth/v1/signup?redirect_to='+encodeURIComponent(callback),{method:'POST',body:{email,password}});
 check(signup.status===200,'Synthetic '+tag+' signup');
 let link;
 for(let i=0;i<15&&!link;i++){
  const mailbox=await(await fetch('http://127.0.0.1:55324/api/v1/messages')).json();
  const msg=mailbox.messages.find(m=>m.To.some(t=>t.Address===email));
  if(msg){const detail=await(await fetch('http://127.0.0.1:55324/api/v1/message/'+msg.ID)).json();const match=detail.HTML.match(/href="([^"]*\/auth\/v1\/verify[^\"]*)"/);if(match)link=match[1].replaceAll('&amp;','&');}
  if(!link)await new Promise(r=>setTimeout(r,250));
 }
 if(!link||new URL(link).origin!==base)throw Error('Local confirmation unavailable');
 const confirmation=await fetch(link,{redirect:'manual'});check(confirmation.status===303||confirmation.status===302,'Local confirmation '+tag);
 const login=await request('/auth/v1/token?grant_type=password',{method:'POST',body:{email,password}});
 check(login.status===200,'Confirmed '+tag+' login');
 return {id:login.body.user.id,token:login.body.access_token};
}
function input(kind){return {display_name:'[SYNTHETIC LOCAL] '+kind,kind,institution_id:'40000000-0000-4000-8000-000000000001',department_id:'41000000-0000-4000-8000-000000000001',joining_year:2020,graduation_year:kind==='student'?new Date().getFullYear()+1:2024,designation:'Synthetic engineer',company:'Synthetic organization',professional_domain:'Engineering',degree:'Synthetic qualification',biography:'Synthetic API testing profile',interests:['Research'],skill_ids:['42000000-0000-4000-8000-000000000001'],city_id:'43000000-0000-4000-8000-000000000001',directory_visible:true,map_opt_in:false,mentoring:true};}
async function rpc(name,body,token){return request('/rest/v1/rpc/'+name,{method:'POST',body,token});}
(async()=>{
 sql("set msgi.synthetic_local='yes';\n"+fs.readFileSync('supabase/dev/synthetic_catalogs.sql','utf8'));
 sql("set msgi.synthetic_local='yes';\n"+fs.readFileSync('supabase/dev/synthetic_catalogs.sql','utf8'));
 check(true,'Separate synthetic catalog seed is repeatable');
 const student=await account('student'),alumni=await account('alumni');
 let r=await request('/rest/v1/institutions?select=id,name&active=eq.true',{token:student.token});check(r.status===200&&r.body.some(x=>x.id===input('student').institution_id),'Authenticated real catalog API');
 r=await request('/rest/v1/departments?select=id&institution_id=eq.'+input('student').institution_id,{token:student.token});check(r.status===200&&r.body.some(x=>x.id===input('student').department_id),'Institution-dependent catalog query');
 r=await request('/rest/v1/profile_drafts',{method:'POST',token:student.token,body:{user_id:student.id,content:{display_name:'Partial'}}});check(r.status===201,'Own draft persists');
 r=await request('/rest/v1/profile_drafts?select=content',{token:alumni.token});check(r.status===200&&r.body.length===0,'Other-user draft hidden');
 r=await rpc('save_member_profile',{p_input:input('student')},student.token);check(r.status===204||r.status===200,'Student profile submission');
 r=await rpc('my_membership',{},student.token);check(r.status===200&&r.body[0].status==='pending','Student remains pending');
 r=await rpc('save_member_profile',{p_input:input('alumni')},alumni.token);check(r.status===204||r.status===200,'Alumni professional submission');
 r=await rpc('discover_alumni',{},alumni.token);check(r.status===403,'Pending alumni discovery denied');
 // Explicit server-owned, isolated fixture authorization. No administrator roles.
 for(const [a,kind] of [[student,'student'],[alumni,'alumni']]){
  if(!/^[a-f0-9-]{36}$/.test(a.id))throw Error('Invalid fixture ID');
  sql(`begin; update private.memberships set status='verified',verified_kind='${kind}' where user_id='${a.id}'; insert into private.verification_audit(subject_id,actor_id,previous_status,new_status,verified_kind,reason) values('${a.id}','${a.id}','pending','verified','${kind}','Isolated synthetic API authorization fixture'); commit;`);
 }
 r=await rpc('discover_alumni',{p_profession:'Synthetic organization',p_institution:input('alumni').institution_id,p_department:input('alumni').department_id,p_year:2024,p_skill:input('alumni').skill_ids[0],p_limit:21},student.token);
 check(r.status===200&&r.body.some(x=>x.user_id===alumni.id),'Verified API filtering uses server membership');
 const visible=r.body.find(x=>x.user_id===alumni.id);
 check(!('email' in visible)&&!('verified_kind' in visible)&&!('reason' in visible)&&visible.city===null,'Safe API projection and hidden city');
 r=await rpc('discover_alumni',{p_user:alumni.id},student.token);check(r.status===200&&r.body.length===1,'Authorized public profile detail');
 r=await request('/rest/v1/profiles?select=*,institutions(name),departments(name),profile_skills(skill_id,skills(name)),mentorship_preferences(available)',{token:alumni.token});
 check(r.status===200&&r.body.length===1&&r.body[0].company==='Synthetic organization','Own profile nested API contract');
 r=await request('/rest/v1/profiles?select=user_id&user_id=eq.'+alumni.id,{token:student.token});check(r.status===200&&r.body.length===0,'Direct cross-profile access denied');
 r=await rpc('save_member_profile',{p_input:{...input('alumni'),graduation_year:2023}},alumni.token);check(r.status===403,'Verified education correction denied');
 r=await rpc('save_member_profile',{p_input:{...input('alumni'),company:'Updated synthetic organization',directory_visible:false}},alumni.token);check(r.status===200||r.status===204,'Own professional/privacy editing');
 r=await rpc('discover_alumni',{p_user:alumni.id},student.token);check(r.status===200&&r.body.length===0,'Hidden profile removed from discovery');
 r=await rpc('discover_alumni',{});check(r.status===401,'Anonymous directory API denied');
 sql(`update private.memberships set status='suspended',verified_kind=null where user_id='${student.id}';`);
 r=await rpc('discover_alumni',{},student.token);check(r.status===403,'Existing JWT loses directory after suspension');
 console.log('LOCAL_PROFILE_API_CHECKS='+count);
})().catch(()=>{console.error('LOCAL_PROFILE_API_CHECK_FAILED (sensitive response suppressed)');process.exitCode=1;});
