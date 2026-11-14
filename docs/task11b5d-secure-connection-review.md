# Task 11B.5D: secure database connection review

Date: 2026-11-15 (Asia/Calcutta). Starting commit:
`ca2caf97a166d4d3ad5a32b03a52bc772159dd3f`.
**Local implementation and secure TLS transport validated. Hosted authenticated
SQL acceptance is PENDING: the process database password is unavailable.**
No hosted write, catalog attempt, migration or retry was made.

## Root cause and selected transport

The exact direct hostname `db.sbgshejyvkptmrffiwvd.supabase.co` resolves to IPv6.
The original default Docker bridge lacks the required route; its psql client
reproducibly reported network unreachable. Docker host networking reaches the
endpoint in this existing Windows/Docker Desktop installation, without a global
Docker, Windows, WSL2 or security-setting change.

Host networking alone was insufficient: the database chain is signed by
Supabase's CA and was not trusted by the previous `sslrootcert=system` setup.
The corrected client selects **host networking**, keeps the same direct host,
port 5432, database/role postgres, and uses **verify-full plus an explicit pinned
Supabase CA**. It never substitutes a pooler or falls back to require/prefer/
disable. No client listener/port is published; the container is read-only and
unprivileged with dropped capabilities. Only its public CA file is bind-mounted,
read-only, at `/run/msgi-ca.crt`.

## Authenticated trusted CA provenance

This is the public shared Supabase production root, not a fabricated unique MSEC
certificate or a private key. It was **not obtained from the database peer**.

