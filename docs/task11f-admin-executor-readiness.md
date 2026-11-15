# Task 11F: institutional administration executor and recovery readiness

Date: 2026-11-15. Starting HEAD:
`8d73eeb0b9aca4f10bfb830f93c90e0cbd370d7b`.
Target: development project `sbgshejyvkptmrffiwvd`.

**Local implementation and testing complete; NO-GO for hosted deployment now.**
No hosted migration, catalog write, administrator provisioning, Auth/SMTP change,
user change, Samsung action or push occurred. No `--execute` invocation occurred.

## Hosted read-only baseline

The fresh authenticated CLI inventory and catalog identity check confirmed:

- Exact project/reference and direct hostname, region `ap-northeast-2`.
- Eleven exact applied versions; only `20261115000100` pending locally.
- All 51 approved reference tuples: institution 1, department 1, programmes 13,
  skills 36. Identities match, not merely totals.
- Administrator roles 0, orphan/inactive institution bindings 0.
- Application tables 18, functions 37, indexes 48, policies 23, triggers 4,
  constraints 103. No active DDL or waiting locks observed.
- Read-only SQL, PostgreSQL 17.11, SSL enabled, TLS 1.3.

A credential-free direct host-network probe again verified the pinned certificate
chain and exact hostname over the IPv6-capable route, then stopped at the password
challenge: `tls_verified=true`, `authenticated=false`, `password_unavailable`.
No password was available in this process. Authenticated **direct PostgreSQL SQL**
was not tested in Task 11F; the CLI's authenticated read-only inventory is separate.

The eleven historical migrations and pending migration remain unchanged.

## Exact reviewed identities

| Item | SHA-256 |
| --- | --- |
| Migration `20261115000100_institutional_operations.sql` | `a93d179f6bea04eb4f4c8b6556ddf1aee46cc2949cbeda28eff64cbfa7d7f120` |
| Original Task 11E review plan | `3f4fc4b6f8ca52f5e15fde2b1163cf74e28b40be6b691ffa6f41a7dcae4638bb` |
| New guarded executor batch | `9532752174520c568429291a141ff7b829b09156da6516f620bb2afd8848f838` |
| New executor implementation, entrypoint | `85864d38269b3fe4e45980d83198c42ad0da7f061d614a7ad921103d8566d92c` |
| **New complete executor plan** | **`9a42477afdb7f2596d6cfd61d539ebab4b3aec99ae62723f88eb5a8e93a618b7`** |

`supabase/review/admin_executor_plan.json` binds the complete source dependency
set, migration dependencies, CA, runtime image, pre/post schema identities and
batch. Its digest covers recursively key-sorted compact JSON `plan` only, array
order retained, UTF-8 without BOM/final newline. It is not the entrypoint hash
alone. Byte changes, including checkout newline changes, fail identity checks
and require review; never silently normalize an execution input to pass a gate.

## Implemented executor

`tool/admin_migration_executor.cjs` supplies read-only checking by default and a
future explicit execution mode. Project and plan-review hash are mandatory.
The read-only path does not import/call a catalog deployment operation.

Before execution it verifies the exact linked project, external plan approval,
canonical plan digest, pinned implementation bytes, original migration bytes,
all eleven dependency hashes, the exact twelve-file local migration set and
the guarded batch bytes. Then it requires private credentials, fresh direct
authenticated read-only inventory, exact history/catalog/role baselines, reviewed
schema/function/ACL/RLS/default privileges and a fresh verified backup.

The owner approval manifest must separately pin:

```text
scope = one-admin-migration-attempt
project_ref = sbgshejyvkptmrffiwvd
execution_plan_sha256 = new reviewed plan digest above
migration_sha256 = unchanged migration digest above
baseline_md5 = fresh owner-reviewed aggregate source-state signature
expires_utc = future expiry, no more than four hours away
backup_directory = separately approved private encrypted backup destination
backup_manifest_sha256 = reviewed ready-manifest ciphertext digest
```

No approval manifest is supplied by Task 11F. A file containing these fields is
not institutional authorization by itself: an authorized owner must review the
plan, actual recovery evidence, scope and one-attempt operation independently.

### Transport and credentials

`admin_executor_transport.cjs` reuses the existing `msec_tls_policy.cjs` trusted
Supabase CA/host policy. It uses the reviewed immutable PostgreSQL image, Docker
host networking, exact direct hostname/5432/postgres identity, `verify-full`,
read-only pinned CA mount and no TLS fallback. It rejects routing/TLS/Docker
endpoint environment overrides. Connection timeout is 8 seconds; client lifetime
is bounded to 120 seconds. The client has a unique identity, read-only root,
dropped capabilities, no-new-privileges, no Docker logging and removal on exit.
Cleanup targets only that newly named client and never retries a SQL operation.

