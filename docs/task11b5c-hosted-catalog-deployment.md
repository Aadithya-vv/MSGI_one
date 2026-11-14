# Task 11B.5C: hosted reference catalog deployment gate

Review date: 2026-11-15 (Asia/Calcutta).
**Current hosted status: NOT COMPLETED.** One later external attempt was reported;
recovery verified all catalogs empty. No retry was performed. Original gate
failures and their historical statuses are preserved below.
Task 11B.5C-FIX local correction is validated in the final section; its new
execution plan requires separate hosted approval.

Latest authorized attempt (2026-11-15): **FAILED at credential preflight, before
any hosted connection or execution**. The owner approved both corrected hashes;
no new approval is being requested. See the final attempt record below.

**Incident update (2026-11-15):** the owner subsequently reported one external
deployment attempt with an uncertain-session error. Fresh read-only recovery
queries found all four catalogs empty (0/0/0/0), eleven migrations applied and
48 unrelated-table fingerprints unchanged against the historical baseline.
The approved Docker bridge path reproducibly fails with IPv6 network unreachable;
a candidate host-network diagnostic instead reaches a TLS certificate-validation
failure. No retry was performed. The prior headings above/below are historical,
not evidence that the owner's later external attempt did not occur.
See [the recovery incident report](task11b5c-deployment-incident.md) for exact
evidence, diagnostic fixes, uncertainty limits and the new approval boundary.

Task 11B.5D follow-up: the local host-network/CA-pinned connection plan passes
hosted verify-full TLS and reaches authentication. Direct read-only SQL acceptance
is still blocked by the missing process password. See
[the secure connection review](task11b5d-secure-connection-review.md) for the new
plan hash. No hosted catalog retry or write is authorized or performed.

## Source and intended scope

HEAD: `503c5268c8a1faf8548a79c675af3af946a784ad`.
Intended project: `sbgshejyvkptmrffiwvd`.
The existing unrelated untracked Task 11B.2 and Task 11B.5A reports were preserved.
The approved SQL and runner match the committed review; neither was modified.

The owner authorized exactly the 51-record atomic catalog payload with SHA-256
`153f97a2eaff6fa02a723a65bcf4c135ab91bc63b2acb8dc151c93966833e428`,
subject to all Task 11B.5C safety gates. The task also explicitly requires:

> Do not concatenate, regenerate, transform or modify the approved SQL.

It requires SHA-256 of the exact bytes the runner will execute and stopping when
those bytes differ. This narrower gate conflicts with the existing reviewed
runner's session-approval prefix; it is not an unexpected source-file modification.

## Verified byte identities

| Artifact | SHA-256 |
| --- | --- |
| Current raw atomic SQL file | `153f97a2eaff6fa02a723a65bcf4c135ab91bc63b2acb8dc151c93966833e428` |
| Atomic SQL Git blob at reviewed HEAD | `153f97a2eaff6fa02a723a65bcf4c135ab91bc63b2acb8dc151c93966833e428` |
| Full batch constructed by existing runner | `47892fea362fa010cd08266148147b83481ed4867aa48071cd8abaee07809fe3` |

At `tool/deploy_msec_reference.cjs:91`, the runner constructs:

```javascript
const sql = "set msgi.catalog_payload_approved='msec-reference-v1';\n" + texts['msec_reference_atomic.sql'];
```

The extra statement is a session intent/approval control, not catalog DML or an
Auth configuration change. It was part of the reviewed Task 11B.5B runner and is
required by the SQL guard, but it is still concatenated SQL outside the approved
atomic file's byte hash. The guard cannot simply be removed or bypassed under
the current authorization. Current raw payload bytes already match Git/LF, so
line-ending normalization is not the cause of this mismatch.

## Checks not reached and actual outcome

No deployment timestamp exists: the write runner was not invoked. No hosted
commands were issued in this task, including read-only preflight, because the
local byte-identity blocker was established before proceeding. Therefore fresh
database-destination verification, backup integrity verification and hosted
catalog/data baselines are **not claimed completed** for this task.

The previously documented recovery checkpoint remains
`20261114T134947Z-3d9e4376`, with prior logical restore evidence in Task 11B.3;
its current integrity was not rechecked here. Independent DPAPI-key recovery
and full-service recovery remain the previously accepted limitations, not the
reason for this stop.

