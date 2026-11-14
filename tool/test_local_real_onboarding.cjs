// Task 11A: local Auth/Mailpit + protected API. Never reads hosted configuration.
const fs=require('fs'),cp=require('child_process'),crypto=require('crypto');
const config=JSON.parse(fs.readFileSync('config/backend.auth-test.local.json','utf8').replace(/^\uFEFF/,''));
const base='http://127.0.0.1:55321',callback='com.msgi.one.dev://auth-callback/';
if(config.SUPABASE_URL!==base)throw Error('Only isolated local port 55321 is permitted');
let checks=0,stage='initialization';
function ok(value,label){stage=label;if(!value)throw Error(label);checks++;console.log('PASS: '+label);}
function sql(text){return cp.execFileSync('docker',['exec','-i','supabase_db_msgi_one_clean_9a7b7923','psql','-X','-qAt','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],{input:text,encoding:'utf8',stdio:['pipe','pipe','pipe']});}
async function api(path,body,account,method=body?'POST':'GET'){
 const response=await fetch(base+path,{method,headers:{apikey:config.SUPABASE_PUBLISHABLE_KEY,'Content-Type':'application/json',...(account?{Authorization:'Bearer '+account.token}:{})},body:body?JSON.stringify(body):undefined,redirect:'manual'});
 return {status:response.status,data:await response.json().catch(()=>null)};
}
const rpc=(name,body,account)=>api('/rest/v1/rpc/'+name,body,account);
const pause=ms=>new Promise(r=>setTimeout(r,ms));
async function mail(email,type){
 for(let i=0;i<30;i++){
  const inbox=await(await fetch('http://127.0.0.1:55324/api/v1/messages')).json();
  for(const message of inbox.messages.filter(m=>m.To.some(t=>t.Address===email))){
   const detail=await(await fetch('http://127.0.0.1:55324/api/v1/message/'+message.ID)).json();
   const link=detail.HTML.match(/href="([^\"]*\/auth\/v1\/verify[^\"]*)"/)?.[1]?.replaceAll('&amp;','&');
   if(link&&new URL(link).origin===base&&new URL(link).searchParams.get('type')===type)return link;
  }
  await pause(200);
 }
 throw Error('Local email unavailable');
}
async function verify(link){const response=await fetch(link,{redirect:'manual'});const location=response.headers.get('location')||'';return {status:response.status,location,fragment:new URLSearchParams(location.split('#')[1]||'')};}
async function account(kind,{expired=false}={}){
 const email='task11a-'+kind+'-'+crypto.randomUUID()+'@example.test',password=crypto.randomBytes(24).toString('base64url');
 let result=await api('/auth/v1/signup?redirect_to='+encodeURIComponent(callback),{email,password,data:{account_kind:kind,role:'administrator',verified:true}});
 ok(result.status===200&&!result.data.access_token,'Unconfirmed '+kind+' signup has no session');
 const id=result.data.id||result.data.user?.id;if(!/^[0-9a-f-]{36}$/.test(id))throw Error('Invalid local fixture ID');
 result=await api('/auth/v1/token?grant_type=password',{email,password});ok(result.status===400,'Unconfirmed '+kind+' login denied');
 if(expired){sql(`update auth.users set confirmation_sent_at=now()-interval '2 hours' where id='${id}' and email like 'task11a-%@example.test';`);const r=await verify(await mail(email,'signup'));ok(r.location.includes('otp_expired'),'Expired confirmation rejected');return;}
 if(kind==='student'){
  await pause(1100);
  result=await api('/auth/v1/resend?redirect_to='+encodeURIComponent(callback),{type:'signup',email});ok(result.status===200,'Confirmation resend accepted locally');
 }
 const link=await mail(email,'signup'),confirmation=await verify(link);
 ok(confirmation.location.startsWith(callback)&&!!confirmation.fragment.get('access_token'),'Confirmation produces expected app callback session for '+kind);
 const repeated=await verify(link);ok(repeated.location.includes('error'),'Repeated confirmation rejected');
 result=await api('/auth/v1/token?grant_type=password',{email,password});ok(result.status===200,'Confirmed '+kind+' login');
 return {id,email,password,token:result.data.access_token,refresh:result.data.refresh_token};
}
const institution='a1100000-0000-4000-8000-000000000001';
const programme='a1110000-0000-4000-8000-000000000004';
const skill='42000000-0000-4000-8000-000000000001';
function profile(kind){return {display_name:'[SYNTHETIC LOCAL] MSEC '+kind,kind,institution_id:institution,department_id:null,programme_id:kind==='staff'?null:programme,affiliation:kind==='staff'?'Synthetic academic support':'',joining_year:kind==='student'?2024:null,graduation_year:kind==='staff'?null:kind==='student'?2028:2020,designation:'Synthetic engineer',company:'Synthetic organization',professional_domain:'Engineering',interests:['Engineering'],skill_ids:kind==='staff'?[]:[skill],directory_visible:true,map_opt_in:false,mentoring:kind==='alumni'};}
(async()=>{
 sql("set msgi.catalog_approved='msec-task11a-local';\n"+fs.readFileSync('supabase/catalogs/msec.sql','utf8'));
 sql("set msgi.catalog_approved='msec-task11a-local';\n"+fs.readFileSync('supabase/catalogs/msec.sql','utf8'));
 ok(true,'Reviewed MSEC catalog is idempotent');
 sql("set msgi.synthetic_local='yes';\n"+fs.readFileSync('supabase/dev/synthetic_catalogs.sql','utf8'));
 const student=await account('student'),alumni=await account('alumni'),staff=await account('staff');
 let r=await api('/rest/v1/programmes?select=id,name,level&institution_id=eq.'+institution,null,student);
 ok(r.status===200&&r.data.length===13&&r.data.filter(p=>p.level==='undergraduate').length===9&&r.data.filter(p=>p.level==='postgraduate').length===4,'Authenticated catalog has exactly 9 UG and 4 PG programmes');
 r=await api('/rest/v1/departments?select=name&institution_id=eq.'+institution,null,student);ok(r.status===200&&r.data.length===1&&r.data[0].name==='Science and Humanities','Academic department remains separate');
 for(const [u,kind] of [[student,'student'],[alumni,'alumni'],[staff,'staff']]){
  r=await rpc('save_member_profile',{p_input:profile(kind)},u);ok([200,204].includes(r.status),kind+' genuine-schema onboarding');
  r=await rpc('my_membership',{},u);ok(r.status===200&&r.data[0].status==='pending'&&!r.data[0].verified_kind,kind+' metadata does not grant membership');
  r=await rpc('discover_alumni_v2',{},u);ok(r.status===403,kind+' pending discovery denied');
  r=await rpc('pending_memberships',{},u);ok(r.status===403,kind+' pending administration denied');
 }
 r=await rpc('save_member_profile',{p_input:{...profile('student'),user_id:alumni.id}},student);ok(r.status===400,'Cross-account profile field rejected');
 r=await api('/rest/v1/profiles?select=programme_id,department_id,degree',null,student);ok(r.status===200&&r.data.length===1&&r.data[0].programme_id===programme&&r.data[0].department_id===null&&r.data[0].degree==='B.E. Computer Science and Engineering','Programme persists without invented department');
 r=await api('/auth/v1/token?grant_type=refresh_token',{refresh_token:student.refresh});ok(r.status===200,'Session refresh restores real identity');student.token=r.data.access_token;
 // Explicitly synthetic, isolated owner fixtures, never real institutional approval.
 for(const [u,kind] of [[student,'student'],[alumni,'alumni'],[staff,'staff']])sql(`update private.memberships set status='verified',verified_kind='${kind}' where user_id='${u.id}' and exists(select 1 from auth.users u where u.id=user_id and u.email like 'task11a-%@example.test');`);
 r=await rpc('my_membership',{},staff);ok(r.status===200&&r.data[0].verified_kind==='staff','Independently verified Staff membership loads');
 r=await rpc('pending_memberships',{},staff);ok(r.status===403,'Verified Staff is not administrator');
 r=await rpc('discover_alumni_v2',{p_programme:programme,p_user:alumni.id},student);ok(r.status===200&&r.data.length===1&&r.data[0].programme_id===programme&&!('email' in r.data[0]),'Authorized programme discovery has safe projection');
 r=await rpc('recommend_mentors',{},student);ok(r.status===200&&r.data.some(p=>p.user_id===alumni.id),'Programme-only alumni participate in mentor matching');
 r=await rpc('request_connection',{p_recipient:alumni.id},student);ok(r.status===200,'Programme-only connection request succeeds');const connection=r.data;
 r=await rpc('manage_connection',{p_id:connection,p_action:'accepted'},alumni);ok([200,204].includes(r.status),'Alumni accepts incoming connection');
 r=await rpc('career_can_publish',{},alumni);ok(r.status===200&&r.data===true,'Verified programme-only alumni can publish');
 r=await rpc('career_can_publish',{},staff);ok(r.status===200&&r.data===false,'Staff does not inherit alumni publishing rights');
 const city=crypto.randomUUID();
 sql(`insert into public.cities(id,name,country_code,centroid_latitude,centroid_longitude) values('${city}','[SYNTHETIC LOCAL] Task11 City ${Date.now()}','IN',13.0,80.2);`);
 r=await rpc('save_member_profile',{p_input:{...profile('alumni'),city_id:city,map_opt_in:true}},alumni);ok([200,204].includes(r.status),'Programme-only alumni map consent saved');
 r=await rpc('alumni_city_clusters',{},student);ok(r.status===200&&r.data.some(c=>c.city_id===city),'Programme-only alumni appear in consenting city clusters');
 r=await rpc('map_city_members',{p_city:city},student);ok(r.status===200&&r.data.some(p=>p.user_id===alumni.id),'Programme-only map detail remains authorized');
 const opportunity=crypto.randomUUID(),post={title:'[SYNTHETIC LOCAL] MSEC collaboration',description:'Synthetic collaboration for isolated local API acceptance only.',kind:'collaboration',location_text:'',external_url:'',status:'published',professional_domain:'Engineering',organization:'Synthetic organization',remote:true,referral:false,audience:'community',skill_ids:[skill]};
 r=await rpc('save_career_opportunity',{p_id:opportunity,p_input:post},alumni);ok(r.status===200&&r.data===opportunity,'Programme-only alumni publishes community collaboration');
 r=await rpc('career_opportunities',{p_id:opportunity},student);ok(r.status===200&&r.data.length===1,'Verified student reads programme-only author opportunity');const expected=r.data[0].updated_at;
 r=await rpc('save_career_opportunity',{p_id:opportunity,p_input:{...post,title:'[SYNTHETIC LOCAL] Edited collaboration'},p_expected:expected},alumni);ok(r.status===200,'Programme-only author edits owned opportunity');
 r=await rpc('transition_career_opportunity',{p_id:opportunity,p_action:'close'},student);ok(r.status===403,'Student cannot close another author opportunity');
 r=await rpc('transition_career_opportunity',{p_id:opportunity,p_action:'close'},alumni);ok([200,204].includes(r.status),'Programme-only author closes opportunity');
 r=await rpc('save_member_profile',{p_input:{...profile('alumni'),company:'Updated synthetic employer',directory_visible:false}},alumni);ok([200,204].includes(r.status),'Own profile editing retains reviewed academics');
 r=await rpc('discover_alumni_v2',{p_user:alumni.id},student);ok(r.status===200&&r.data.length===0,'Privacy edit removes directory exposure');
 r=await api('/auth/v1/signup',{email:student.email,password:student.password});ok([200,422].includes(r.status)&&!r.data.access_token,'Duplicate signup creates no authenticated session');
 const invalid=await verify(base+'/auth/v1/verify?token=invalid&type=signup&redirect_to='+encodeURIComponent(callback));ok(invalid.location.includes('error'),'Invalid confirmation denied');
 await account('expired',{expired:true});
 r=await api('/auth/v1/recover?redirect_to='+encodeURIComponent(callback),{email:student.email});ok(r.status===200,'Local recovery email requested');
 const recoveryLink=await mail(student.email,'recovery');
 const recovery=await verify(recoveryLink);ok(recovery.location.startsWith(callback)&&recovery.fragment.get('type')==='recovery'&&!!recovery.fragment.get('access_token'),'Recovery callback carries validated recovery session');
 const password=crypto.randomBytes(24).toString('base64url');
 r=await api('/auth/v1/user',{password},{token:recovery.fragment.get('access_token')},'PUT');ok(r.status===200,'Recovery session permits password update');
 r=await api('/auth/v1/token?grant_type=password',{email:student.email,password});ok(r.status===200,'Updated password permits login');
 r=await api('/auth/v1/logout',{}, {token:r.data.access_token});ok(r.status===204,'Logout accepted');
 const repeatedRecovery=await verify(recoveryLink);ok(repeatedRecovery.location.includes('error'),'Repeated recovery link rejected');
 r=await api('/auth/v1/recover?redirect_to='+encodeURIComponent(callback),{email:staff.email});ok(r.status===200,'Expired recovery fixture email requested');
 sql(`update auth.users set recovery_sent_at=now()-interval '2 hours' where id='${staff.id}' and email like 'task11a-%@example.test';`);
 const expiredRecovery=await verify(await mail(staff.email,'recovery'));ok(expiredRecovery.location.includes('otp_expired'),'Expired recovery link rejected');
 if(process.argv.includes('--fixture'))fs.writeFileSync('build/task11a-local-fixture.json',JSON.stringify({email:student.email,password,id:student.id,staffEmail:staff.email,staffPassword:staff.password,alumniEmail:alumni.email,alumniPassword:alumni.password}));
 console.log('LOCAL_REAL_ONBOARDING_CHECKS='+checks);
})().catch(()=>{console.error('LOCAL_REAL_ONBOARDING_FAILED at '+stage+'; credentials, links and responses suppressed');process.exitCode=1;});