The password is passed only to child PGPASSWORD environment, never argv, SQL,
repository configuration or logs. The private SUPABASE_DB_PASSWORD handoff is
removed from the executor's environment after retrieval. The trusted OS and
Docker administrators can inspect process memory; this is not protection against
a compromised administrator. JavaScript strings cannot guarantee memory erasure.

`request_admin_readonly_credential.ps1` follows the previous SecureString/BSTR/
ProcessStartInfo pattern, verifies implementation hashes, launches a **fixed
read-only** child, clears the launch environment and emits only a safe receipt.
It cannot accept an arbitrary command or execute flag.

Its AST syntax check passed, but `-File ... -SelfTest` was blocked by the current
Windows script execution policy. No policy change or bypass was applied. The
new launcher's runtime self-test/private input are therefore **pending**. A future
owner must use an approved script-execution/signing process or the existing
authorized temporary process-environment handoff, then verify direct read-only
authentication. No password was requested through chat or another credential store.

### Concurrency, atomicity and outcome

The new batch is an explicitly disclosed derivative, not the original migration
bytes. It adds four operations to Task 11E's 49-statement batch: transaction-local
baseline context, advisory-lock guard, fixed table locks and in-transaction
baseline verification. Thus it has 53 top-level SQL statements, one BEGIN and one
COMMIT. The history insertion still occurs before that same COMMIT.

A durable exclusive-create, fsync'd attempt marker lives at a fixed per-project/
migration path under LOCALAPPDATA/MSGIOne/admin-deployments. It is created only
after preflight/backup/approval gates pass and before the first write. No success,
rollback, exception or uncertain outcome removes this marker automatically.

The transaction requires `pg_try_advisory_xact_lock(749312050001)`, obtains fixed
SHARE ROW EXCLUSIVE locks over the reviewed application tables, auth.users and
migration history, then recomputes the source aggregate signature before DDL.
The runtime baseline parameter is validated as 32 lowercase hex characters.
Locks and context are transaction local. Source/backfill/grants/history commit
together. The migration creates no administrator or Auth/SMTP configuration.

These locks can briefly block application/Auth user-table writes; the lock
timeout is 5 seconds and per-statement timeout 60 seconds. Use an agreed quiet
window. Advisory locks coordinate cooperating executors, not arbitrary owner DDL;
other owner deployments must also be excluded operationally. No claim of zero
downtime is made. A timeout aborts rather than retries.

Success requires client exit zero, explicit COMMIT command tag and an independent
new authenticated read-only postflight. Postflight checks exact twelve-version
history, expected schema/privileges, 51 catalogs, existing row fingerprints/Auth
user fingerprint and empty new private tables. An observed COMMIT with failed
postflight is retained as committed-but-unverified. A lost tag is uncertain even
if the transaction may have committed. Only whitelisted diagnostics are retained.
There is no automatic retry, history repair, administrator provisioning, down
migration or hosted restore path.

## Fresh backup and recovery

See [the repeatable backup procedure](admin-predeployment-backup-procedure.md).
`admin_backup.cjs` implements user-only directory creation, binary custom-archive
DPAPI sealing, ciphertext/plaintext digests, append-only ready manifest,
decryption/integrity checks, four-hour age gate, exact source baseline and
restore-evidence binding. No plaintext archive file is written. Original capture
files are not overwritten when recovery evidence is appended.

The local rehearsal captured a complete custom archive of its **synthetic**
database, encrypted/decrypted it under this Windows account and restored it into
a new empty database in the newly named network-disabled tmpfs container. No
published ports/shared database volumes or existing database resets were used.
It checked all 18 application tables, 37 application functions, policies/RLS,
indexes/constraints/triggers, Auth user fingerprint and migration history against
the source, with every role/table effective privilege checked separately.

Two representation differences were explicitly investigated and accepted:

- `mentor_blocks`' explicit owner-only ACL became NULL (PostgreSQL default owner
  rights). Owner/RLS still match, and the full role/table privilege matrix matches.
- `city_centroid_bounds` had associative AND parentheses flattened. Only the
  exact reviewed original/restored expression hashes are accepted, and the
  boundary/NULL truth table is verified. Other constraint differences fail.

This verifies logical equivalence within the stated application/Auth-user scope,
not byte-identical pg_dump schema rendering or every managed-platform object.
The restored database used role definitions already present in this new synthetic
cluster. Independent reconstruction of actual hosted roles/managed services is
not demonstrated. Synthetic encrypted backup scope cannot satisfy deployment.

The original encrypted November 14 backup remains untouched: project matches,
all **15 ciphertext hashes match**, manifest SHA-256 remains
`6ce4fa5779fbff0ec6bafc821ca25bddc5b2fcf52834bd7b49daaebc7d38dbfa`.
It is stale relative to later schema/catalog changes. No fresh hosted backup was
captured; this task designs the procedure and exercises synthetic recovery only.

