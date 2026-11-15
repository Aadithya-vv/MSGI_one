const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
for(const name of ['confirmation','recovery','email-change'])test(name+' draft contains only approved action variable and no tracking or executable content',()=>{
const html=fs.readFileSync('supabase/email-drafts/'+name+'.html','utf8');
const text=fs.readFileSync('supabase/email-drafts/'+name+'.txt','utf8');
assert.deepEqual([...html.matchAll(/{{[\s\S]*?}}/g)].map(x=>x[0]),['{{ .ConfirmationURL }}']);
assert.deepEqual([...html.matchAll(/href="([^"]*)"/g)].map(x=>x[1]),['{{ .ConfirmationURL }}']);
assert(!/<(?:script|img|iframe|form|object)|\son\w+\s*=|url\(|javascript:|https?:\/\//i.test(html));
assert(/lang="en"/.test(html)&&/viewport/.test(html)&&/role="presentation"/.test(html));
assert(text.includes('{{ .ConfirmationURL }}')&&text.includes('institutional affiliation'));
assert(html.includes('Development pilot')&&text.includes('Development pilot'));
assert(!/\.Token|\.TokenHash|\.Email|\.Data|safeHTML/.test(html));
});
test('pilot manifest is a blocked proposal and preserves hosted TOTP and confirmation',()=>{
const m=JSON.parse(fs.readFileSync('supabase/email-drafts/pilot-auth-change-manifest.json','utf8'));
assert.equal(m.status,'PROPOSAL_ONLY_NOT_EXECUTABLE');
assert.equal(m.target_project_ref,'sbgshejyvkptmrffiwvd');
assert.equal(m.preserve['auth.mfa.totp.enroll_enabled'],true);
assert.equal(m.preserve['auth.mfa.totp.verify_enabled'],true);
assert.equal(m.preserve['auth.email.enable_confirmations'],true);
assert.equal(m.proposed_changes['auth.minimum_password_length'].proposed,12);
assert.equal(m.proposed_changes['auth.site_url'].proposed,null);
assert.equal(m.proposed_changes['auth.email.smtp.admin_email'].proposed,null);
assert.equal(m.proposed_changes['auth.enable_signup'].initial_containment_proposal,false);
assert.equal(m.hosted_mutations_performed,false);
});
