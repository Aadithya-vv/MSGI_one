// Fixed debug candidate and disposable emulator only. Never targets Samsung.
const fs=require('node:fs'),cp=require('node:child_process'),path=require('node:path');
const DEVICE='emulator-5556',AVD='MSGI_Task12A_Disposable',PACKAGE='com.msgi.nexus.msgi_nexus';
const folder='build/logo-integration',apk=folder+'/MSGI-One-logo-debug.apk';
const adb=path.join(process.env.LOCALAPPDATA,'Android/Sdk/platform-tools/adb.exe');
const call=(args,binary=false)=>cp.execFileSync(adb,['-s',DEVICE,...args],{encoding:binary?null:'utf8',windowsHide:true,stdio:['pipe','pipe','pipe'],timeout:30000,maxBuffer:8*1024*1024});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
function capture(name){fs.writeFileSync(folder+'/'+name+'.png',call(['exec-out','screencap','-p'],true));}
const decode=s=>s.replace(/&#(\d+);/g,(_,n)=>String.fromCodePoint(Number(n))).replace(/&amp;/g,'&');
function ui(){call(['shell','uiautomator','dump','/sdcard/msgi-logo-test.xml']);return [...call(['shell','cat','/sdcard/msgi-logo-test.xml']).matchAll(/<node\s+([^>]+)>?/g)].map(m=>Object.fromEntries([...m[1].matchAll(/([\w-]+)="([^"]*)"/g)].map(a=>[a[1],decode(a[2])])));}
const label=n=>(n.text||'')+(n['content-desc']||'');
async function tap(pattern){const n=ui().find(n=>pattern.test(label(n)));if(!n)throw Error('Control unavailable: '+pattern.source);const b=n.bounds.match(/\d+/g).map(Number);call(['shell','input','tap',String((b[0]+b[2])>>1),String((b[1]+b[3])>>1)]);await sleep(700);}
function check(pattern,name){let found=false;for(let n=0;n<5;n++){if(ui().some(node=>pattern.test(label(node)))){found=true;break;}}if(!found)throw Error('Screen assertion failed: '+name);capture(name);console.log('PASS logo debug: '+name);}
async function main(){
 if(process.argv.length!==2||call(['emu','avd','name']).split(/\r?\n/)[0].trim()!==AVD||call(['shell','getprop','sys.boot_completed']).trim()!=='1')throw Error('Verified disposable emulator required');
 if(!fs.existsSync(apk))throw Error('Separate debug candidate missing');
 const existing=cp.spawnSync(adb,['-s',DEVICE,'shell','pm','path',PACKAGE],{encoding:'utf8',windowsHide:true,timeout:30000});
 if(![0,1].includes(existing.status))throw Error('Cannot inspect disposable installation');
 if(existing.stdout.trim())call(['uninstall',PACKAGE]);
 call(['shell','svc','wifi','disable']);call(['shell','svc','data','disable']);call(['shell','cmd','connectivity','airplane-mode','enable']);
 call(['install','--no-streaming',apk]);
 call(['shell','input','keyevent','3']);await sleep(800);call(['shell','input','swipe','540','2050','540','800','600']);await sleep(800);capture('launcher-icon');
 const launch=cp.spawn(adb,['-s',DEVICE,'shell','am','start','-W','-n',PACKAGE+'/.MainActivity'],{windowsHide:true,stdio:['ignore','pipe','pipe']});
 const finished=new Promise((resolve,reject)=>{launch.on('error',reject);launch.on('exit',code=>code===0?resolve():reject(Error('Cold launch failed')));});
 for(const [name,delay] of [['native-startup-1',150],['native-startup-2',300],['native-startup-3',500]]){await sleep(delay);capture(name);}
 await finished;await sleep(1200);check(/^Explore Demo$/,'welcome-logo');
 await tap(/^Explore Demo$/);check(/Choose a perspective/,'role-selection-logo');await tap(/^Student demo/);check(/Welcome, Mira Rao/,'student-header-logo');
 await tap(/^Find a mentor$/);check(/Mentor recommendations/,'mentor-header-logo');call(['shell','input','keyevent','4']);await sleep(500);
 await tap(/^Student$/);await tap(/^Alumni$/);check(/Welcome, Arjun Iyer/,'alumni-header-logo');await tap(/^Profile\s+Tab/);check(/Arjun Iyer/,'profile-header-logo');await tap(/^Home\s+Tab/);
 await tap(/^Alumni$/);await tap(/^Staff \/ Faculty$/);check(/Welcome, Kavya Sen/,'staff-header-logo');
 const scale=call(['shell','settings','get','system','font_scale']).trim();
 try{call(['shell','settings','put','system','font_scale','2.0']);await sleep(1000);check(/Welcome, Kavya Sen/,'large-text-emblem-header');}
 finally{call(['shell','settings',scale==='null'?'delete':'put','system','font_scale',...(scale==='null'?[]:[scale])]);}
 const pid=call(['shell','pidof',PACKAGE]).trim();if(!/^\d+$/.test(pid))throw Error('App process missing');
 const logs=call(['logcat','-d','--pid='+pid]);
 const diagnostics={crash:/FATAL EXCEPTION|ANR in com\.msgi/.test(logs),render_error:/RenderFlex overflowed|Unhandled Exception|Unable to load asset/.test(logs)};
 fs.writeFileSync(folder+'/emulator-acceptance.json',JSON.stringify({completed:!Object.values(diagnostics).some(Boolean),device:DEVICE,avd:AVD,debug_only:true,samsung_operations:0,diagnostics},null,2));
 if(Object.values(diagnostics).some(Boolean))throw Error('Sampled diagnostics need review');
}
main().catch(e=>{console.error('LOGO_DEBUG_STOPPED: '+e.message.split('\n')[0]);process.exitCode=1;});
