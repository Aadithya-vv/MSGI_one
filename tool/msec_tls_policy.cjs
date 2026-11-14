// Public trust anchor, authenticated official provenance; never trust a DB peer CA.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const CA_RELATIVE = 'tool/certs/supabase-prod-ca-2021.crt';
const CA_SHA256 = '700723581420dd1ac98fd7e9ac529f0ef210eadcaf87fc868a3ad7d114c2f3b7';
const CA_DER_SHA256 = '807025ad50d4ed219d2c9c7d299c004f824eb00cf7f65afef607d07b72e6cafa';
const CA_SOURCE = 'https://supabase-downloads.s3-ap-southeast-1.amazonaws.com/prod/ssl/prod-ca-2021.crt';
const HOST = 'db.sbgshejyvkptmrffiwvd.supabase.co';
function pinnedCa(bytes = fs.readFileSync(path.resolve(__dirname, '..', CA_RELATIVE))) {
  const hash = b => crypto.createHash('sha256').update(b).digest('hex');
  if (!Buffer.isBuffer(bytes) || hash(bytes) !== CA_SHA256) throw Error('Unapproved CA bytes');
  const cert = new crypto.X509Certificate(bytes);
  if (!cert.ca || hash(cert.raw) !== CA_DER_SHA256 || !cert.verify(cert.publicKey) || Date.now() < Date.parse(cert.validFrom) || Date.now() >= Date.parse(cert.validTo)) throw Error('Pinned CA invalid or expired');
  return { path: path.resolve(__dirname, '..', CA_RELATIVE), bytes };
}
function assertHost(host) { if (host !== HOST) throw Error('Unexpected direct TLS hostname'); }
module.exports = { HOST, CA_RELATIVE, CA_SHA256, CA_DER_SHA256, CA_SOURCE, pinnedCa, assertHost };
