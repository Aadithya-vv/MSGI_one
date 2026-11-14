const { test } = require('node:test');
const assert = require('node:assert/strict');
const { jsonArgs, parseResponse, CONTRACT_SHA256 } = require('./supabase_cli_json.cjs');
test('every supported read-only command explicitly requests output-format=json', () => {
  for (const cmd of [['projects','list'],['migration','list'],['db','query']]) {
    assert.deepEqual(jsonArgs(cmd), [...cmd,'--output-format=json']);
  }
});
test('reject output overrides and unsupported commands', () => {
  assert.throws(() => jsonArgs(['projects','list','--output=json']), /Conflicting/);
  assert.throws(() => jsonArgs(['projects','list','--output-format=text']), /Conflicting/);
  assert.throws(() => jsonArgs(['db','push']), /Unsupported/);
});
test('parse projects envelope including BOM without losing metadata', () => {
  const obj={projects:[{id:'reviewed-ref',database:{host:'reviewed-host'}}]};
  assert.deepEqual(parseResponse(['projects','list'],'\uFEFF \n'+JSON.stringify(obj)),obj);
});
test('identify the failing projects command without echoing raw output', () => {
  assert.throws(() => parseResponse(['projects','list'],'LINKED | ID | sensitive-token'), e => /projects list/.test(e.message) && !e.message.includes('sensitive-token'));
});
test('reject text migration history, rather than interpreting a human table', () => {
  assert.throws(() => parseResponse(['migration','list'],'LOCAL | REMOTE'), /migration list/);
});
test('preserve migration target identity for subsequent project safety checks', () => {
  const obj={migrations:[{local:'1',remote:'1'}],target:{project_ref:'reviewed-ref'}};
  assert.deepEqual(parseResponse(['migration','list'],JSON.stringify(obj)),obj);
});
test('reject migration JSON without authoritative target metadata', () => {
  assert.throws(() => parseResponse(['migration','list'],'{"migrations":[]}'), /Unsupported JSON/);
  assert.throws(() => parseResponse(['migration','list'],'[]'), /Unsupported JSON/);
});
test('normalize the supported human-mode JSON db-query array', () => {
  assert.deepEqual(parseResponse(['db','query'],'[{"catalog_preflight":{"read_only":"on"}}]'), {rows:[{catalog_preflight:{read_only:'on'}}]});
});
test('preserve the supported agent-mode db-query rows envelope', () => {
  const obj={boundary:'opaque',rows:[{catalog_preflight:{read_only:'on'}}],warning:'not trusted'};
  assert.deepEqual(parseResponse(['db','query'],JSON.stringify(obj)),obj);
});
test('malformed, scalar, prefixed and trailing data fail closed without raw disclosure', () => {
  for (const text of ['true','{"secret":"sensitive-token"','prefix []','[] suffix']) {
    assert.throws(() => parseResponse(['db','query'],text), e => !e.message.includes('sensitive-token'));
  }
});
test('response review contract has a stable SHA-256 identity', () => {
  assert.equal(CONTRACT_SHA256,'9530698dc297c73f07caff55a3b63fc36d76444124de03ca20b5005f6acd40be');
});
