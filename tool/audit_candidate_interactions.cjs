// Additional ordinary-release interactions; only the disposable Task12A AVD.
const fs=require('node:fs');
const {call,ui,label,tap,check,back,sleep,AVD,PACKAGE,output,checks}=require('./audit_candidate_demo.cjs');
async function type(text){
 const n=ui().find(n=>n.class==='android.widget.EditText');if(!n)throw Error('Demo search field unavailable');
 const b=n.bounds.match(/\d+/g).map(Number);call(['shell','input','tap',String((b[0]+b[2])>>1),String((b[1]+b[3])>>1)]);
 call(['shell','input','text',text]);await sleep(300);check(/Search alumni/,'21-keyboard-search');await back();
}
async function main(){
 if(process.argv.length!==2||call(['emu','avd','name']).split(/\r?\n/)[0].trim()!==AVD)throw Error('Wrong disposable target');
 if(!ui().some(n=>label(n)==='Explore Demo')){await tap(/^Demo controls$/);await tap(/^Exit demo$/);}
 await tap(/^Explore Demo$/);await tap(/^Student demo/);
 await tap(/^Demo controls$/);await tap(/^Reset demo$/);await tap(/^Reset demo$/);
 await tap(/^Discover\s+Tab/);
 await type('Anika');await tap(/^Search alumni$/);check(/Anika Bose/,'22-search-result');await tap(/^View profile$/);
 check(/FICTIONAL DEMONSTRATION PROFILE/,'23-fictional-alumni-detail');await tap(/^Connect$/);check(/Request sent/,'24-local-connection-request');await back();
 await tap(/^Home\s+Tab/);call(['shell','am','force-stop',PACKAGE]);call(['shell','am','start','-W','-n',PACKAGE+'/.MainActivity']);await sleep(1000);
 check(/Welcome, Mira Rao/,'25-student-relaunch');await tap(/^Discover\s+Tab/);await type('Anika');await tap(/^Search alumni$/);await tap(/^View profile$/);check(/Request sent/,'26-request-persists-after-relaunch');await back();
 await tap(/^Clear$/);await type('zzzznomatch');await tap(/^Search alumni$/);check(/No alumni found/,'27-empty-search');await tap(/^Clear$/);
 await tap(/^Filter alumni/);check(/Filter alumni/,'28-filter-controls');await back();
 await tap(/^Home\s+Tab/);await tap(/^Student$/);await tap(/^Alumni$/);await tap(/^Find a mentor$/);check(/Mentor recommendations/,'29-alumni-mentors');await back();
 await tap(/^Opportunities$/);
 for(let i=0;i<3&&!ui().some(n=>/Create opportunity/.test(label(n)));i++){
  const chip=ui().find(n=>/All types|Jobs|Internships|Projects|Referrals|Status and sorting/.test(label(n)));
  if(!chip)throw Error('Opportunity filter strip unavailable');const b=chip.bounds.match(/\d+/g).map(Number),y=String((b[1]+b[3])>>1);
  call(['shell','input','swipe','950',y,'130',y,'450']);await sleep(300);
 }
 check(/Create opportunity/,'30-alumni-publishing-action');await back();
 await tap(/^Network\s+Tab/);await tap(/^Incoming$/);check(/Accept/,'31-incoming-request-actions');await tap(/^Accept$/);await tap(/^Connected$/);check(/Mira Rao/,'32-simulated-acceptance');
 await tap(/^Home\s+Tab/);await tap(/^Demo controls$/);await tap(/^Reset demo$/);check(/Reset the demo/,'33-reset-confirmation');await tap(/^Reset demo$/);check(/Welcome, Mira Rao/,'34-reset-student-home');
 // Display scaling and appearance changes are confined to this disposable AVD.
 const priorScale=call(['shell','settings','get','system','font_scale']).trim();
 try{call(['shell','settings','put','system','font_scale','2.0']);await sleep(1000);check(/Welcome, Mira Rao/,'35-large-text-home');}
 finally{if(/^(null|[\d.]+)$/.test(priorScale)){if(priorScale==='null')call(['shell','settings','delete','system','font_scale']);else call(['shell','settings','put','system','font_scale',priorScale]);}}
 await verify();
}
async function verify(){
 if(call(['emu','avd','name']).split(/\r?\n/)[0].trim()!==AVD)throw Error('Wrong disposable target');
 const connectivity=call(['shell','dumpsys','connectivity']);
 const network={wifi:call(['shell','settings','get','global','wifi_on']).trim(),mobile:call(['shell','settings','get','global','mobile_data']).trim(),airplane:call(['shell','cmd','connectivity','airplane-mode']).trim(),active_default_network:connectivity.match(/Active default network:\s*(\S+)/)?.[1]??'unknown'};
 if(network.wifi!=='0'||network.mobile!=='0'||!/enabled/i.test(network.airplane)||network.active_default_network!=='none')throw Error('Offline network evidence mismatch');
 const pid=call(['shell','pidof',PACKAGE]).trim();
 const logs=call(['logcat','-d','--pid='+pid]);
 const diagnostics={crash:/FATAL EXCEPTION|ANR in com\.msgi/.test(logs),layout_error:/RenderFlex overflowed|Unhandled Exception/.test(logs),token_pattern:/access_token=|refresh_token=|sb_secret_[A-Za-z0-9_-]{20,}/.test(logs)};
 const evidence=checks.length?checks:[...Array(15)].map((_,i)=>{const prefix=String(i+21)+'-';const f=fs.readdirSync(output).find(n=>n.startsWith(prefix)&&n.endsWith('.png'));if(!f)throw Error('Missing prior signed interaction evidence');return f.slice(0,-4);});
 fs.writeFileSync(output+'/interactions.json',JSON.stringify({completed:!Object.values(diagnostics).some(Boolean),checks:evidence,network,diagnostics,scope:'signed release on disposable emulator only'},null,2)+'\n');
 if(Object.values(diagnostics).some(Boolean))throw Error('Sampled diagnostics require review');
 console.log('PASS: signed-release search, simulated request/persistence/acceptance, empty state, reset, large text, offline evidence and sampled logs');
}
if(require.main===module)(process.argv.length===3&&process.argv[2]==='--verify-evidence'?verify():main()).catch(e=>{console.error('SIGNED_INTERACTIONS_STOPPED: '+e.message.split('\n')[0]);process.exitCode=1;});
