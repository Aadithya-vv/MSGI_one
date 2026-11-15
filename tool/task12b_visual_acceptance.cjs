// Workspace-owned disposable emulator only; never installs on a physical device.
const fs=require('node:fs'),crypto=require('node:crypto');
const {call,ui,label,tap,sleep,AVD,PACKAGE}=require('./audit_competition_demo.cjs');
const {audit}=require('./audit_competition_apk.cjs');
const mode=process.argv[2],folder='build/task12b/'+mode;
const capture=name=>{fs.writeFileSync(folder+'/'+name+'.png',call(['exec-out','screencap','-p'],true));console.log('CAPTURE '+mode+': '+name);};
async function main(){
 if(!['before','after'].includes(mode)||process.argv.length!==3)throw Error('Use before or after only');
 if(call(['emu','avd','name']).split(/\r?\n/)[0].trim()!==AVD)throw Error('Wrong disposable AVD');
 audit();fs.mkdirSync(folder,{recursive:true});
 call(['shell','svc','wifi','disable']);call(['shell','svc','data','disable']);call(['shell','cmd','connectivity','airplane-mode','enable']);
 if(mode==='after'){
  const candidate='build/task12b/MSGI-One-task12b-debug.apk';if(!fs.existsSync(candidate))throw Error('Debug candidate missing');
  call(['uninstall',PACKAGE]);call(['install','--no-streaming',candidate]);
 }
 const installedPath=call(['shell','pm','path',PACKAGE]).trim().replace(/^package:/,'');
 if(!/^\/data\/app\/[A-Za-z0-9_+/=~.\-]+\/base\.apk$/.test(installedPath))throw Error('Unexpected installed APK path');
 const installedHash=call(['shell','sha256sum',installedPath]).split(/\s+/)[0];
 const file=mode==='before'?'build/competition-release/MSGI-One-1.0.0-competition.apk':'build/task12b/MSGI-One-task12b-debug.apk';
 if(installedHash!==crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'))throw Error('Installed binary identity differs');
 call(['shell','am','start','-W','-n',PACKAGE+'/.MainActivity']);await sleep(1000);
 if(!ui().some(n=>label(n)==='Explore Demo')){await tap(/^Demo controls$/);await tap(/^Exit demo$/);}
 capture('welcome');
 await tap(/^Explore Demo$/);await tap(/^Student demo/);await sleep(900);capture('student-home');
 await tap(/^Profile\s+Tab/);await sleep(600);capture('student-profile');await tap(/^Map\s+Tab/);
 capture('map-initial');
 for(let i=0;i<3;i++)await tap(/^Zoom out$/);
 capture('map-minimum');
 for(let i=0;i<4;i++){call(['shell','input','swipe','950','1100','130','1100','450']);await sleep(250);}
 capture('map-east-boundary');
 for(let i=0;i<8;i++){call(['shell','input','swipe','130','1100','950','1100','450']);await sleep(250);}
 capture('map-west-boundary');
 await tap(/^Zoom in$/);capture('map-zoom-in');
 if(mode==='after'){
  await tap(/^Home\s+Tab/);await tap(/^Student$/);await tap(/^Alumni$/);await sleep(600);capture('alumni-home');
  await tap(/^Alumni$/);await tap(/^Staff \/ Faculty$/);await sleep(600);capture('staff-home');
 }
 fs.writeFileSync(folder+'/result.json',JSON.stringify({mode,avd:AVD,installed_sha256:installedHash,offline:true,completed:true},null,2)+'\n');
}
main().catch(e=>{console.error('TASK12B_VISUAL_STOPPED: '+e.message.split('\n')[0]);process.exitCode=1;});
