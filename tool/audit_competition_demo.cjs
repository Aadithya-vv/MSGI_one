// Ordinary signed APK acceptance ONLY on the explicitly disposable Task12A AVD.
// No Flutter install/build, backend configuration, physical device or real account.
const fs=require('node:fs'),cp=require('node:child_process'),path=require('node:path');
const {audit}=require('./audit_competition_apk.cjs');
const DEVICE='emulator-5556',AVD='MSGI_Task12A_Disposable',PACKAGE='com.msgi.nexus.msgi_nexus';
const adb=path.join(process.env.LOCALAPPDATA,'Android/Sdk/platform-tools/adb.exe');
const output='build/task12a/signed-apk',checks=[];
const call=(args,binary=false)=>cp.execFileSync(adb,['-s',DEVICE,...args],{encoding:binary?null:'utf8',windowsHide:true,stdio:['pipe','pipe','pipe'],timeout:30000,maxBuffer:8*1024*1024});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const decode=s=>s.replace(/&#(\d+);/g,(_,n)=>String.fromCodePoint(Number(n))).replace(/&quot;/g,'"').replace(/&apos;/g,"'").replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&amp;/g,'&');
function ui(){call(['shell','uiautomator','dump','/sdcard/msgi-task12a.xml']);const xml=call(['shell','cat','/sdcard/msgi-task12a.xml']);return [...xml.matchAll(/<node\s+([^>]+)>?/g)].map(m=>Object.fromEntries([...m[1].matchAll(/([\w-]+)="([^"]*)"/g)].map(a=>[a[1],decode(a[2])])));}
const label=n=>n.text+n['content-desc'];
async function tap(pattern){const node=ui().find(n=>pattern.test(label(n)));if(!node)throw Error('Control unavailable: '+pattern.source);const b=node.bounds.match(/\d+/g).map(Number);call(['shell','input','tap',String(Math.floor((b[0]+b[2])/2)),String(Math.floor((b[1]+b[3])/2))]);await sleep(500);}
function check(pattern,name){if(!ui().some(n=>pattern.test(label(n))))throw Error('Screen assertion failed: '+name);checks.push(name);fs.writeFileSync(output+'/'+name+'.png',call(['exec-out','screencap','-p'],true));console.log('PASS signed APK: '+name);}
async function back(){call(['shell','input','keyevent','4']);await sleep(500);}
async function main(){
 if(process.argv.length!==2)throw Error('No device, APK or configuration override accepted');
 audit();fs.mkdirSync(output,{recursive:true});
 if(call(['emu','avd','name']).split(/\r?\n/)[0].trim()!==AVD)throw Error('Wrong/non-disposable AVD; no mutation allowed');
 if(call(['shell','getprop','sys.boot_completed']).trim()!=='1')throw Error('Disposable AVD not booted');
 // Only this newly created, explicitly disposable AVD may be cleaned/installed.
 const existing=cp.spawnSync(adb,['-s',DEVICE,'shell','pm','path',PACKAGE],{encoding:'utf8',windowsHide:true,timeout:30000});
 if(![0,1].includes(existing.status))throw Error('Cannot inspect disposable installation');
 const installed=existing.stdout.trim();
 if(installed)call(['uninstall',PACKAGE]);
 call(['shell','svc','wifi','disable']);call(['shell','svc','data','disable']);
 call(['shell','cmd','connectivity','airplane-mode','enable']);
 call(['install','--no-streaming','build/competition-release/MSGI-One-1.0.0-competition.apk']);
 fs.writeFileSync(output+'/cold-start.txt',call(['shell','am','start','-W','-n',PACKAGE+'/.MainActivity']));await sleep(1800);
 check(/^Explore Demo$/,'00-entry-offline');await tap(/^Explore Demo$/);check(/Choose a perspective/,'01-role-choice');await tap(/^Student demo/);
 check(/Welcome, Mira Rao/,'02-student-home');
 await tap(/^Discover\s+Tab/);check(/Discover|alumni/,'03-student-discovery');
 await tap(/^Map\s+Tab/);check(/Global alumni map/,'04-student-map');
 await tap(/^Network\s+Tab/);check(/My network/,'05-student-network');
 await tap(/^Profile\s+Tab/);check(/Mira Rao/,'06-student-profile');
 await tap(/^Home\s+Tab/);await tap(/^Find a mentor$/);check(/Mentor recommendations/,'07-student-mentors');
 await back();check(/Welcome, Mira Rao/,'08-mentor-android-back');
 await tap(/^Opportunities$/);check(/Career Bridge|Opportunities/,'09-student-opportunities');await back();
 await tap(/^Student$/);await tap(/^Alumni$/);check(/Welcome, Arjun Iyer/,'10-alumni-home');
 await tap(/^Profile\s+Tab/);check(/Arjun Iyer/,'11-alumni-profile');
 await tap(/^Home\s+Tab/);await tap(/^Alumni$/);await tap(/^Staff \/ Faculty$/);check(/Welcome, Kavya Sen/,'12-staff-home');
 await tap(/^Discover\s+Tab/);check(/Discover|alumni/,'13-staff-discovery');
 await tap(/^Home\s+Tab/);await tap(/^Find a mentor$/);check(/Mentor recommendations/,'14-staff-mentors');await back();
 await tap(/^Opportunities$/);check(/Career Bridge|Opportunities/,'15-staff-opportunities');await back();
 await tap(/^Profile\s+Tab/);check(/Kavya Sen/,'16-staff-profile');await tap(/^Home\s+Tab/);
 call(['shell','am','force-stop',PACKAGE]);fs.writeFileSync(output+'/restart-timing.txt',call(['shell','am','start','-W','-n',PACKAGE+'/.MainActivity']));await sleep(1000);
 check(/Welcome, Kavya Sen/,'17-staff-persisted-after-restart');
 await tap(/^Demo controls$/);await tap(/^About simulated data$/);check(/All activity is simulated/,'18-fictional-disclosure');await tap(/^Got it$/);
 await tap(/^Demo controls$/);await tap(/^Exit demo$/);check(/^Explore Demo$/,'19-exit-demo');
 await tap(/^Sign in to real community$/);check(/Backend configuration required|Development setup|Supply SUPABASE|Backend setup/,'20-real-path-fails-closed');
 fs.writeFileSync(output+'/checks.json',JSON.stringify({device:DEVICE,avd:AVD,signed_apk_unchanged:true,offline:true,checks},null,2)+'\n');
 console.log('SIGNED_APK_CHECKS='+checks.length);
}
module.exports={call,ui,label,tap,check,back,sleep,AVD,DEVICE,PACKAGE,output,checks};
if(require.main===module)main().catch(e=>{fs.mkdirSync(output,{recursive:true});fs.writeFileSync(output+'/checks.json',JSON.stringify({device:DEVICE,avd:AVD,checks,failed:e.message},null,2)+'\n');console.error('SIGNED_APK_AUDIT_STOPPED: '+e.message);process.exitCode=1;});
