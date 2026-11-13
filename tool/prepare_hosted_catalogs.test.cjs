const test=require('node:test');
const assert=require('node:assert/strict');
const {render}=require('./prepare_hosted_catalogs.cjs');
const base={project_ref:'sbgshejyvkptmrffiwvd',review_status:'PROPOSAL',institutions:[],departments:[],skills:['SQL'],cities:[]};
test('Empty institutional proposal never invents institutions and requires approval',()=>{const sql=render(base);assert.match(sql,/Explicit catalog approval required/);assert.match(sql,/select null::text where false/);assert.match(sql,/on conflict\(lower\(name\)\) do nothing/);});
test('Wrong target, case duplicates and unmatched departments are rejected',()=>{
 assert.throws(()=>render({...base,review_status:'APPROVED',institutions:['College']}));
 assert.throws(()=>render({...base,project_ref:'wrong'}));
 assert.throws(()=>render({...base,skills:['SQL','sql']}));
 assert.throws(()=>render({...base,institutions:['College'],departments:[{institution:'Other',name:'Department'}]}));
});
test('Quotes and dollar text are safe even inside generated DO blocks',()=>{
 const sql=render({...base,institutions:["O'Brien $$ Institute"],departments:[{institution:"O'Brien $$ Institute",name:'Engineering'}]});
 assert.match(sql,/O''Brien \$\$ Institute/);assert.match(sql,/do \$msgi_[a-f0-9]{64}\$ begin/);
});
test('No existing identifiers, names, consent or authority are overwritten',()=>{
 const sql=render({...base,institutions:['Approved institution'],departments:[{institution:'Approved institution',name:'Approved department'}],cities:[{name:'Approved city',country_code:'IN'}]});
 assert.doesNotMatch(sql,/do update|delete from|truncate|account_roles|insert into auth\./i);
 assert.match(sql,/Missing\/inactive institution/);assert.match(sql,/lower\(existing.name\)=lower\(d.name\)/);
});
