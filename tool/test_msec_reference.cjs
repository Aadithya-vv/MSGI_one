// Actual SQL tests run ONLY in a newly created network-disabled tmpfs cluster.
const fs = require('node:fs');
const cp = require('node:child_process');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const { run, OVERRIDES } = require('./deploy_msec_reference.cjs');
const { render, hash, normalize } = require('./render_msec_reference.cjs');
const { executionPlan, executeDedicated, psqlOperations, CONTROLS, sha256 } = require('./msec_catalog_session.cjs');
const { CONTRACT_SHA256 } = require('./supabase_cli_json.cjs');
const responseFlag='--approve-cli-response-sha256='+CONTRACT_SHA256;
const planFlag='--approve-execution-plan-sha256='+executionPlan().execution_plan_sha256;
const manifest = JSON.parse(fs.readFileSync('supabase/catalogs/msec_reference_manifest.json', 'utf8'));
const bundle = normalize(fs.readFileSync('supabase/catalogs/msec_reference_atomic.sql', 'utf8'));
const approval = "set msgi.catalog_payload_approved='msec-reference-v1';\n";
let passed = 0;
function ok(name, action) { action(); console.log(`PASS ${++passed}: ${name}`); }
function runnerTests() {
  const baseRead = p => fs.readFileSync(p, 'utf8');
  const calls = [];
  const cli = args => { calls.push(args); throw Error('Unexpected CLI call'); };
  const refuses = (args, patch = {}, pattern) => {
    calls.length = 0;
    assert.throws(() => run(args, { read: baseRead, env: {}, cli, ...patch }), pattern);
    assert.equal(calls.length, 0);
  };
  ok('Wrong project refuses before CLI/SQL', () => refuses(['--project-ref=wrong'], {}, /Wrong project/));
  ok('Altered bundle refuses before CLI/SQL', () => refuses([], { read: p => baseRead(p) + (p.endsWith('msec_reference_atomic.sql') ? '\n--changed' : '') }, /hash/));
  ok('Wrong linked project refuses', () => refuses([], { read: p => p.endsWith('project-ref') ? 'wrong' : baseRead(p) }, /linked project/));
  ok('Missing hash-bound execution approval refuses', () => refuses(['--execute'], {}, /approval/));
  ok('Wrong execution approval hash refuses', () => refuses(['--execute','--approve-sha256=wrong'], {}, /approval/));
  ok('Connection-string argument refused', () => refuses(['--db-url=postgresql://invalid'], {}, /argument/));
  ok('Conflicting read-only and execution flags refused', () => refuses(['--check','--execute'], {}, /Conflicting/));
  for (const key of OVERRIDES) ok(`${key} override refused without SQL`, () => refuses([], { env: { [key]: 'untrusted' } }, /override/));
  const project = { id: manifest.project_ref, ref: manifest.project_ref, linked: true, region: 'ap-northeast-2', database: { host: `db.${manifest.project_ref}.supabase.co` } };
  ok('Wrong authenticated database host refuses before SQL', () => {
    let queries = 0;
    assert.throws(() => run([], { read: baseRead, env: {}, cli: args => { if (args[0] === 'db') queries++; return { projects: [{ ...project, database: { host: 'wrong' } }] }; } }), /metadata mismatch/);
    assert.equal(queries, 0);
  });
  ok('Unexpected cached host refuses before SQL', () => {
    let queries = 0;
    assert.throws(() => run([], { read: p => p.endsWith('pooler-url') ? `postgresql://postgres.${manifest.project_ref}@evil.invalid/postgres` : baseRead(p), env: {}, cli: args => { if (args[0] === 'db') queries++; return { projects: [project] }; } }), /Unexpected database/);
    assert.equal(queries, 0);
  });
  ok('Manifest reproduces all exact reviewed SQL bytes', () => {
    const out = render(manifest);
    assert.equal(out.bundle, bundle);
    assert.equal(out.msec, normalize(fs.readFileSync('supabase/catalogs/msec.sql','utf8')));
    assert.equal(out.skills, normalize(fs.readFileSync('supabase/catalogs/starter_skills_proposed.sql','utf8')));
    assert.equal(manifest.programmes.length, 13);
    assert.equal(new Set(manifest.skills.map(s => s.name.toLowerCase())).size, 36);
  });
  ok('No privilege, user or Auth mutation SQL', () => assert.doesNotMatch(bundle.replace(/^--.*$/gm,''), /\b(?:grant|revoke|create\s+role|alter\s+table|delete\s+from|update\s+public\.|insert\s+into\s+(?:auth|private)\.)/i));
  const versions=['20261112000100','20261112000200','20261112000300','20261113000100','20261113000200','20261113000300','20261114000100','20261114000200','20261114000300','20261114000400','20261114000500'];
  function simulated(options={}) {
    let writes=0, reads=0;
    const cli=args=>{
      if(args[0]==='projects')return {projects:[project]};
      if(args[0]==='migration')return {target:{project_ref:manifest.project_ref},migrations:versions.map(v=>({local:v,remote:v}))};
      if(!args.includes('--read-only')){writes++;return {rows:[]};}
      reads++;
      return {rows:[{catalog_preflight:{read_only:'on',database:'postgres',version:17,history:versions,rls_tables:4,
        institutions_conflict:!!options.conflict,departments_conflict:false,programmes_conflict:false,skills_conflict:false,
        institutions_count:writes?(options.badPost?0:1):0,departments_count:writes?1:0,programmes_count:writes?13:0,skills_count:writes?36:0}}]};
    };
    return {cli,session:()=>{writes++;},counts:()=>({writes,reads})};
  }
  ok('Read-only mode never invokes a write, even with matching approval',()=>{const s=simulated();run(['--check','--approve-sha256='+hash(bundle)],{read:baseRead,env:{},cli:s.cli,session:s.session});assert.deepEqual(s.counts(),{writes:0,reads:1});});
  ok('Exact approval executes one atomic write and independently verifies read-only',()=>{const s=simulated();run(['--execute','--approve-sha256='+hash(bundle),planFlag,responseFlag],{read:baseRead,env:{},cli:s.cli,session:s.session});assert.deepEqual(s.counts(),{writes:1,reads:2});});
  ok('Conflict preflight refuses before a write',()=>{const s=simulated({conflict:true});assert.throws(()=>run(['--execute','--approve-sha256='+hash(bundle),planFlag,responseFlag],{read:baseRead,env:{},cli:s.cli,session:s.session}),/preflight/);assert.equal(s.counts().writes,0);});
  ok('Bad post-write verification stops without retry',()=>{const s=simulated({badPost:true});assert.throws(()=>run(['--execute','--approve-sha256='+hash(bundle),planFlag,responseFlag],{read:baseRead,env:{},cli:s.cli,session:s.session}),/Post-write/);assert.equal(s.counts().writes,1);});
  ok('Missing new execution-plan approval refuses before CLI',()=>refuses(['--execute','--approve-sha256='+hash(bundle)],{},/execution plan/));
  ok('Missing renewed response-contract review refuses before CLI',()=>refuses(['--execute','--approve-sha256='+hash(bundle),planFlag],{},/Renewed execution-plan review/));
  ok('Raw CRLF substitution refuses despite normalized hash equality',()=>refuses([],{read:p=>p.endsWith('msec_reference_atomic.sql')?baseRead(p).replace(/\n/g,'\r\n'):baseRead(p)},/Raw payload/));
  ok('Dedicated adapter sends exact original bytes separately from controls',()=>{
    const secret='synthetic-local-only';let calls=0;
    executeDedicated({payload:Buffer.from(bundle),project:manifest.project_ref,host:`db.${manifest.project_ref}.supabase.co`,password:secret,spawn:(cmd,args,options)=>{
      calls++;if(args[0]==='stop')return {status:0};
      assert.equal(cmd,'docker');assert(Buffer.isBuffer(options.input));assert.equal(sha256(options.input),hash(bundle));
      assert(!args.join(' ').includes(secret));assert.equal(options.env.PGPASSWORD,secret);assert.equal(options.env.PGSSLMODE,'verify-full');
      assert(args.includes('-f'));assert(args.includes(CONTROLS.set));assert(!options.input.toString().startsWith('set msgi.'));
      return {status:0};
    }});assert.equal(calls,2);
  });
  ok('Dedicated adapter rejects wrong project before any transport',()=>assert.throws(()=>executeDedicated({payload:Buffer.from(bundle),project:'wrong',host:'wrong',password:'synthetic',spawn:()=>assert.fail('transport called')}),/target mismatch/));
  ok('Dedicated adapter rejects missing credential before transport',()=>assert.throws(()=>executeDedicated({payload:Buffer.from(bundle),project:manifest.project_ref,host:`db.${manifest.project_ref}.supabase.co`,spawn:()=>assert.fail('transport called')}),/SUPABASE_DB_PASSWORD/));
  ok('Dedicated adapter rejects altered raw stdin before transport',()=>assert.throws(()=>executeDedicated({payload:Buffer.from(bundle+'\n'),project:manifest.project_ref,host:`db.${manifest.project_ref}.supabase.co`,password:'synthetic',spawn:()=>assert.fail('transport called')}),/byte identity/));
}
function docker(args, input, allowedFailure = false) {
  const r = cp.spawnSync('docker', args, { input, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
  if (r.status !== 0 && !allowedFailure) throw Error('Isolated Docker/SQL step failed; raw response suppressed');
  return r;
}
function databaseTests() {
  const id = 'msgi-catalog-test-' + Date.now() + '-' + crypto.randomBytes(4).toString('hex');
  const image = 'public.ecr.aws/supabase/postgres:17.11.0.019';
  // Schema only: no existing accounts, catalog data, tokens or passwords copied.
  const schema = docker(['exec','supabase_db_msgi_one_clean_9a7b7923','pg_dump','-U','postgres','-d','postgres','--schema-only','--schema=public','--schema=private','--schema=auth','--no-owner','--no-privileges']).stdout;
  let started = false, serial = 0;
  const sql = (db, text, fail = false) => docker(['exec','-i',id,'psql','-h','/tmp','-X','-qAt','-U','postgres','-d',db,'-v','ON_ERROR_STOP=1'], text, fail);
  const snapshot = db => sql(db, `select jsonb_build_object('i',(select coalesce(jsonb_agg(to_jsonb(x)||jsonb_build_object('xmin',xmin::text,'ctid',ctid::text) order by id),'[]') from public.institutions x),'d',(select coalesce(jsonb_agg(to_jsonb(x)||jsonb_build_object('xmin',xmin::text,'ctid',ctid::text) order by id),'[]') from public.departments x),'p',(select coalesce(jsonb_agg(to_jsonb(x)||jsonb_build_object('xmin',xmin::text,'ctid',ctid::text) order by id),'[]') from public.programmes x),'s',(select coalesce(jsonb_agg(to_jsonb(x)||jsonb_build_object('xmin',xmin::text,'ctid',ctid::text) order by id),'[]') from public.skills x));`).stdout.trim();
  const fresh = () => {
    const db = 'case_' + (++serial);
    docker(['exec',id,'createdb','-h','/tmp','-U','postgres',db]);
    sql(db, 'drop schema public;\n' + schema);
    return db;
  };
  const reject = (name, setup) => ok(name, () => {
    const db = fresh(); setup(db);
    const before = hash(snapshot(db));
    assert.notEqual(sql(db, approval + bundle, true).status, 0);
    assert.equal(hash(snapshot(db)), before);
  });
  const seedInstitution = db => sql(db, `insert into public.institutions(id,name,catalog_key,active) values('${manifest.institution.id}','${manifest.institution.name}','msec',true);`);
  try {
    docker(['run','--pull','never','-d','--name',id,'--network','none','--read-only','--no-healthcheck','--cap-drop','ALL','--security-opt','no-new-privileges','--memory','1536m','--user','postgres','--tmpfs','/catalog:rw,noexec,nosuid,size=768m,uid=100,gid=101,mode=0700','--tmpfs','/tmp:rw,noexec,nosuid,size=128m,uid=100,gid=101,mode=0700','--entrypoint','/bin/sh',image,'-c','initdb -D /catalog -A trust --no-locale --encoding=UTF8 >/tmp/init.log 2>&1 && exec postgres -D /catalog -c listen_addresses= -c unix_socket_directories=/tmp']);
    started = true;
    let ready = false;
    for (let i=0;i<40;i++) { if (docker(['exec',id,'pg_isready','-h','/tmp','-U','postgres'],undefined,true).status === 0) { ready=true; break; } cp.spawnSync('powershell.exe',['-NoProfile','-Command','Start-Sleep -Milliseconds 250'],{windowsHide:true}); }
    assert(ready);
    sql('postgres', "create role anon;create role authenticated;create role service_role;create role supabase_admin;create role supabase_auth_admin;create role supabase_storage_admin;create role dashboard_user;create role authenticator;");
    const inspect = JSON.parse(docker(['inspect',id]).stdout)[0];
    ok('Disposable destination has no network, shared volumes or ports', () => { assert.equal(inspect.HostConfig.NetworkMode,'none');assert.equal(inspect.Mounts.filter(m=>m.Type!=='tmpfs').length,0);assert.equal(Object.keys(inspect.HostConfig.PortBindings||{}).length,0); });
    const db = fresh();
    ok('Empty catalogs insert exactly 51 rows atomically', () => {
      assert.equal(sql(db, approval+bundle).status,0);
      const s=JSON.parse(snapshot(db));assert.deepEqual([s.i.length,s.d.length,s.p.length,s.s.length],[1,1,13,36]);
      assert.deepEqual(s.p.map(p=>[p.id,p.application_key,p.name,p.level,p.institution_id,p.active]).sort(),manifest.programmes.map(p=>[p.id,p.application_key,p.name,p.level,p.institution_id,p.active]).sort());
    });
    ok('Identical rerun changes no UUID, timestamp, xmin or ctid', () => {const before=hash(snapshot(db));sql(db,approval+bundle);assert.equal(hash(snapshot(db)),before);});
    reject('Conflicting institution name rolls back', d=>{seedInstitution(d);sql(d,"update public.institutions set name='Conflict';");});
    reject('Conflicting programme name rolls back', d=>{sql(d,approval+bundle);sql(d,"update public.programmes set name='Conflict' where application_key='msec-ug-cse';");});
    reject('Conflicting programme level rolls back', d=>{sql(d,approval+bundle);sql(d,"update public.programmes set level='postgraduate' where application_key='msec-ug-cse';");});
    reject('Institution UUID/key mapping mismatch rolls back', d=>{seedInstitution(d);sql(d,"update public.institutions set catalog_key='wrong';");});
    reject('Natural institution key with another UUID rolls back', d=>sql(d,`insert into public.institutions(name,catalog_key) values('${manifest.institution.name}','msec');`));
    reject('Programme key with another UUID rolls back', d=>{seedInstitution(d);sql(d,`insert into public.programmes(institution_id,application_key,name,level) values('${manifest.institution.id}','msec-ug-cse','B.E. Computer Science and Engineering','undergraduate');`);});
    ok('Matching skill preserves its existing UUID',()=>{const d=fresh();sql(d,"insert into public.skills(id,name) values('b0000000-0000-4000-8000-000000000001','Python');");sql(d,approval+bundle);assert.equal(sql(d,"select id from public.skills where name='Python';").stdout.trim(),'b0000000-0000-4000-8000-000000000001');});
    reject('Case alias rejects and rolls back institution/programme inserts',d=>sql(d,"insert into public.skills(name) values('python');"));
    reject('Whitespace skill alias rejected',d=>sql(d,"insert into public.skills(name) values(' Python ');"));
    reject('Unrelated institution preserved with deployment refusal',d=>sql(d,"insert into public.institutions(name,catalog_key) values('[SYNTHETIC LOCAL] Other','other');"));
    reject('Unexpected skill preserved with deployment refusal',d=>sql(d,"insert into public.skills(name) values('[SYNTHETIC LOCAL] Extra');"));
    reject('Inactive authoritative state rejected',d=>{seedInstitution(d);sql(d,'update public.institutions set active=false;');});
    ok('Injected late failure leaves zero partial records',()=>{const d=fresh();const broken=bundle.replace(/commit;\s*$/, "do $failure$ begin raise exception 'Synthetic late failure'; end $failure$;\ncommit;");assert.notEqual(sql(d,approval+broken,true).status,0);const s=JSON.parse(snapshot(d));assert.deepEqual([s.i.length,s.d.length,s.p.length,s.s.length],[0,0,0,0]);});
    ok('Direct SQL without approval is refused',()=>{const d=fresh();assert.notEqual(sql(d,bundle,true).status,0);const s=JSON.parse(snapshot(d));assert.equal(s.i.length,0);});
    const session=(d,bytes,ops=psqlOperations())=>docker(['exec','-i',id,'psql','-h','/tmp','-U','postgres','-d',d,'-qAt',...ops],bytes,true);
    const clean=d=>sql(d,"select case when coalesce(current_setting('msgi.catalog_payload_approved',true),'')='' then 'CLEAN' else 'LEAK' end;").stdout.trim();
    const d=fresh();
    ok('Separate SET/verify and unchanged stdin file insert all 51 atomically',()=>{assert.equal(session(d,Buffer.from(bundle)).status,0);const s=JSON.parse(snapshot(d));assert.deepEqual([s.i.length,s.d.length,s.p.length,s.s.length],[1,1,13,36]);});
    ok('Separate session rerun preserves exact row versions',()=>{const before=hash(snapshot(d));assert.equal(session(d,Buffer.from(bundle)).status,0);assert.equal(hash(snapshot(d)),before);});
    ok('Approval reset verified in same session before unrelated SELECT',()=>{const result=session(d,Buffer.from(bundle),[...psqlOperations(),'-c',"select case when coalesce(current_setting('msgi.catalog_payload_approved',true),'')='' then 'CLEAN' else 'LEAK' end;"]);assert.equal(result.status,0);assert.equal(result.stdout.trim().split(/\r?\n/).at(-1),'CLEAN');});
    ok('Fresh unrelated connection cannot inherit approval',()=>assert.equal(clean(d),'CLEAN'));
    ok('Separate operation without SET fails closed',()=>{const x=fresh();assert.notEqual(session(x,Buffer.from(bundle),['-X','-v','ON_ERROR_STOP=1','-c',CONTROLS.assertClean,'-c',CONTROLS.verify,'-f','-']).status,0);assert.equal(JSON.parse(snapshot(x)).i.length,0);});
    ok('SET LOCAL before payload BEGIN does not satisfy guard',()=>{const x=fresh();assert.notEqual(session(x,Buffer.from(bundle),['-X','-v','ON_ERROR_STOP=1','-c',"set local msgi.catalog_payload_approved='msec-reference-v1';",'-f','-']).status,0);assert.equal(JSON.parse(snapshot(x)).i.length,0);});
    ok('Committed SET LOCAL setup cannot carry approval across transactions',()=>{const x=fresh();assert.notEqual(session(x,Buffer.from(bundle),['-X','-v','ON_ERROR_STOP=1','-c',"begin;set local msgi.catalog_payload_approved='msec-reference-v1';commit;",'-f','-']).status,0);assert.equal(JSON.parse(snapshot(x)).i.length,0);});
    ok('Conflicting exact-byte file rolls back and connection close clears context',()=>{const x=fresh();sql(x,"insert into public.skills(name) values('python');");const before=hash(snapshot(x));assert.notEqual(session(x,Buffer.from(bundle)).status,0);assert.equal(hash(snapshot(x)),before);assert.equal(clean(x),'CLEAN');});
    ok('Late local-only injected failure rolls back dedicated session entirely',()=>{const x=fresh();const broken=bundle.replace(/commit;\s*$/,"do $late$ begin raise exception 'Synthetic late failure';end $late$;commit;");assert.notEqual(session(x,Buffer.from(broken)).status,0);const s=JSON.parse(snapshot(x));assert.deepEqual([s.i.length,s.d.length,s.p.length,s.s.length],[0,0,0,0]);assert.equal(clean(x),'CLEAN');});
    ok('Ambient approval context is rejected before approved file',()=>{const x=fresh();assert.notEqual(session(x,Buffer.from(bundle),['-X','-v','ON_ERROR_STOP=1','-c',CONTROLS.set,...psqlOperations()]).status,0);assert.equal(JSON.parse(snapshot(x)).i.length,0);});
    ok('Approval operations leave database/role settings, schema, policies and user tables unchanged',()=>{const x=fresh();const probe="select jsonb_build_object('settings',(select coalesce(jsonb_agg(to_jsonb(s)),'[]') from pg_db_role_setting s),'users',(select count(*) from auth.users),'profiles',(select count(*) from public.profiles),'memberships',(select count(*) from private.memberships),'roles',(select count(*) from private.account_roles),'objects',(select jsonb_agg(jsonb_build_array(n.nspname,c.relname,c.relkind,c.relrowsecurity,c.relacl) order by n.nspname,c.relname) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private','auth')),'policies',(select jsonb_agg(to_jsonb(p) order by schemaname,tablename,policyname) from pg_policies p where schemaname in ('public','private','auth')));";const before=sql(x,probe).stdout;assert.equal(session(x,Buffer.from(bundle)).status,0);assert.equal(sql(x,probe).stdout,before);});
    ok('Dedicated backend terminates after the session operations complete',()=>{const x=fresh();const result=session(x,Buffer.from(bundle),['-c','select pg_backend_pid();',...psqlOperations()]);assert.equal(result.status,0);const pid=Number(result.stdout.trim().split(/\r?\n/)[0]);assert(Number.isInteger(pid)&&pid>0);assert.equal(sql(x,`select count(*) from pg_stat_activity where pid=${pid};`).stdout.trim(),'0');assert.equal(clean(x),'CLEAN');});
    const result={passed,container:id,image,network:'none',shared_volumes:false,new_databases:serial,hosted_writes:0};
    fs.mkdirSync('build',{recursive:true});fs.writeFileSync('build/task11b5b-local-results.json',JSON.stringify(result,null,2));
  } finally {
    if (started) docker(['stop','--timeout','20',id]);
  }
}
try { runnerTests(); databaseTests(); console.log(`All ${passed} checks passed; only the newly created tmpfs target was stopped.`); }
catch (e) { console.error('Catalog validation failed: '+e.message.split('\n')[0]);process.exitCode=1; }
