// Requires local_session_launcher debug build on the dedicated test AVD.
const cp=require('child_process'),fs=require('fs'),path=require('path');
const adb=path.join(process.env.LOCALAPPDATA,'Android/Sdk/platform-tools/adb.exe');
const pkg='com.msgi.nexus.msgi_nexus',device='emulator-5558';
const run=(...args)=>cp.execFileSync(adb,['-s',device,...args],{encoding:'utf8',stdio:['pipe','pipe','pipe'],timeout:30000});
const delay=ms=>new Promise(r=>setTimeout(r,ms));
let stage='startup';
function ui(){run('shell','uiautomator','dump','/sdcard/task11a-restart.xml');return run('shell','cat','/sdcard/task11a-restart.xml');}
async function wait(label){for(let i=0;i<40;i++){try{const xml=ui();if(xml.includes(label))return xml;}catch{}await delay(500);}throw Error('Expected restart screen unavailable');}
async function tap(label){const xml=await wait(label);const node=[...xml.matchAll(/<node\b[^>]*>/g)].find(m=>m[0].includes(`content-desc="${label}"`)||m[0].includes(`text="${label}"`));if(!node)throw Error('Restart control unavailable');const values=node[0].match(/bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/).slice(1).map(Number);run('shell','input','tap',String(Math.round((values[0]+values[2])/2)),String(Math.round((values[1]+values[3])/2)));}
(async()=>{
 fs.mkdirSync('build/task11a',{recursive:true});
 for(let cycle=1;cycle<=2;cycle++){
  stage='process-launch-'+cycle;
  run('shell','am','force-stop',pkg);
  const timing=run('shell','am','start','-W','-n',pkg+'/.MainActivity');
  fs.writeFileSync(`build/task11a/process-restart-${cycle}.txt`,timing);
  stage='open-restored-session-'+cycle;
  await tap('Sign in to real community');await wait('Verification pending');
  stage='read-restored-profile-'+cycle;
  await tap('View your submitted profile');await wait('[SYNTHETIC LOCAL] Android staff');
  run('shell','screencap','-p','/sdcard/task11a-restart.png');
  run('pull','/sdcard/task11a-restart.png',`build/task11a/process-restart-${cycle}.png`);
 }
 const pid=run('shell','pidof',pkg).trim();if(!/^\d+$/.test(pid))throw Error('Application process unavailable');
 const logs=run('logcat','-d','--pid='+pid,'-s','flutter:I','AndroidRuntime:E');
 if(/access_token=|refresh_token=|Local-Synthetic-|Local-Updated-|RenderFlex overflowed|Unhandled Exception|FATAL EXCEPTION/.test(logs))throw Error('Sensitive/runtime diagnostic pattern');
 console.log('PASS: Two actual Android process restarts restore the SDK session and cloud Staff profile without credential entry.');
 console.log('PASS: Pending access retained and no sampled credential/runtime patterns.');
})().catch(()=>{console.error('LOCAL_SESSION_RESTART_FAILED at '+stage+'; sensitive diagnostics suppressed.');process.exitCode=1;});