DPAPI portability across reinstall/accounts/machines, independent encrypted key
custody, complete cluster roles, SMTP/Auth provider/JWT configuration and Storage
object bytes remain recovery limitations. Do not infer complete Supabase service
recovery from a logical database restore or a manifest's `verified` flag alone.

## Failure testing and results

| Executed validation | Result |
| --- | --- |
| Executor unit tests | 30 passed |
| Backup manifest gate tests | 12 passed |
| Existing SQL/plan unit tests | 5 passed |
| Actual IPv6/TLS fixture tests | 11 passed |
| New PostgreSQL executor/encrypted-recovery checks | 20 passed |
| Full isolated transition/workload checks | 30 passed, including suite wrappers |
| Database security assertions | 326 pgTAP passed |
| Actual local Auth/PostgREST administration API checks | 46 passed |
| Plan/source/dependency/batch identity check | Passed |
| Masked launcher | Syntax passed; runtime self-test blocked by policy |

Covered failures include wrong project/host/credentials, certificate and hostname
rejection, incorrect migration/plan approval, source hash failure, invalid/stale/
unverified/synthetic backup, drifted history/catalog/admin roles/default grants,
concurrent attempt, SQL failure, lost acknowledgement and postflight discrepancy.

Actual PostgreSQL tests verify advisory-lock contention, baseline-change rejection,
failure rollback, exact batch commit/history, preservation and repeat rejection.
Connection-loss timing is simulated in executor unit adapters; a lost COMMIT tag
is also simulated over an actual locally committed transaction and independently
observed persisted history. No claim of physically severing hosted TCP is made.
Actual TLS wrong-CA/hostname/authentication/timeout tests use isolated IPv6 fixtures.

Intermediate harness failures were not suppressed: default ACL reconstruction
initially omitted explicit postgres grants; a DPAPI test initially flipped a header
byte rather than encrypted data; restore comparison initially included a different
database name and expected ACL/constraint representations; an unnecessary final
database rename failed. The final harness fixes these issues without weakening
the hosted guards or changing migration SQL. Final results contain no failures.

No Flutter/Dart/platform/dependency code changed. Flutter tests/analyzer/Android
build were not repeated because these tools do not affect app code or packaging;
Task 11E's 197-test/debug-build result remains historical evidence, not a newly
executed Task 11F result. No emulator or hardware acceptance is claimed here.

## Performance and operational limits

At 5,000 synthetic pending entries, on this development machine:

| Operation | Execution ms |
| --- | ---: |
| First 30-row page | 2348.064 |
| Offset-4500 page | 2391.389 |
| Overview | 1692.381 |
| Filtered inner query | 2111.188 |

Plan nodes: Limit, Sort, Hash Join, Seq Scan, Hash, Seq Scan. Repeated per-row
scope authorization remains expensive despite the queue index. These are local
measurements, not production SLAs. No broad performance schema change was made.
Repeated unchanged pages are stable, adjacent pages do not overlap, and a Student
filter excludes the synthetic Alumni queue. Offset pages remain non-snapshot
under concurrent status changes. The real API suite verifies concurrent review
winner/stale-loser behavior and appeals without automatic reinstatement; pgTAP
also verifies duplicate/open appeal handling and three-per-thirty-days limits.

Large unrestricted queues remain NO-GO pending query optimization/benchmarking.
A small supervised pilot needs explicit latency acceptance, reviewer staffing,
audit retention, monitoring and escalation ownership.

## Required next approvals and verdict

1. Review this exact new implementation/plan/batch and recovery scope; prior Task
   11E/catalog approval hashes grant no execution authorization.
2. Separately authorize a fresh encrypted hosted backup and isolated recovery
   verification, including current source state and managed-schema/role limits.
3. Resolve approved temporary credential-input execution and complete fresh
   direct authenticated read-only preflight. Do not change Windows policy silently.
4. Recheck exact eleven-version/51-catalog/zero-admin baseline, file hashes,
   current backup, no concurrent DDL and an agreed low-activity window.
5. Only then obtain separate explicit owner approval for **one** guarded migration
   transaction and its history row, with expiry/baseline/ready-backup hash bound.
   No admin/bootstrap, Auth/SMTP, seed or membership change is included.

College verification authority, evidence policy, reviewer lifecycle, bootstrap,
support/escalation, moderation/appeals, privacy/retention and credential custody
are separate institutional decisions. SMTP/email acceptance is also separate.

**GO for owner review of the locally validated executor and synthetic recovery
procedure. NO-GO for hosted deployment now, unrestricted queues or institutional
operation.** Stop after this checkpoint. Any uncertain future attempt is examined
read-only before a new separately authorized operation; no automatic retry or
destructive recovery is permitted.

Signed competition APK remains unchanged, SHA-256
`aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.
Signing materials were not accessed/modified. The two pre-existing untracked
Task 11B reports are preserved and excluded from this commit. No backup, personal
record, key or password is committed.
