// Isolated API tests and optional private emulator fixture. Never uses hosted config.
const fs=require('fs'),cp=require('child_process'),crypto=require('crypto');
const cfg=JSON.parse(fs.readFileSync('config/backend.auth-test.local.json','utf8').replace(/^\uFEFF/,''));
const base='http://127.0.0.1:55321',callback='com.msgi.one.dev://auth-callback/';
if(cfg.SUPABASE_URL!==base)throw Error('Only isolated local API permitted');
const stamp=Date.now(),domain='[SYNTHETIC LOCAL] Mentor '+stamp;
let total=0;function ok(v,label){if(!v)throw Error(label);total++;console.log('PASS: '+label);}
function sql(text){return cp.execFileSync('docker',['exec','-i','supabase_db_msgi_one_clean_9a7b7923','psql','-X','-qAt','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],{input:text,encoding:'utf8',stdio:['pipe','pipe','pipe']});}
async function api(path,body,token,method=body?'POST':'GET'){const r=await fetch(base+path,{method,headers:{apikey:cfg.SUPABASE_PUBLISHABLE_KEY,'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:body?JSON.stringify(body):undefined,redirect:'manual'});return {status:r.status,data:await r.json().catch(()=>null)};}
async function rpc(name,body,account){return api('/rest/v1/rpc/'+name,body,account?.token);}
async function account(tag){
 const email='task06-'+tag+'-'+Date.now()+'@example.test',password=crypto.randomBytes(24).toString('base64url');
 let r=await api('/auth/v1/signup?redirect_to='+encodeURIComponent(callback),{email,password});ok(r.status===200,'Synthetic '+tag+' signup');
 let link;for(let i=0;i<20&&!link;i++){const box=await(await fetch('http://127.0.0.1:55324/api/v1/messages')).json();const m=box.messages.find(x=>x.To.some(t=>t.Address===email));if(m){const msg=await(await fetch('http://127.0.0.1:55324/api/v1/message/'+m.ID)).json();link=msg.HTML.match(/href="([^"]*\/auth\/v1\/verify[^\"]*)"/)?.[1]?.replaceAll('&amp;','&');}if(!link)await new Promise(r=>setTimeout(r,250));}
 if(!link||new URL(link).origin!==base)throw Error('Local confirmation missing');await fetch(link,{redirect:'manual'});
 r=await api('/auth/v1/token?grant_type=password',{email,password});ok(r.status===200,'Confirmed '+tag+' login');return {email,password,id:r.data.user.id,token:r.data.access_token};
}

function profile(name,kind){return {display_name:'[SYNTHETIC LOCAL] '+name+' '+stamp,kind,institution_id:'40000000-0000-4000-8000-000000000001',department_id:'41000000-0000-4000-8000-000000000001',joining_year:2020,graduation_year:2024,designation:'Synthetic engineer',company:'Synthetic organization',professional_domain:domain,degree:'Synthetic qualification',biography:'Local mentor test only',interests:['Research'],skill_ids:['42000000-0000-4000-8000-000000000001'],city_id:null,directory_visible:true,map_opt_in:false,mentoring:kind==='alumni'};}
(async()=>{
 sql("set msgi.synthetic_local='yes';\n"+fs.readFileSync('supabase/dev/synthetic_catalogs.sql','utf8'));
 const skill=crypto.randomUUID();sql(`insert into public.skills(id,name) values('${skill}','[SYNTHETIC LOCAL] Mentor skill ${stamp}');`);
 const student=await account('student'),mentor=await account('mentor'),pending=await account('pending');
 const sp=profile('Learner','student'),mp=profile('Mentor Example','alumni');mp.skill_ids.push(skill);
 for(const [u,p]of [[student,sp],[mentor,mp]]){const r=await rpc('save_member_profile',{p_input:p},u);ok([200,204].includes(r.status),'Synthetic onboarding saved');}
 let r=await rpc('recommend_mentors',{},pending);ok(r.status===403,'Unverified recommendation requester denied');
 for(const [u,kind]of [[student,'student'],[mentor,'alumni']]){if(!/^[a-f0-9-]{36}$/.test(u.id))throw Error('Bad fixture');sql(`update private.memberships set status='verified',verified_kind='${kind}' where user_id='${u.id}';`);}
 r=await rpc('my_mentor_goals',{},student);ok(r.status===200&&r.data.existing_skill_ids.length===1,'Own defaults reuse profile skills');
 const goals={career_interests:['Research'],target_domains:[domain],existing_skill_ids:sp.skill_ids,learning_skill_ids:[skill],objectives:['Career planning']};
 r=await rpc('save_mentor_goals',{p_input:goals},student);ok([200,204].includes(r.status),'Private goals saved through authenticated API');
 r=await rpc('save_mentor_goals',{p_input:{...goals,user_id:mentor.id}},student);ok(r.status===400,'Forged goals owner denied');
 r=await api('/rest/v1/mentor_goals?select=*',null,mentor.token);ok(r.status===200&&r.data.length===0,'Other-user goals hidden by RLS');
 r=await api('/rest/v1/mentor_goals',{user_id:student.id},student.token);ok(r.status===403,'Direct goals insert denied');
 r=await rpc('recommend_mentors',{p_domain:domain},student);ok(r.status===200&&r.data.length===1&&r.data[0].score===100,'Exact real API recommendation scores 100');
 const match=r.data[0];ok(match.shared_skills.length===2&&match.matching_domains[0]===domain&&match.shared_interests[0]==='Research','Explanations use actual authorized evidence');
 ok(!('email'in match)&&!('objectives'in match)&&!('city'in match),'Recommendation projection omits private and location data');
 r=await rpc('recommend_mentors',{p_domain:domain,p_after_rank:match.rank_value,p_after_id:match.user_id},student);ok(r.status===200&&r.data.length===0,'Real API cursor does not repeat mentor');
 r=await rpc('recommend_mentors',{p_domain:domain,p_sort:'skills'},student);ok(r.status===200&&r.data[0].user_id===mentor.id,'Server-side alternate ordering works');
 await rpc('set_mentor_block',{p_peer:mentor.id,p_block:true},student);
 r=await rpc('recommend_mentors',{p_domain:domain},student);ok(r.status===200&&r.data.length===0,'Blocked mentor excluded');
 await rpc('set_mentor_block',{p_peer:mentor.id,p_block:false},student);
 mp.mentoring=false;await rpc('save_member_profile',{p_input:mp},mentor);
 r=await rpc('recommend_mentors',{p_domain:domain},student);ok(r.status===200&&r.data.length===0,'Mentoring opt-out enforced immediately');
 mp.mentoring=true;mp.directory_visible=false;await rpc('save_member_profile',{p_input:mp},mentor);
 r=await rpc('recommend_mentors',{p_domain:domain},student);ok(r.status===200&&r.data.length===0,'Hidden mentor cannot leak through filtering');
 mp.directory_visible=true;await rpc('save_member_profile',{p_input:mp},mentor);
 r=await rpc('request_connection',{p_recipient:mentor.id},student);ok(r.status===200,'Matching reuses protected connection request');const connection=r.data;
 r=await rpc('recommend_mentors',{p_domain:domain},student);ok(r.status===200&&r.data[0].connection_status==='pending','Existing connection status returned');
 r=await rpc('recommend_mentors',{p_domain:domain,p_unconnected:true},student);ok(r.status===200&&r.data.length===0,'New-connections filter excludes pending');
 await rpc('manage_connection',{p_id:connection,p_action:'cancelled'},student);
 sql(`update private.memberships set status='suspended',verified_kind=null where user_id='${mentor.id}';`);
 r=await rpc('recommend_mentors',{p_domain:domain},student);ok(r.status===200&&r.data.length===0,'Suspended alumni excluded');
 sql(`update private.memberships set status='verified',verified_kind='alumni' where user_id='${mentor.id}';`);
 r=await rpc('save_mentor_goals',{p_input:goals},pending);ok(r.status===403,'Unverified preferences save denied');
 if(process.argv[2])fs.writeFileSync(process.argv[2],JSON.stringify({email:student.email,password:student.password,peer:mentor.id,peerName:mp.display_name,domain}));
 console.log('LOCAL_MENTOR_API_CHECKS='+total);
})().catch(()=>{console.error('LOCAL_MENTOR_API_FAILURE; private response suppressed');process.exitCode=1;});
