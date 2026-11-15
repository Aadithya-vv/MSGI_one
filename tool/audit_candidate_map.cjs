// Ordinary signed candidate, exclusively the workspace-owned disposable AVD.
const fs=require('node:fs');
const {call,ui,label,tap,check,back,sleep,AVD,PACKAGE,output}=require('./audit_candidate_demo.cjs');
async function pan(direction,count){
 for(let i=0;i<count;i++)call(['shell','input','swipe',direction>0?'950':'130','1100',direction>0?'130':'950','1100','300']);
 await sleep(1000);
}
async function main(){
 const finish=process.argv.length===3&&process.argv[2]==='--finish';
 if((process.argv.length!==2&&!finish)||call(['emu','avd','name']).split(/\r?\n/)[0].trim()!==AVD)throw Error('Wrong disposable target');
 const checks=[];
 if(!finish){
 await tap(/^Home\s+Tab/);await tap(/^Map\s+Tab/);await sleep(800);
 for(let i=0;i<5;i++)await tap(/^Zoom out$/);
 for(let zoom=0;zoom<3;zoom++){
  if(zoom)await tap(/^Zoom in$/);
  await pan(1,12);check(/Global alumni map/,'map-'+zoom+'-east');
  await pan(1,5);check(/Global alumni map/,'map-'+zoom+'-east-repeat');
  await pan(-1,24);check(/Global alumni map/,'map-'+zoom+'-west');
  await pan(-1,5);check(/Global alumni map/,'map-'+zoom+'-west-repeat');
  checks.push('zoom-'+zoom+'-both-edges');
 }
 }else{
  for(let z=0;z<3;z++)for(const edge of ['east','east-repeat','west','west-repeat'])if(!fs.existsSync(output+'/map-'+z+'-'+edge+'.png'))throw Error('Prior boundary evidence missing');
  checks.push('zoom-0-both-edges','zoom-1-both-edges','zoom-2-both-edges');
 }
 await tap(/^World view$/);await sleep(800);
 // Filter to a single city so its map marker (not the list row) is identifiable.
 const field=ui().find(n=>n.class==='android.widget.EditText');
 if(!field)throw Error('Map search unavailable');
 const box=field.bounds.match(/\d+/g).map(Number);
 call(['shell','input','tap',String((box[0]+box[2])>>1),String((box[1]+box[3])>>1)]);
 if(field.text===''||field.text==='City or country')call(['shell','input','text','London']);
 else if(field.text!=='London')throw Error('Unexpected prior map search; inspect before continuing');
 await back();await tap(/^Search$/);await sleep(800);
 // Android exposes the outer map semantics at viewport bounds; target the
 // painted numeric button after filtering, not that large semantics container.
 const marker=ui().find(n=>/^\d+$/.test(label(n))&&n.clickable==='true');
 if(!marker)throw Error('Painted city marker unavailable');
 await tap(new RegExp('^'+label(marker)+'$'));check(/London alumni/,'map-city-detail');
 await tap(/^Home\s+Tab/);call(['shell','input','keyevent','3']);await sleep(500);
 call(['shell','am','start','-W','-n',PACKAGE+'/.MainActivity']);await sleep(800);check(/Welcome, Mira Rao/,'candidate-background-resume');
 call(['shell','am','start','-W','-a','android.intent.action.VIEW','-d','com.msgi.one.dev://auth-callback/?code=task12c-invalid',PACKAGE]);
 await sleep(800);check(/Welcome, Mira Rao/,'candidate-callback-ignored');
 await tap(/^Demo controls$/);await tap(/^Exit demo$/);check(/Offline competition demonstration/,'candidate-exit');
 await tap(/^Explore Demo$/);await tap(/^Student demo/);check(/Welcome, Mira Rao/,'candidate-reentry');
 fs.writeFileSync(output+'/map-acceptance.json',JSON.stringify({completed:true,checks,ordinary_signed_candidate:true,edge_pixel_comparison_pending:true},null,2)+'\n');
}
main().catch(e=>{console.error('CANDIDATE_MAP_STOPPED: '+e.message.split('\n')[0]);process.exitCode=1;});