Expected approved totals remain 1 institution, 1 academic department, 13 programmes
(9 UG/4 PG) and 36 skills, total 51. These are **not newly observed hosted counts**.
No transaction began, no partial catalog insertion occurred, and no rollback,
retry, correction or idempotency rerun was attempted. The previous local tests
do not resolve the new exact-submitted-bytes restriction.

No Auth/SMTP/TOTP/password-policy, administrator, verification, migration, RLS,
user/profile/membership or city operation was issued. There was no Flutter or
Samsung action. No backup, signing material or competition APK was modified.
Only this report and ignored local hash-comparison evidence were created.
No commit or push was performed; the task authorizes a documentation commit
after successful deployment, which has not occurred.

## Required next approval

Choose a separately explicit scope before any hosted execution:

1. Approve the existing runner's single session-approval SET prefix followed by
   the unchanged atomic payload, explicitly identifying the full submitted-batch
   hash `47892fea362fa010cd08266148147b83481ed4867aa48071cd8abaee07809fe3`
   alongside atomic-file hash `153f97a2eaff6fa02a723a65bcf4c135ab91bc63b2acb8dc151c93966833e428`;
   then rerun every fresh project/backup/empty-catalog gate before execution; or
2. Authorize a local-only runner/payload correction and re-review, with fresh
   hashes and tests, followed by a new hosted approval. No such correction was
   made implicitly during this deployment task.

SMTP, administrator bootstrap, actual signup, privacy/verification ownership and
public invitations remain separate stages regardless of the chosen resolution.

## Task 11B.5C-FIX: validated local correction

The original failure was a mismatch between the approved file hash and the SQL
request assembled by the runner, not damage to the catalog payload. That runner
hashed the file but sent `SET ...;` concatenated with its text. A custom `SET`
without LOCAL changes the current backend session; it survives COMMIT until RESET
or backend termination. It is not ALTER SYSTEM/DATABASE/ROLE and does not persist
in `pg_db_role_setting`, nor change schemas, Auth, policies, grants or user rows.
Nevertheless, leaving approval set on a reused session is unsafe. The local tests
compare database/role settings, schema objects, policies and user-table counts.

Two independent Management API/CLI requests cannot be assumed to share a backend.
Moving SET to an earlier CLI request therefore cannot establish a reliable guard.
`SET LOCAL` before BEGIN, or in an already committed setup transaction, also
cannot satisfy this payload's guard; both failure modes were tested locally.
Wrapping the payload's own BEGIN/COMMIT in another transaction was rejected.

### Corrected transport and exact bytes

The runner retains its existing read-only CLI target/destination/hash/history
checks. Its write path now uses
[msec_catalog_session.cjs](../tool/msec_catalog_session.cjs): one **direct**, fresh
PostgreSQL backend via the already-installed PostgreSQL 17.11.0.019 psql client
image. It does not use a connection pooler or the Management API for writes.

Destination: `db.sbgshejyvkptmrffiwvd.supabase.co:5432`, database/role `postgres`,
TLS `verify-full`, system trusted roots. The direct host must equal the verified
authenticated project metadata. No arbitrary destination or SQL input is accepted.
Client containers have no published ports or volumes, are read-only, and are
removed after exit. Failure/timeout cleanup targets only the newly named client.

The owner password must already be supplied privately through the supported
`SUPABASE_DB_PASSWORD` environment workflow. The runner does not retrieve it,
provision a role or request its value in chat. It passes the value only through
the short-lived client environment (`PGPASSWORD`), never SQL, argv, Git or logs.
This requires trust in the local Docker daemon: its operators can inspect client
environment while the client exists. No claim of hardware-backed credential
isolation is made. No new software/dependency is required.

In one psql connection, ordered `-c`/`-f` operations are:

1. Assert approval is absent (reject contaminated session/default context).
2. Set session approval.
3. Verify the setting on that same backend.
4. Execute the **original payload bytes** with `-f -` from a Buffer on stdin.
5. RESET approval and verify it cleared.
6. Disconnect. `ON_ERROR_STOP=1` also disconnects on any error; a direct backend
   is not returned to a pool. Cleanup stops an attached client that times out.

The exact additional session-control SQL is exported as `CONTROLS` in the helper:

