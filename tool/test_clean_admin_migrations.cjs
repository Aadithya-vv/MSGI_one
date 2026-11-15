// New network-disabled tmpfs database; schema only, never existing data or resets.
const fs=require('fs'),cp=require('child_process'),crypto=require('crypto');
const name='msgi-admin-clean-'+crypto.randomUUID();let started=false,total=0;
function docker(args,input,allow=false){const r=cp.spawnSync('docker',args,{input,encoding:'utf8',windowsHide:true,timeout:60000,maxBuffer:8*1024*1024});if(r.status!==0&&!allow)throw Error('Isolated database command failed');return r;}
const sql=text=>docker(['exec','-i',name,'psql','-h','/tmp','-X','-qAt','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],text);
try{
 const schema=docker(['exec','supabase_db_msgi_one_clean_9a7b7923','pg_dump','-U','postgres','-d','postgres','--schema-only','--schema=auth','--no-owner','--no-privileges']).stdout;
 docker(['run','--rm','--pull','never','-d','--name',name,'--network','none','--read-only','--no-healthcheck','--user','postgres','--tmpfs','/case:rw,nosuid,size=768m,uid=100,gid=101,mode=0700','--tmpfs','/tmp:rw,nosuid,size=64m,uid=100,gid=101,mode=0700','--entrypoint','/bin/sh','public.ecr.aws/supabase/postgres:17.11.0.019','-c','initdb -D /case -A trust --no-locale --encoding=UTF8 >/tmp/init.log 2>&1 && exec postgres -D /case -c listen_addresses= -c unix_socket_directories=/tmp']);started=true;
 let ready=false;for(let i=0;i<40;i++){if(docker(['exec',name,'pg_isready','-h','/tmp','-U','postgres'],undefined,true).status===0){ready=true;break;}cp.spawnSync('powershell.exe',['-NoProfile','-Command','Start-Sleep -Milliseconds 200'],{windowsHide:true});}if(!ready)throw Error();
 sql('create role anon;create role authenticated;create role service_role;create role supabase_admin;create role supabase_auth_admin;create role supabase_storage_admin;create role authenticator;create role dashboard_user;create schema extensions;'+schema+'\ngrant usage on schema auth,extensions to anon,authenticated,service_role;');
 const files=fs.readdirSync('supabase/migrations').filter(f=>f.endsWith('.sql')).sort();
 for(const file of files){sql(fs.readFileSync('supabase/migrations/'+file));console.log('PASS clean migration: '+file);}
 for(const file of fs.readdirSync('supabase/tests/database').filter(f=>f.endsWith('.sql')).sort()){
  const result=sql(fs.readFileSync('supabase/tests/database/'+file)).stdout;const failed=result.split(/\r?\n/).filter(l=>/^not ok|^#/.test(l));if(failed.some(l=>/^not ok/.test(l))){console.log(failed.join('\n'));throw Error('Assertion failed');}const passed=result.split(/\r?\n/).filter(l=>/^ok \d+/.test(l)).length;total+=passed;console.log('PASS '+file+': '+passed);
 }
 const inspection=JSON.parse(docker(['inspect',name]).stdout)[0];if(inspection.HostConfig.NetworkMode!=='none'||inspection.Mounts.some(m=>m.Type!=='tmpfs'))throw Error();
 const bootstrap=cp.spawnSync(process.execPath,['tool/test_local_bootstrap.cjs'],{env:{...process.env,MSGI_BOOTSTRAP_TEST_CONTAINER:name},encoding:'utf8',windowsHide:true});
 if(bootstrap.status!==0){console.log((bootstrap.stdout||'').split(/\r?\n/).filter(l=>/^(not )?ok|^#\s+(?:died|Failed|have|want)|^1\.\./.test(l)).join('\n'));console.log((bootstrap.stderr||'').split(/\r?\n/).filter(l=>l.startsWith('ERROR:')).join('\n'));throw Error('Clean bootstrap failed');}console.log(bootstrap.stdout.trim());
 console.log('CLEAN_ADMIN_MIGRATIONS='+files.length+'; PGTAP_PASSED='+total+'; NO_NETWORK_OR_SHARED_VOLUMES');
}catch{console.error('CLEAN_ADMIN_MIGRATIONS_FAILED; existing databases preserved; raw output suppressed');process.exitCode=1;}
finally{if(started)docker(['stop','--timeout','5',name],undefined,true);}
