// All private keys/passwords here are generated synthetic fixtures, never hosted.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {pinnedCa,assertHost,CA_SHA256}=require('./msec_tls_policy.cjs');
const {summarize}=require('./msec_session_diagnostics.cjs');
const {directReadOnly,SQL}=require('./check_msec_secure_connection.cjs');
let passed=0;
const ok=(name,fn)=>{fn();console.log(`PASS TLS ${++passed}: ${name}`);};
const openssl=['C:/Program Files/Git/usr/bin/openssl.exe','C:/Program Files/Git/mingw64/bin/openssl.exe'].find(p=>fs.existsSync(p));
function processCall(exe,args,input,env){const r=cp.spawnSync(exe,args,{input,env,encoding:'utf8',windowsHide:true,timeout:30000,maxBuffer:4*1024*1024});return r;}
function docker(args,input,env){return processCall('docker',args,input,env);}
function required(r){if(r.status!==0)throw Error('Synthetic TLS fixture setup failed; raw output suppressed');return r;}
const id='msgi-tls-test-'+Date.now()+'-'+crypto.randomBytes(4).toString('hex');
const dir=path.resolve('build',id),password=crypto.randomBytes(24).toString('hex');
let started=false;
try{
 ok('Pinned official CA is valid and fingerprint-locked',()=>assert.equal(crypto.createHash('sha256').update(pinnedCa().bytes).digest('hex'),CA_SHA256));
 ok('Changed or unapproved CA bytes fail closed',()=>assert.throws(()=>pinnedCa(Buffer.from('untrusted')),/Unapproved CA/));
 ok('Unexpected production hostname rejected',()=>assert.throws(()=>assertHost('unapproved.invalid'),/Unexpected/));
 ok('Read-only transport cannot execute catalog SQL or approval controls',()=>assert.doesNotMatch(SQL,/insert|update|delete|create|grant|catalog_payload_approved/i));
 ok('Read-only transport forces host networking, pinned readonly CA and strict TLS',()=>{
  const r=directReadOnly({spawn:(cmd,args,o)=>{if(args[0]==='stop')return {status:0};assert(args.includes('host'));assert(args.some(a=>a.includes('/run/msgi-ca.crt,readonly')));assert.equal(o.env.PGSSLMODE,'verify-full');assert.equal(o.env.PGSSLROOTCERT,'/run/msgi-ca.crt');assert.match(o.input.toString(),/^begin read only;/);return {status:2,stderr:'fe_sendauth: no password supplied'};}});assert.equal(r.authenticated,false);assert.equal(r.tls_verified,true);
 });
 if(!openssl)throw Error('Existing Git OpenSSL unavailable; no installation attempted');
 fs.mkdirSync(dir,{mode:0o700});
 const f=n=>path.join(dir,n);
 const generate=args=>required(processCall(openssl,args));
 generate(['req','-x509','-newkey','rsa:2048','-nodes','-keyout',f('ca.key'),'-out',f('ca.crt'),'-subj','/CN=MSGI Synthetic Local Test CA','-days','1']);
 generate(['req','-newkey','rsa:2048','-nodes','-keyout',f('server.key'),'-out',f('server.csr'),'-subj','/CN=localhost']);
 fs.writeFileSync(f('server.ext'),'subjectAltName=DNS:localhost,IP:::1\nextendedKeyUsage=serverAuth\nbasicConstraints=CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\n');
 generate(['x509','-req','-in',f('server.csr'),'-CA',f('ca.crt'),'-CAkey',f('ca.key'),'-CAcreateserial','-out',f('server.crt'),'-days','1','-extfile',f('server.ext')]);
 fs.writeFileSync(f('untrusted.crt'),pinnedCa().bytes);
 const boot="initdb -D /tlsdb -A trust --no-locale --encoding=UTF8 >/tmp/init.log 2>&1 && cp /fixtures/server.key /tmp/server.key && chmod 600 /tmp/server.key && printf '%s\\n' 'local all all trust' 'hostssl all all ::1/128 scram-sha-256' 'host all all ::1/128 reject' > /tlsdb/pg_hba.conf && exec postgres -D /tlsdb -c listen_addresses=::1 -c unix_socket_directories=/tmp -c ssl=on -c ssl_cert_file=/fixtures/server.crt -c ssl_key_file=/tmp/server.key";
 required(docker(['run','-d','--pull','never','--name',id,'--network','none','--read-only','--no-healthcheck','--cap-drop','ALL','--security-opt','no-new-privileges','--user','postgres','--sysctl','net.ipv6.conf.all.disable_ipv6=0','--sysctl','net.ipv6.conf.lo.disable_ipv6=0','--tmpfs','/tlsdb:rw,nosuid,size=384m,uid=100,gid=101,mode=0700','--tmpfs','/tmp:rw,nosuid,size=32m,uid=100,gid=101,mode=0700','--mount',`type=bind,source=${dir},target=/fixtures,readonly`,'--entrypoint','/bin/sh','public.ecr.aws/supabase/postgres:17.11.0.019','-c',boot]));started=true;
 let ready=false;for(let i=0;i<25;i++){if(docker(['exec',id,'pg_isready','-h','/tmp','-U','postgres']).status===0){ready=true;break;}cp.spawnSync('powershell.exe',['-NoProfile','-Command','Start-Sleep -Milliseconds 250'],{windowsHide:true});}assert(ready,'TLS fixture server readiness');
 const admin=sql=>required(docker(['exec','-i',id,'psql','-h','/tmp','-X','-qAt','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],sql));
 admin(`create role tls_fixture login password '${password}';`);
 function client(overrides={},sql="begin read only; select json_build_object('ipv6',inet_server_addr()='::1'::inet,'ssl',(select ssl from pg_stat_ssl where pid=pg_backend_pid()),'readonly',current_setting('transaction_read_only')); commit;",quiet=true){const env={...process.env,PGPASSWORD:password,PGHOST:'localhost',PGHOSTADDR:'::1',PGSSLMODE:'verify-full',PGSSLROOTCERT:'/fixtures/ca.crt',PGCONNECT_TIMEOUT:'3',...overrides};return docker(['exec','-i','--env','PGPASSWORD','--env','PGHOST','--env','PGHOSTADDR','--env','PGSSLMODE','--env','PGSSLROOTCERT','--env','PGCONNECT_TIMEOUT',id,'psql','-X',quiet?'-qAt':'-At','--no-password','-U','tls_fixture','-d','postgres','-v','ON_ERROR_STOP=1','-c',sql],undefined,env);}
 ok('Actual IPv6 TLS chain, hostname, SCRAM authentication and read-only query pass',()=>{const r=required(client());const j=JSON.parse(r.stdout.trim());assert.deepEqual(j,{ipv6:true,ssl:true,readonly:'on'});});
 ok('Actual hostname mismatch rejected despite trusted CA',()=>{const r=client({PGHOST:'wrong.invalid'});assert.notEqual(r.status,0);assert.equal(summarize(r).classification,'tls_validation_failure');});
 ok('Actual untrusted CA rejected with verification enabled',()=>{const r=client({PGSSLROOTCERT:'/fixtures/untrusted.crt'});assert.notEqual(r.status,0);assert.equal(summarize(r).classification,'tls_validation_failure');});
 ok('Actual invalid credentials rejected after verified TLS',()=>{const r=client({PGPASSWORD:crypto.randomBytes(12).toString('hex')});assert.notEqual(r.status,0);assert.equal(summarize(r).classification,'authentication_rejected');});
 ok('Actual COMMIT acknowledgement tracked independently of later operations',()=>{const r=required(client({},'begin read only;select 1;commit;',false));assert.equal(summarize(r).commit_acknowledged,true);});
 ok('Actual connection timeout categorized without retry',()=>{admin("alter system set pre_auth_delay='4';");admin('select pg_reload_conf();');const r=client({PGCONNECT_TIMEOUT:'2'});assert.notEqual(r.status,0);assert.equal(summarize(r).classification,'connection_timeout');});
 fs.writeFileSync('build/task11b5d-tls-test-results.json',JSON.stringify({passed,container:id,network:'none',ipv6_loopback:true,hosted_writes:0},null,2));
 console.log(`All ${passed} TLS tests passed; synthetic keys cleaned after isolated server stops.`);
}catch(e){console.error('TLS validation failed: '+e.message.split('\n')[0]);process.exitCode=1;}
finally{
 if(started)docker(['stop','--timeout','10',id]);
 if(fs.existsSync(dir)){const base=path.resolve('build')+path.sep;if(!dir.startsWith(base))throw Error('Unsafe fixture cleanup path');for(const name of fs.readdirSync(dir))fs.unlinkSync(path.join(dir,name));fs.rmdirSync(dir);}
}