```sql
do $context$ begin if coalesce(current_setting('msgi.catalog_payload_approved',true),'')<>'' then raise exception 'Unexpected ambient approval context'; end if; end $context$;
set msgi.catalog_payload_approved='msec-reference-v1';
do $context$ begin if current_setting('msgi.catalog_payload_approved',true) is distinct from 'msec-reference-v1' then raise exception 'Session approval not established'; end if; end $context$;
-- The unchanged approved file is a separate psql -f operation here.
reset msgi.catalog_payload_approved;
do $context$ begin if coalesce(current_setting('msgi.catalog_payload_approved',true),'')<>'' then raise exception 'Session approval not cleared'; end if; end $context$;
```

These five controls are **not concatenated with the payload** and do not form a
new single SQL batch. The payload alone is not the entire execution procedure.
There are five additional, fixed session-control operations plus its exact file
operation. No per-user data or dynamic SQL interpolation is used in the controls.

The file still owns the only explicit BEGIN/COMMIT for catalog inserts. Session
approval survives from setup into that BEGIN; after payload COMMIT it is reset.
On a pre-COMMIT error the file transaction rolls back when the dedicated session
closes. If a connection/cleanup failure occurs after COMMIT, report uncertain
outcome and inspect read-only; never assume rollback or retry automatically.

Raw payload SHA-256 remains:
`153f97a2eaff6fa02a723a65bcf4c135ab91bc63b2acb8dc151c93966833e428`.
Unlike the former normalized execution path, this runner rejects CRLF or any
other raw-byte substitution. It does not regenerate, concatenate or normalize the
file for execution. All approved catalog SQL, JSON manifest and hashes are unchanged.

The old combined hash `47892fea362fa010cd08266148147b83481ed4867aa48071cd8abaee07809fe3`
is historical and is no longer an execution artifact. New execution-plan SHA-256:
**`b44a29ca2f28188b67388ef557cc0ad1e8646849ddd653334828531d1c5eea83`**.
This hashes UTF-8 `JSON.stringify(plan)` from `executionPlan()` **before** its
`execution_plan_sha256` field is attached. The descriptor binds project, direct
host/port, role/database, image, TLS mode, all five ordered controls, the payload
hash and dedicated-session closure requirement. It is not a SQL batch hash.
Print the complete descriptor locally with:

```powershell
node -e "console.log(JSON.stringify(require('./tool/msec_catalog_session.cjs').executionPlan(),null,2))"
```

### Local execution evidence and limits

`node tool/test_msec_reference.cjs`: **75 checks passed**, retaining the original
57 and adding 18. Real database tests used 24 new databases inside isolated tmpfs
cluster `msgi-catalog-test-1794684160156-92ee9d1d`, network none, no shared volumes
or published ports. The cluster was stopped after verification. Schema only was
read from the existing local test stack; no existing database was reset.

Verified: wrong target/hash/approval refusal, unchanged raw stdin Buffer, missing
credential refusal before transport, one-session setup/verification/file/reset,
51-row atomic insert, untouched exact rerun, conflict rollback, late-failure
rollback, missing guard refusal, bad SET LOCAL scoping refusal, ambient-context
refusal, cleanup before unrelated SELECT, no inherited approval in a new
connection, termination of the original backend, and unchanged database/role
settings, schema/RLS/policies and user/profile/membership/admin tables.

Tests of the future hosted transport are mocked; actual session operations used
the identical psql operation ordering against the disposable local server. No
hosted commands were issued by this correction task. Direct hosted IPv6/TLS
connectivity, owner credential availability and real hosted execution are
**unverified**. Those are explicit future preflight requirements, not claimed
passes. There were no hosted inserts or configuration changes.

Intentional files: `tool/deploy_msec_reference.cjs`, new
`tool/msec_catalog_session.cjs`, `tool/test_msec_reference.cjs`, this report,
the historical hardening report's supersession note, and `docs/decisions.md`.
No catalog SQL, manifest, migration, Flutter/Android or signing file changed.
Backups and competition APK were preserved; unrelated untracked reports remain.

### Exact future authorization needed

New approval must explicitly permit **one deployment** to the verified project
using the dedicated direct TLS backend, securely supplied owner credential, the
five listed session controls and unchanged payload hash, under execution-plan
hash `b44a29ca2f28188b67388ef557cc0ad1e8646849ddd653334828531d1c5eea83`.
The runner now requires both approval hashes. The previously authorized API
prefix-concatenation procedure is not reused or silently treated as approval for
this different connection/credential transport.

