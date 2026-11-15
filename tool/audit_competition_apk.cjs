// Inspect only: no signing material, build, installation or backend configuration.
const fs=require('node:fs'),zlib=require('node:zlib'),crypto=require('node:crypto');
const APK='build/competition-release/MSGI-One-1.0.0-competition.apk';
const EXPECTED='aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809';
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function audit(){
 const b=fs.readFileSync(APK);if(sha(b)!==EXPECTED)throw Error('Protected APK identity changed; stop release replacement');
 let end=-1;for(let i=b.length-22;i>=Math.max(0,b.length-65557);i--)if(b.readUInt32LE(i)===0x06054b50){end=i;break;}
 if(end<0)throw Error('ZIP directory missing');
 const count=b.readUInt16LE(end+10);let p=b.readUInt32LE(end+16);const entries=[],findings=[];
 for(let n=0;n<count;n++){
  if(b.readUInt32LE(p)!==0x02014b50)throw Error('ZIP directory invalid');
  const method=b.readUInt16LE(p+10),size=b.readUInt32LE(p+20),plain=b.readUInt32LE(p+24),nl=b.readUInt16LE(p+28),el=b.readUInt16LE(p+30),cl=b.readUInt16LE(p+32),off=b.readUInt32LE(p+42),name=b.toString('utf8',p+46,p+46+nl);p+=46+nl+el+cl;
  if(name.includes('..')||name.startsWith('/')||b.readUInt32LE(off)!==0x04034b50)throw Error('Unsafe ZIP entry');
  const start=off+30+b.readUInt16LE(off+26)+b.readUInt16LE(off+28),raw=b.subarray(start,start+size);
  const data=method===0?raw:method===8?zlib.inflateRawSync(raw):null;
  if(!data||data.length!==plain)throw Error('ZIP entry unreadable');
  entries.push({name,bytes:plain});
  if(/\.(p12|pfx|jks|keystore|key|dpapi)$|(^|\/)\.env(?:\.|$)|backend\.local\.json|key\.properties/i.test(name))findings.push({category:'private_file',entry:name});
  if(/\.(so|dex|json|xml|txt)$/.test(name)){
   const text=data.toString('latin1');
   if(/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/.test(text)||/sb_secret_[A-Za-z0-9_-]{20,}/.test(text))findings.push({category:'private_key_pattern',entry:name});
   if(text.includes('sbgshejyvkptmrffiwvd'))findings.push({category:'hosted_project_literal',entry:name});
   for(const jwt of text.matchAll(/eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{10,}/g)){
    try{if(JSON.parse(Buffer.from(jwt[0].split('.')[1],'base64url')).role==='service_role')findings.push({category:'privileged_jwt',entry:name});}catch{}
   }
  }
 }
 const result={apk:APK,sha256:EXPECTED,bytes:b.length,zip_entries:entries.length,all_zip_entries_readable:true,
  bundled_map:entries.some(e=>e.name.endsWith('assets/maps/ne_110m_land.geojson')),bundled_license_notice:entries.some(e=>/NOTICES/.test(e.name)),
  kernel_blob:entries.some(e=>/kernel_blob\.bin/.test(e.name)),native_app_abis:entries.filter(e=>/^lib\/[^/]+\/libapp\.so$/.test(e.name)).map(e=>e.name.split('/')[1]),findings,
  limitations:'Static pattern scan is not proof against all obfuscated secrets or runtime network activity. No private config/key file was opened.'};
 fs.mkdirSync('build/task12a',{recursive:true});fs.writeFileSync('build/task12a/apk-inspection.json',JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify(result));if(findings.length)process.exitCode=1;
 return result;
}
module.exports={audit};if(require.main===module)audit();
