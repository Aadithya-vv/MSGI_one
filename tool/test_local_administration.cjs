// Synthetic accounts only; fixed isolated stack. No hosted credentials or writes.
const fs=require('fs'),cp=require('child_process'),crypto=require('crypto');
const base='http://127.0.0.1:55321',callback='com.msgi.one.dev://auth-callback/';
const cfg=JSON.parse(fs.readFileSync('config/backend.auth-test.local.json','utf8').replace(/^\uFEFF/,''));
if(cfg.SUPABASE_URL!==base)throw Error('Only isolated port 55321 permitted');
let count=0,stage='start';const accounts=[];
const ok=(v,s)=>{stage=s;if(!v)throw Error(s);count++;console.log('PASS: '+s);};
function sql(q){return cp.execFileSync('docker',['exec','-i','supabase_db_msgi_one_clean_9a7b7923','psql','-X','-qAt','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],{input:q,encoding:'utf8',stdio:['pipe','pipe','pipe']});}
async function api(p,body,token,method=body?'POST':'GET'){const r=await fetch(base+p,{method,headers:{apikey:cfg.SUPABASE_PUBLISHABLE_KEY,'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:body?JSON.stringify(body):undefined,redirect:'manual',signal:AbortSignal.timeout(20000)});return {status:r.status,data:await r.json().catch(()=>null)};}
const rpc=(n,b={},a)=>api('/rest/v1/rpc/'+n,b,a?.token);
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function account(kind,{confirm=true}={}){
 const email='task11d-'+crypto.randomUUID()+'@example.test',password=crypto.randomBytes(24).toString('base64url');
 let r=await api('/auth/v1/signup?redirect_to='+encodeURIComponent(callback),{email,password,data:{role:'administrator',verified:true,account_kind:kind}});
 ok(r.status===200&&!r.data.access_token,'Synthetic '+kind+' signup requires confirmation');
 const id=r.data.id||r.data.user?.id;if(!/^[0-9a-f-]{36}$/.test(id))throw Error('Invalid fixture ID');
 const a={id,email,password,kind};accounts.push(a);if(!confirm)return a;
 let link;for(let i=0;i<30&&!link;i++){const inbox=await(await fetch('http://127.0.0.1:55324/api/v1/messages')).json();const m=inbox.messages.find(m=>m.To.some(t=>t.Address===email));if(m){const d=await(await fetch('http://127.0.0.1:55324/api/v1/message/'+m.ID)).json();link=d.HTML.match(/href="([^\"]*\/auth\/v1\/verify[^\"]*)"/)?.[1]?.replaceAll('&amp;','&');}if(!link)await delay(100);}
 if(!link||new URL(link).origin!==base)throw Error('Local confirmation unavailable');await fetch(link,{redirect:'manual'});
 r=await api('/auth/v1/token?grant_type=password',{email,password});ok(r.status===200,'Synthetic confirmed '+kind+' login');a.token=r.data.access_token;return a;
}
const inst='d2100000-0000-4000-8000-000000000001',dep='d2200000-0000-4000-8000-000000000001',skill='d2300000-0000-4000-8000-000000000001';
async function onboard(a,changes={}){const staff=a.kind==='staff';const r=await rpc('save_member_profile',{p_input:{display_name:'[SYNTHETIC LOCAL] Administrator acceptance '+a.kind,kind:a.kind,institution_id:inst,department_id:dep,joining_year:staff?null:2020,graduation_year:staff?null:a.kind==='student'?2028:2024,affiliation:staff?'Synthetic academic support':'',designation:'Synthetic engineer',interests:['Engineering'],skill_ids:staff?[]:[skill],directory_visible:false,map_opt_in:false,...changes}},a);ok([200,204].includes(r.status),'Real '+a.kind+' onboarding remains pending');}
function verified(a,admin=false){sql(`update private.memberships set status='verified',verified_kind='${a.kind}',updated_at=clock_timestamp() where user_id='${a.id}';${admin?`insert into private.account_roles(user_id,role) values('${a.id}','administrator');`:''}`);}
const revision=(rows,id)=>rows.find(x=>x.user_id===id).revision;
const decide=(a,target,action,rev,key=crypto.randomUUID())=>rpc('decide_institutional_membership',{p_user:target.id,p_action:action,p_kind:['approve','reinstate'].includes(action)?target.kind:null,p_category:action==='suspend'?'policy_violation':'record_checked',p_note:'Synthetic independently reviewed local fixture',p_revision:rev,p_request:key},a);
(async()=>{
 sql(`insert into public.institutions(id,name) values('${inst}','[SYNTHETIC LOCAL] Administration acceptance') on conflict(id) do nothing;insert into public.departments(id,institution_id,name) values('${dep}','${inst}','Synthetic operations') on conflict(id) do nothing;insert into public.skills(id,name) values('${skill}','Synthetic institutional operations') on conflict(id) do nothing;`);
 const admin=await account('staff'),other=await account('alumni'),student=await account('student'),alumni=await account('alumni'),staff=await account('staff'),ordinary=await account('staff');
 for(const a of accounts)await onboard(a);
 ok((await rpc('administration_context',{},staff)).status===403,'Staff metadata cannot grant administration');
 verified(admin,true);verified(other,true);verified(ordinary);
 ok((await rpc('administration_context',{},ordinary)).status===403,'Verified ordinary Staff remains non-admin');
 ok((await rpc('administration_context')).status>=400,'Anonymous has no admin data');
 ok((await rpc('administration_members',{},student)).status===403,'Pending Student cannot enumerate reviews');
 ok((await rpc('administration_context',{},admin)).status===200,'Explicit verified local administrator authorized');
 let rows=(await rpc('administration_members',{p_status:'pending',p_limit:1},admin)).data;ok(rows.length===1,'API server-side page size');
 const all=(await rpc('administration_members',{p_status:'pending'},admin)).data;const rev=revision(all,alumni.id),key=crypto.randomUUID();
 ok((await decide(student,student,'approve',revision(all,student.id))).status===403,'Pending self-approval rejected through actual API');
 let r=await decide(admin,alumni,'approve',rev,key);ok([200,204].includes(r.status),'Admin approves synthetic Alumni');
 ok([200,204].includes((await decide(admin,alumni,'approve',rev,key)).status),'Exact API retry idempotent');
 ok((await rpc('administration_history',{p_user:alumni.id},admin)).data.length===1,'No duplicate audit after retry');
 const raceRev=revision(all,student.id);const race=await Promise.all([decide(admin,student,'approve',raceRev),decide(other,student,'reject',raceRev)]);
 ok(race.filter(r=>[200,204].includes(r.status)).length===1&&race.some(r=>r.data?.code==='40001'),'Two simultaneous reviewers: one commits, stale loser rejected');
 rows=(await rpc('administration_members',{p_status:'verified'},admin)).data;
 ok([200,204].includes((await decide(admin,alumni,'suspend',revision(rows,alumni.id))).status),'Authorized suspension');
 ok((await rpc('discover_alumni_v2',{},alumni)).status===403,'Pre-suspension JWT cannot bypass revocation');
 ok([200,204].includes((await rpc('request_membership_review',{p_kind:'appeal'},alumni)).status),'Suspended account may appeal');
 ok((await rpc('discover_alumni_v2',{},alumni)).status===403,'Appeal does not restore access');
 rows=(await rpc('administration_members',{p_status:'suspended'},admin)).data;
 ok([200,204].includes((await decide(admin,alumni,'reinstate',revision(rows,alumni.id))).status),'Separate authorized reinstatement');
 ok((await rpc('discover_alumni_v2',{},alumni)).status===200,'Same JWT follows live reinstatement state');
 rows=(await rpc('administration_members',{p_status:'pending'},admin)).data;
 ok([200,204].includes((await decide(admin,staff,'reject',revision(rows,staff.id))).status),'Authorized rejection');
 r=await rpc('own_review_status',{},staff);ok(r.status===200&&r.data.category==='record_checked'&&!('note'in r.data),'Safe rejection category without internal notes');
 rows=(await rpc('administration_members',{p_status:'verified'},admin)).data;
 ok([200,204].includes((await decide(admin,alumni,'correction',revision(rows,alumni.id))).status),'Verified correction returns account to pending');
 ok((await rpc('discover_alumni_v2',{},alumni)).status===403,'Correction revokes community access until reverified');
 await onboard(alumni,{graduation_year:2023});
 ok((await rpc('administration_history',{p_user:alumni.id},admin)).data.some(x=>x.action==='claim_correction'&&x.actor_id===alumni.id),'Own corrected academic claim has protected before/after audit');
 r=await api('/rest/v1/reports',{target_profile_id:staff.id,reason:'privacy',details:'Synthetic privacy report for local acceptance only'},ordinary.token);ok([200,201,204].includes(r.status),'Verified user may report privacy issue');
 r=await rpc('administration_reports',{},admin);ok(r.status===200&&r.data.some(x=>x.target_profile_id===staff.id)&&r.data.every(x=>!('reporter_id'in x)),'Moderation queue protects reporter identity');const report=r.data.find(x=>x.target_profile_id===staff.id);
 ok((await rpc('administration_reports',{},ordinary)).status===403,'Reporter denied private moderation RPC');
 r=await rpc('decide_institutional_report',{p_report:report.id,p_status:'resolved',p_note:'Synthetic reviewed privacy policy issue',p_revision:report.revision,p_request:crypto.randomUUID()},admin);ok([200,204].includes(r.status),'Report decision audited');
 sql(`delete from private.account_roles where user_id='${admin.id}';`);ok((await rpc('administration_context',{},admin)).status===403,'Existing JWT loses access immediately after role revocation');
 console.log('LOCAL_ADMINISTRATION_API_CHECKS='+count);
})().catch(()=>{console.error('LOCAL_ADMINISTRATION_FAILED at '+stage+'; credentials, tokens and raw responses suppressed');process.exitCode=1;}).finally(()=>{
 try{if(accounts.length)sql(`delete from private.account_roles where user_id in (${accounts.map(a=>"'"+a.id+"'").join(',')});`);}catch{console.error('Synthetic role cleanup failed; raw output suppressed');process.exitCode=1;}
 for(const a of accounts){if(a.token)delete a.token;delete a.password;}
});
