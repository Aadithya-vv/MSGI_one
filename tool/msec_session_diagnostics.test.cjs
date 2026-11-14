const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const crypto=require('node:crypto');
const {summarize,persist}=require('./msec_session_diagnostics.cjs');
const {executeDedicated,REF}=require('./msec_catalog_session.cjs');
const secret='SYNTHETIC_DO_NOT_LOG_PASSWORD_OR_TOKEN';
const cases=[
 ['DNS',{status:2,stderr:'could not translate host name '+secret},'dns_failure'],
 ['IPv6 route',{status:2,stderr:'Network is unreachable '+secret},'network_unreachable'],
 ['blocked/refused port',{status:2,stderr:'Connection refused '+secret},'connection_refused'],
 ['connect timeout',{status:2,stderr:'connection timed out '+secret},'connection_timeout'],
 ['TLS',{status:2,stderr:'certificate verify failed '+secret},'tls_validation_failure'],
 ['TLS hostname',{status:2,stderr:'server certificate does not match host name '+secret},'tls_validation_failure'],
 ['missing password',{status:2,stderr:'fe_sendauth: no password supplied '+secret},'password_unavailable'],
 ['bad authentication',{status:2,stderr:'password authentication failed '+secret},'authentication_rejected'],
 ['SQL',{status:3,stderr:'ERROR: synthetic statement '+secret},'sql_statement_failure'],
 ['Docker',{status:125,stderr:secret},'docker_client_or_image_failure'],
 ['native start',{status:null,error:{code:'ENOENT',message:secret}},'client_start_failure'],
 ['process timeout',{status:null,error:{code:'ETIMEDOUT',message:secret}},'client_timeout'],
 ['unclassified',{status:null,error:{code:secret,message:secret}},'unclassified_failure'],
];
for(const [name,input,expected] of cases)test(name+' produces safe classification',()=>{const s=summarize(input);assert.equal(s.classification,expected);assert(!JSON.stringify(s).includes(secret));assert.equal(s.automatic_retry_permitted,false);});
test('lost commit acknowledgement stays uncertain',()=>{const s=summarize({status:2,stdout:'BEGIN\nSET\n',stderr:'connection lost '+secret});assert(s.transaction_begin_observed);assert.equal(s.commit_acknowledged,false);assert.match(s.outcome_hint,/requires_read_only/);});
test('COMMIT acknowledgement retained even if later reset/session fails',()=>{const s=summarize({status:3,stdout:'BEGIN\nCOMMIT\n',stderr:'ERROR: reset '+secret});assert.equal(s.commit_acknowledged,true);assert.equal(s.outcome_hint,'commit_acknowledged_verify_records_read_only');assert.equal(s.automatic_retry_permitted,false);});
test('persistence drops raw and injected secret fields',()=>{const client='msgi-catalog-client-'+crypto.randomUUID();const file=persist(client,{classification:secret,exit_status:secret,outcome_hint:secret,stderr:secret,environment:{PGPASSWORD:secret}});assert(file);try{const text=fs.readFileSync(file,'utf8');assert(!text.includes(secret));assert(!text.includes('PGPASSWORD'));assert(!text.includes('stderr'));}finally{fs.unlinkSync(file);}});
test('safe local failure preserves classification and cleanup without retries',()=>{const payload=fs.readFileSync('supabase/catalogs/msec_reference_atomic.sql');let attempts=0,cleanup=0;assert.throws(()=>executeDedicated({payload,project:REF,host:`db.${REF}.supabase.co`,password:secret,spawn:(cmd,args)=>{if(args[0]==='stop'){cleanup++;throw Error(secret);}attempts++;return {status:2,stderr:'Network is unreachable '+secret};}}),e=>/network_unreachable/.test(e.message)&&!e.message.includes(secret)&&e.diagnostic.commit_acknowledged===false);assert.equal(attempts,1);assert.equal(cleanup,1);});
