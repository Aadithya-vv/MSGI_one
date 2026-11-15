// Safe local evidence inventory. Never copies APKs, keys, config or raw logs to Git.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const read=f=>JSON.parse(fs.readFileSync(f,'utf8').replace(/^\uFEFF/,''));
const textFile=f=>{const b=fs.readFileSync(f);return b[0]===255&&b[1]===254?b.toString('utf16le'):b.toString('utf8');};
function record(){
 const inspection=read('build/task12a/apk-inspection.json'),base=read('build/task12a/signed-apk/checks.json'),extra=read('build/task12a/signed-apk/interactions.json'),appearance=read('build/task12a/signed-apk/appearance.json'),driver=read('build/task08/demo-driver-summary.json');
 const apk='build/competition-release/MSGI-One-1.0.0-competition.apk';
 assert.equal(sha(fs.readFileSync(apk)),'aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809');
 assert.equal(inspection.findings.length,0);assert(extra.completed&&driver.completed);assert(!Object.values(extra.diagnostics).some(Boolean));
 const checks=[...new Set([...base.checks,...extra.checks,...appearance.passed])];assert.equal(checks.length,38);
 assert(/\+197: All tests passed/.test(textFile('build/task12a/flutter-tests.log')),'Flutter test success evidence missing');
 assert(/All tests passed\./.test(textFile('build/task12a/source-integration.log')),'Source integration success evidence missing');
 const signature=textFile('build/task12a/apk-signature.txt');
 assert.match(signature,/APK Signature Scheme v2\): true/);assert(signature.includes('857fbe0fc6d3366bb46c59745fce24eb03cef23b78a6b030a24148fb0d995cc4'));
 const sourceDirectory='build/task12a/source-integration-screenshots';fs.mkdirSync(sourceDirectory,{recursive:true});
 const sourceImages=driver.screenshots.map(c=>{
  const source='build/task08/screenshots/'+c+'.png',destination=sourceDirectory+'/'+c+'.png';
  if(fs.existsSync(destination))assert.equal(sha(fs.readFileSync(destination)),sha(fs.readFileSync(source)),'Frozen source evidence differs; do not overwrite');
  else fs.copyFileSync(source,destination,fs.constants.COPYFILE_EXCL);
  return destination;
 });
 const files=[apk,...checks.map(c=>'build/task12a/signed-apk/'+c+'.png'),...sourceImages];
 const inventory=files.map(file=>{const b=fs.readFileSync(file);return {file,bytes:b.length,sha256:sha(b)};});
 const result={date:'2026-11-15',starting_commit:'dbc2d45ab51285ac757f90186c5e4ee94afd1959',artifact_frozen:true,
  package:'com.msgi.nexus.msgi_nexus',version_name:'1.0.0',version_code:1,min_api:24,target_api:36,
  certificate_sha256:'857fbe0fc6d3366bb46c59745fce24eb03cef23b78a6b030a24148fb0d995cc4',
  device:{avd:'MSGI_Task12A_Disposable',id:'emulator-5556',api:34,disposable:true,physical_device_touched:false},
  signed_release_checks:checks,network:extra.network,sampled_diagnostics:extra.diagnostics,
  source_results:{formatter_files:97,format_changes:0,analyzer_issues:0,flutter_tests:197,android_integration_journeys:1,debug_screenshots:driver.screenshots.length},
  limitations:['No official organizer rules supplied','Signing recovery unverified','No new hosted or physical-device acceptance','No screen-reader or sustained release-performance sign-off','Source tests are separate from signed binary checks'],
  files:inventory,uploads:0,hosted_operations:0};
 fs.writeFileSync('docs/competition-release-manifest.json',JSON.stringify(result,null,2)+'\n');
 fs.copyFileSync('build/task12a/dependencies.json','docs/competition-dependency-inventory.json');
 console.log(JSON.stringify({signed_release_checks:checks.length,source_integration_journeys:1,signed_screenshots:checks.length,source_screenshots:driver.screenshots.length,artifact_unchanged:true}));
}
module.exports={record};if(require.main===module)record();
