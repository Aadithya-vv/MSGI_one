const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
for(const name of ['confirmation','recovery','email-change'])test(name+' draft contains only approved action variable and no tracking or executable content',()=>{
const html=fs.readFileSync('supabase/email-drafts/'+name+'.html','utf8');
const text=fs.readFileSync('supabase/email-drafts/'+name+'.txt','utf8');
assert.deepEqual([...html.matchAll(/{{[\s\S]*?}}/g)].map(x=>x[0]),['{{ .ConfirmationURL }}']);
assert.deepEqual([...html.matchAll(/href="([^"]*)"/g)].map(x=>x[1]),['{{ .ConfirmationURL }}']);
assert(!/<(?:script|img|iframe|form|object)|\son\w+\s*=|url\(|javascript:|https?:\/\//i.test(html));
assert(/lang="en"/.test(html)&&/viewport/.test(html)&&/role="presentation"/.test(html));
assert(text.includes('{{ .ConfirmationURL }}')&&text.includes('institutional affiliation'));
assert(!/\.Token|\.TokenHash|\.Email|\.Data|safeHTML/.test(html));
});