1. The authenticated GitHub connector fetched the official Supabase repository's
   [SSL configuration component](https://github.com/supabase/supabase/blob/master/apps/studio/components/interfaces/Settings/Database/SSLConfiguration.tsx).
   Its Download Certificate button uses the custom-content certificate URL.
2. The official
   [custom-content definition](https://github.com/supabase/supabase/blob/master/apps/studio/hooks/custom-content/custom-content.json)
   specifies `https://supabase-downloads.s3-ap-southeast-1.amazonaws.com/${env}/ssl/${env}-ca-2021.crt`.
3. Production CA bytes were fetched from
   `https://supabase-downloads.s3-ap-southeast-1.amazonaws.com/prod/ssl/prod-ca-2021.crt`
   over HTTPS with default certificate/hostname validation and HTTP 200 required.
   This authenticates the distribution server; no bearer token/private login was
   needed for the public certificate. The URL is the official dashboard's
   distribution source, not an untrusted search-result certificate mirror.
4. CA basic constraints, self-signature, validity, raw PEM hash and DER fingerprint
   were verified and pinned. No certificate was added to a global trust store.

Certificate: **Supabase Root 2021 CA**, valid 2021-04-28 through 2031-04-26.

| Trust identity | SHA-256 |
| --- | --- |
| Exact distribution PEM bytes | `700723581420dd1ac98fd7e9ac529f0ef210eadcaf87fc868a3ad7d114c2f3b7` |
| DER certificate | `807025ad50d4ed219d2c9c7d299c004f824eb00cf7f65afef607d07b72e6cafa` |

The public certificate and provenance are versioned under `tool/certs/`.
Scoped `.gitattributes` preserves the pinned distribution bytes without checkout
line-ending conversion. `msec_tls_policy.cjs` rejects changed/expired/non-CA data
before connecting. Trust updates require review and a new plan hash; no automatic
CA download, peer-certificate trust or certificate exception exists at runtime.

[Supabase's SSL guidance](https://supabase.com/docs/guides/platform/ssl-enforcement)
documents its database CA and verify-full hostname verification. Validating the
shared CA alone does not identify this project: libpq also verifies the exact
hostname, and existing authenticated project/link/destination checks remain.

## Implementation and security behavior

- `tool/msec_catalog_session.cjs`: same single dedicated psql session, now
  `--network host`, readonly CA mount, forced `PGSSLMODE=verify-full`,
  `PGSSLROOTCERT=/run/msgi-ca.crt`, and eight-second connection timeout.
- `tool/msec_tls_policy.cjs`: static expected direct hostname and pinned official
  certificate identity, provenance URL and validity checks.
- `tool/check_msec_secure_connection.cjs`: **read-only-only** entrypoint. It first
  runs the unchanged guarded CLI metadata preflight, then invokes the corrected
  direct client with a fixed BEGIN READ ONLY / SELECT / COMMIT query. It neither
  imports/calls executeDedicated nor accepts SQL, host or deployment arguments.
- `tool/msec_session_diagnostics.cjs`: classification extended for libpq's actual
  `does not match host name` wording. The first negative TLS fixture exposed only
  a categorization gap; certificate rejection itself was already working.

The existing main runner, project checks, raw payload hash, CLI response-contract
approval and no-retry gates remain. The changed execution-plan hash makes the old
plan approval fail closed. Nothing in this task authorizes --execute.

Five session-control statements and psql -c/-f ordering compare unchanged against
the baseline. The catalog file retains its own BEGIN/COMMIT and exact raw bytes;
approval SET/verification remains separate, then RESET/verification/disconnect.
No prefix concatenation, unexpected SQL, altered record vocabulary, grants or RLS
change was introduced. A lost COMMIT acknowledgement still stops for read-only
state investigation, never automatic replay.

## Credential handling and remaining authentication gap

The process has no `SUPABASE_DB_PASSWORD`. No password was printed, recovered
from unrelated stores, rotated, stored in source or requested in chat. The
deployment helper still requires a nonempty privately inherited password before
any write connection. Its child environment supplies PGPASSWORD; argv, SQL,
diagnostics and Git never contain it. Docker-daemon operators remain inside the
trusted local-machine boundary and can inspect a running client's environment.

Prefer an ephemeral secure launcher/process handoff, not persistent plaintext
User/Machine environment variables. The current task did not create a credential
store, secret file, database role or administrative permission.

For read-only TLS validation only, the direct acceptance client supplied an
explicitly empty password. It reached libpq's **no password supplied** challenge,
exit 2, after successful verify-full TLS. It did not send approval controls or
catalog SQL. This is strong evidence of working IPv6, CA chain and exact-host
verification, **not successful database authentication or executed direct SQL**.

## Hosted read-only results

Executed: `node tool/check_msec_secure_connection.cjs`.
Its overall exit was 2 because authenticated acceptance could not complete.

| Check | Result |
| --- | --- |
| Exact project/link/control-plane metadata | `sbgshejyvkptmrffiwvd` verified |
| Migration history through authenticated read-only CLI | 11 applied; zero pending |
| Institutions/departments/programmes/skills via read-only CLI | 0 / 0 / 0 / 0 |
| Corrected direct Docker host-network IPv6 route | Passed: reached authentication challenge |
| Pinned CA chain and hostname, verify-full | Passed: no certificate failure; libpq requested a password |
| Direct authenticated query/history/catalog counts | **Not executed: credential unavailable** |
| Hosted catalog/approval SQL or test writes | **None** |

The counts/history above are explicitly from the supported authenticated
control-plane read-only preflight, not attributed to an unexecuted direct query.
The fixed direct query checks transaction_read_only, current database/role, its
own pg_stat_ssl state, history and four empty catalogs if credentials are later
provided. Do not claim full hosted acceptance until it passes.

## Local test evidence

**115 tests passed:** 11 actual TLS-policy/transport checks, 28 parser/diagnostic
unit tests and all 76 preserved catalog/session safety tests.

New TLS fixture cluster: `msgi-tls-test-1794689241117-03d3d5c3`, network none,
IPv6 loopback enabled only inside the disposable network namespace. Existing
Git OpenSSL 3.5.9 generated synthetic one-day CA/server keys; no installation was
performed. Server enforces SSL/SCRAM on ::1. The fixture was stopped and generated
private keys/password material removed; no generated private credentials entered Git.

Verified against actual isolated PostgreSQL/libpq:

- IPv6 loopback, certificate chain, hostname, SCRAM login and read-only SQL pass.
- Wrong hostname rejected with trusted CA; untrusted CA rejected with correct
  hostname, both with verify-full still enabled.
- Invalid synthetic credentials rejected after TLS; connection timeout tested
  using pre-auth delay on the disposable local server only.
- Actual COMMIT acknowledgement classification; fixed read-only entrypoint has
  no catalog inserts, approval controls or arbitrary SQL input.
- Pinned CA alteration and unexpected production hostname fail closed.
- Existing suite preserves full transaction rollback, exact-record idempotency,
  session reset/termination, secret suppression, failure categories and no retry.

No existing valuable database was reset. No hosted temporary tables/roles were
created. These local tests do not bypass the hosted credential requirement.

## New identities and required future approval

| Artifact | SHA-256 |
| --- | --- |
| New connection helper (complete raw file) | `3ea90ff3f257d425ba5c31073e345e2532d4635f5b139b66e224b8ede2dc1722` |
| Read-only acceptance entrypoint | `63f419c68237ab7f846c56b88a03ce15840c84405bc3c392dabe31154545db71` |
| TLS policy | `2d633c3cff12b787412a25279899b7373e4ba523cdc60b8d5d79d1aa049cdcbd` |
| **Complete new execution descriptor** | **`1dc1532047b90c92e8eab593bd57715d8a736178b35e61c912a72e7d72f52a5a`** |
| Approved catalog payload, unchanged | `153f97a2eaff6fa02a723a65bcf4c135ab91bc63b2acb8dc151c93966833e428` |

The plan hash is SHA-256 of UTF-8 JSON.stringify(plan), before the attached hash
field. It now explicitly binds host network mode, verify-full, public CA file/
PEM/DER pins and official source, timeout, exact destination and the unchanged
five controls/payload. It supersedes b44a29...; it is not an authorization itself.
Raw source file hashes are not LF-normalized. Main runner remains the reviewed
fbe212... file, but its dependencies and connection plan have changed.

Before another deployment, complete the fixed **direct read-only authenticated
acceptance** through an ephemeral private credential handoff. Then obtain fresh
owner authorization for exactly one attempt using the new plan hash, pinned CA,
host networking, existing CLI response contract and unchanged 51-record payload.
Repeat backup/destination/migration/empty-catalog checks immediately beforehand.
No retries are allowed under the spent authorization.

This task stops here: authentication acceptance is the remaining blocker. No
catalog deployment, Auth/SMTP/TOTP/migration/RLS/admin/user-record change, Samsung
action, APK rebuild, credential rotation, global trust-store change or push occurred.
Signed APK SHA-256 remains
`aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.
Unrelated untracked reports and backups are preserved.
