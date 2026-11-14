// Presentation-only acceptance. No backend configuration, account or key is read.
const fs=require('fs'),cp=require('child_process'),path=require('path');
const adb=path.join(process.env.LOCALAPPDATA,'Android/Sdk/platform-tools/adb.exe');
const run=(...args)=>cp.execFileSync(adb,['-s','emulator-5554',...args],{encoding:'utf8',stdio:['pipe','pipe','pipe'],timeout:30000});
let wifi,data,passed=false;
try{
 if(run('get-state').trim()!=='device')throw Error('Preferred emulator unavailable');
 wifi=run('shell','settings','get','global','wifi_on').trim();data=run('shell','settings','get','global','mobile_data').trim();
 if(!['0','1'].includes(wifi)||!['0','1'].includes(data))throw Error('Cannot safely restore emulator network state');
 fs.mkdirSync('build/task08',{recursive:true});
 fs.writeFileSync('build/task08/emulator-network.json',JSON.stringify({wifi,data}));
 run('shell','svc','wifi','disable');run('shell','svc','data','disable');
 console.log('Emulator-only Wi-Fi/mobile data disabled for offline demo acceptance.');
 const result=cp.spawnSync('cmd.exe',['/d','/c','flutter drive --driver=test_driver/demo_driver.dart --target=integration_test/demo_experience_test.dart -d emulator-5554 --no-pub --debug --keep-app-running > build/task08-emulator.log 2>&1'],{stdio:'pipe',timeout:600000});
 if(result.status!==0)throw Error('Demo journeys failed');
 const logs=run('logcat','-d','-s','flutter:I');
 if(/access_token=|refresh_token=|RenderFlex overflowed|Unhandled Exception/.test(logs))throw Error('Unexpected diagnostic pattern');
 passed=true;
 console.log('PASS: Offline Student, Alumni and Staff journeys, persisted demo restoration, reset and data-isolation sentinel.');
 console.log('PASS: No HTTP client creation in app journey; no sampled token/overflow/exception patterns.');
 console.log('Screenshots: build/task08/screenshots');
}catch{
 console.error('DEMO_EMULATOR_ACCEPTANCE_FAILED; inspect the ignored local log safely.');process.exitCode=1;
}finally{
 try{
  if(['0','1'].includes(wifi))run('shell','svc','wifi',wifi==='1'?'enable':'disable');
  if(['0','1'].includes(data))run('shell','svc','data',data==='1'?'enable':'disable');
  console.log('Prior emulator Wi-Fi/mobile data settings restored.');
 }catch{console.error('EMULATOR_NETWORK_RESTORE_FAILED; restore the settings recorded in build/task08/emulator-network.json.');process.exitCode=1;}
}
