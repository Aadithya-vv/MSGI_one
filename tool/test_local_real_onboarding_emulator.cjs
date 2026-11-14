// Dedicated local emulator only. Preserves Samsung/release artifacts and retains app.
const fs=require('fs'),cp=require('child_process'),path=require('path');
const config=JSON.parse(fs.readFileSync('config/backend.auth-test.local.json','utf8').replace(/^\uFEFF/,''));
const base='http://127.0.0.1:55321',callback='com.msgi.one.dev://auth-callback/',device='emulator-5558',pkg='com.msgi.nexus.msgi_nexus';
if(config.SUPABASE_URL!==base)throw Error('Isolated local stack required');
const stamp=Date.now().toString(),adb=path.join(process.env.LOCALAPPDATA,'Android/Sdk/platform-tools/adb.exe');
const run=(...args)=>cp.execFileSync(adb,['-s',device,...args],{encoding:'utf8',stdio:['pipe','pipe','pipe'],timeout:30000});
const pause=ms=>new Promise(r=>setTimeout(r,ms));
async function emailLink(email,type){
 const inbox=await(await fetch('http://127.0.0.1:55324/api/v1/messages')).json();
 for(const m of inbox.messages.filter(m=>m.To.some(t=>t.Address===email))){
  const msg=await(await fetch('http://127.0.0.1:55324/api/v1/message/'+m.ID)).json();
  const link=msg.HTML.match(/href="([^\"]*\/auth\/v1\/verify[^\"]*)"/)?.[1]?.replaceAll('&amp;','&');
  if(link&&new URL(link).origin===base&&new URL(link).searchParams.get('type')===type)return link;
 }
}
function intent(uri){
 if(!uri.startsWith(callback)||/["'\s]/.test(uri))throw Error('Unexpected callback');
 // Android shell requires quoting ampersands; output intentionally discarded.
 run('shell','am','start','-a','android.intent.action.VIEW','-d',"'"+uri+"'",pkg);
}
(async()=>{
 if(run('get-state').trim()!=='device'||run('shell','getprop','sys.boot_completed').trim()!=='1')throw Error('Dedicated AVD not ready');
 run('reverse','tcp:55321','tcp:55321');run('reverse','tcp:55324','tcp:55324');
 const log='build/task11a-android.log';fs.writeFileSync(log,'');
 fs.writeFileSync('build/task11a-session-run.json',JSON.stringify({stamp}));
 const stream=fs.openSync(log,'a');
 const child=cp.spawn('cmd.exe',['/d','/c',`flutter drive --driver=test_driver/demo_driver.dart --target=integration_test/real_onboarding_test.dart -d ${device} --no-pub --debug --keep-app-running --dart-define=LOCAL_AUTH_TESTING=true --dart-define=TASK11_STAMP=${stamp} --dart-define-from-file=config/backend.auth-test.local.json`],{stdio:['ignore',stream,stream]});
 let exitCode;child.on('exit',code=>{exitCode=code;});
 const phases=['student','alumni','staff','recovery','invalid'];let phase=0;
 for(let i=0;i<1200&&exitCode===undefined;i++){
  const text=fs.readFileSync(log,'utf8');const current=phases[phase];
  const marker=current==='recovery'?'TASK11_RECOVERY':current==='invalid'?'TASK11_INVALID':'TASK11_CONFIRM_'+current;
  if(current&&text.includes(marker)){
   if(current==='invalid'){intent(callback+'?error=access_denied&error_code=otp_expired&error_description=Expired');phase++;}
   else{
    const role=current==='recovery'?'staff':current;
    const link=await emailLink(`task11a-android-${role}-${stamp}@example.test`,current==='recovery'?'recovery':'signup');
    if(link){const response=await fetch(link,{redirect:'manual'});const uri=response.headers.get('location')||'';intent(uri);phase++;console.log('Opened local Android '+current+' callback; values suppressed.');}
   }
  }
  await pause(500);
 }
 if(exitCode===undefined){child.kill();throw Error('Native run timed out');}
 fs.closeSync(stream);
 if(exitCode!==0||phase!==phases.length)throw Error('Native workflow failed');
 const logs=run('logcat','-d','-s','flutter:I');
 if(/access_token=|refresh_token=|RenderFlex overflowed|Unhandled Exception/.test(logs)||logs.includes('Local-Synthetic-'+stamp)||logs.includes('Local-Updated-'+stamp))throw Error('Sensitive/rendering diagnostic pattern');
 if(!run('shell','pm','path',pkg).includes('package:'))throw Error('Test app unexpectedly removed');
 console.log('PASS: Actual Android confirmation/recovery intents, three-role local onboarding, profile persistence, pending access and invalid-link denial.');
 console.log('PASS: App retained; sampled Flutter logs contain no password/token/overflow/unhandled-exception patterns.');
})().catch(()=>{console.error('LOCAL_REAL_ONBOARDING_EMULATOR_FAILED; see ignored local log. No credentials or callback URLs printed.');process.exitCode=1;});
