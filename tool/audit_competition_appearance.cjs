// Restore the frozen release after debug integration, only on the disposable AVD.
const fs=require('node:fs');
const {audit}=require('./audit_competition_apk.cjs');
const {call,ui,label,tap,check,sleep,AVD,PACKAGE,output}=require('./audit_competition_demo.cjs');
async function main(){
 if(process.argv.length!==2||call(['emu','avd','name']).split(/\r?\n/)[0].trim()!==AVD)throw Error('Wrong disposable target');
 audit();call(['uninstall',PACKAGE]);call(['install','--no-streaming','build/competition-release/MSGI-One-1.0.0-competition.apk']);
 call(['shell','am','start','-W','-n',PACKAGE+'/.MainActivity']);await sleep(1200);await tap(/^Explore Demo$/);await tap(/^Student demo/);
 const night=call(['shell','cmd','uimode','night']).match(/Night mode:\s*(auto|yes|no)/i)?.[1];
 const auto=call(['shell','settings','get','system','accelerometer_rotation']).trim(),rotation=call(['shell','settings','get','system','user_rotation']).trim();
 if(!night||![auto,rotation].every(x=>/^(null|[0-3])$/.test(x)))throw Error('Cannot restore disposable appearance state');
 try{
  call(['shell','cmd','uimode','night','yes']);await sleep(800);check(/Welcome, Mira Rao/,'36-system-dark-light-app');
  call(['shell','settings','put','system','accelerometer_rotation','0']);call(['shell','settings','put','system','user_rotation','1']);await sleep(1000);
  check(/Welcome, Mira Rao/,'37-landscape-home');
 }finally{
  call(['shell','cmd','uimode','night',night]);
  for(const [key,value] of [['accelerometer_rotation',auto],['user_rotation',rotation]])call(['shell','settings',value==='null'?'delete':'put','system',key,...(value==='null'?[]:[value])]);
 }
 fs.writeFileSync(output+'/appearance.json',JSON.stringify({passed:['36-system-dark-light-app','37-landscape-home'],app_theme:'intentional light theme',device:AVD,previous_settings_restored:true,frozen_release_restored_after_debug:true},null,2)+'\n');
}
main().catch(e=>{console.error('APPEARANCE_CHECK_STOPPED: '+e.message.split('\n')[0]);process.exitCode=1;});