After that approval, recheck project/destination, direct TLS access, recovery
checkpoint currency/integrity and **empty** catalogs before any write. No secret
value should be sent in chat. A future command, **not executed here**, is:

```powershell
node tool/deploy_msec_reference.cjs --execute --approve-sha256=153f97a2eaff6fa02a723a65bcf4c135ab91bc63b2acb8dc151c93966833e428 --approve-execution-plan-sha256=b44a29ca2f28188b67388ef557cc0ad1e8646849ddd653334828531d1c5eea83
```

No automatic continuation to deployment, Auth/SMTP, administrator provisioning,
signup or public onboarding is authorized by this local correction.

## Authorized corrected-plan attempt: credential gate failure

Review date: 2026-11-15 (Asia/Calcutta).
HEAD: `752d8096755d78ebf219516108a53e51dc090ba3`.
Intended target: `sbgshejyvkptmrffiwvd`.
**Result: FAILED — preflight blocked; zero deployment attempts.**

The new user instructions explicitly approve one corrected-plan deployment, with
fresh destination, credential, TLS, backup, migration and empty-catalog gates.
Those instructions require stopping if a gate fails, and forbid fallback endpoints
or automatic retries. Authorization is sufficient; availability is the blocker.

### Completed local checks

- Git HEAD matches the reviewed implementation. Runner, dedicated-session helper,
  atomic SQL, record manifest and hash manifest match the reviewed Git revision.
- Independent reconstruction of the execution descriptor, removing its appended
  hash field and hashing UTF-8 `JSON.stringify(descriptor)`, matched
  `b44a29ca2f28188b67388ef557cc0ad1e8646849ddd653334828531d1c5eea83`.
- The five session-control statements and their order are unchanged.
- SHA-256 over the raw file bytes matched
  `153f97a2eaff6fa02a723a65bcf4c135ab91bc63b2acb8dc151c93966833e428`.
- The manifest still contains the expected 1 institution, 1 department, 9 UG/4 PG
  programmes and 36 skills. Approved deployment files were not rewritten.

### Failed prerequisite and checks not reached

The approved direct-session helper requires an existing privately supplied
`SUPABASE_DB_PASSWORD`. Presence-only checks found it absent in **Process, User
and Machine** Windows environment scopes. No credential values were printed,
stored in the repository, requested in chat or inferred from public API keys.
The CLI access token/public publishable key is not a substitute for this direct
PostgreSQL owner's password.

No hosted CLI/API/database request or direct TLS connection was issued during
this attempt. Fresh actual-destination/TLS verification, backup integrity checks,
migration/catalog baselines, concurrency checks and unrelated-data fingerprints
were therefore not completed or claimed passed. Previous evidence is historical,
not a substitute for those fresh gates.

There is **no deployment timestamp**, because no transaction or execution attempt
began. No automatic retry, pooler/API write substitution, correction or restore
was attempted. Actual current hosted catalog counts are unverified in this
attempt; expected approved totals remain 1/1/13/36 (51), not observed new totals.

Auth, SMTP, TOTP, password policy, administrators, users, profiles, memberships,
RLS, migrations, cities and existing application data were not touched. Backups,
competition APK and signing configuration were not modified. Existing unrelated
untracked reports were preserved. Only this safe report and ignored local
identity-check evidence were updated; no commit or push was made, because the
task conditions its documentation commit on successful deployment/verification.

### Resume prerequisite

Make the existing database password available privately through the approved
`SUPABASE_DB_PASSWORD` environment mechanism, in the environment inherited by
the deployment process. Do not paste it in chat or commit it to a config file.
No new deployment approval is needed while the hashes, plan and scope remain
unchanged. Once availability is confirmed, rerun **all** required fresh gates,
including direct TLS/certificate validation and intact backup verification,
before using the single authorized execution. If direct connectivity fails,
stop rather than switching endpoints or weakening TLS.

### Subsequent resume: process credential still inaccessible

On the owner's resume request, presence-only checks in both the ordinary tool
subprocess and the privileged deployment subprocess reported
`process_credential_accessible: false`. No value was printed, logged or sent.
The supplied variable was therefore not inherited by either execution context.

The first mandatory gate failed, so all remaining checks and the single
deployment were left unattempted. No hosted connection, SQL request, deployment
retry, endpoint substitution, settings change or credential-store modification
was made. Authorization remains unchanged; the blocker is subprocess credential
availability. Only this report was updated; no commit or push was performed.
