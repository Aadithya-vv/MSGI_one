# Task 11E: institutional administration deployment review

Reviewed 2026-11-15 against starting commit
`3e22151256d6d487a8d8ef1aeb27dc0dd06ff8f8`.
Scope: hosted read-only investigation and isolated local implementation/testing.
No hosted deployment, administrator provisioning, Auth/SMTP change or data write
was performed. No Samsung action, signing change or push was performed.

## Hosted baseline

The authenticated CLI identifies development project `sbgshejyvkptmrffiwvd`,
region `ap-northeast-2`. Read-only SQL reports database `postgres`, PostgreSQL
17.11, `transaction_read_only=on`, SSL enabled and TLS 1.3. Direct endpoint:
`db.sbgshejyvkptmrffiwvd.supabase.co:5432`.

The direct CA-pinned connection probe reached the authentication challenge with
certificate-chain and hostname verification enabled. It deliberately supplied
no password: `tls_verified=true`, `authenticated=false`,
`classification=password_unavailable`. Fresh direct PostgreSQL authentication
was **not** verified. Inventory SQL was authenticated through the supported CLI
read-only HTTPS path. A future executor must authenticate privately again.

Remote history contains exactly eleven migrations. The ordered dependency names
and hashes are recorded in `supabase/review/admin_execution_plan.json`; all first
eleven repository migration files remain unchanged. Exactly one migration is
pending: `20261115000100_institutional_operations.sql`.

The CLI dry run (`supabase db push --dry-run` with the explicit remote project)
reported this file only, no seeds and no role operations. No actual push ran.

Catalog identities match the previously approved 51 records: one MSEC
institution, one separate academic department, thirteen academic programmes and
36 skills. No catalog additions are part of this migration. Aggregate role
count is zero; orphan/inactive-institution role counts are zero. Auth user count
is one; no personal identity was exported into this report.

| Application metadata | Hosted baseline | Rehearsed post-migration |
| --- | ---: | ---: |
| Public/private tables | 18 | 20 |
| Application functions | 37 | 48 |
| Indexes | 48 | 54 |
| RLS policies | 23 | 23 |
| Non-internal triggers | 4 | 6 |
| Constraints | 103 | 114 |

The inventory query records aggregate counts/fingerprints and metadata only.
No active DDL or waiting locks were observed; this is a snapshot, not a promise
that deployment cannot encounter contention. Hosted migration-history columns
are `version text NOT NULL`, nullable `statements text[]` and nullable `name text`.

## Migration review and explicit correction

The plan inventories all 45 top-level source statements with ordinal, statement
head and LF SHA-256. They cover: transaction boundaries; two private tables and
their RLS/revokes/indexes; role institution binding/backfill/constraint/trigger;
membership/admin scope helpers; eight new public RPCs; eight replaced legacy
helpers/RPCs; report SELECT policy replacement; explicit execution privileges;
expanded report reason constraint; queue index; academic correction audit trigger;
and transactional PostgREST reload notification.

There is no table/column deletion, TRUNCATE, broad record deletion, catalog seed,
Auth mutation or administrator insertion. DROP operations replace the reviewed
report policy and reason CHECK, inside the same transaction. The intentional
existing-data change binds each existing administrator role to its profile's
institution. Missing profiles/institutions fail the NOT NULL/FK gate; they must
not be silently repaired during deployment. Existing hosted role count is zero.

All SECURITY DEFINER functions use an empty search path and qualified objects.
Authorization reads protected current membership and scoped role records rather
than editable metadata. No dynamic SQL/user-interpolated SQL was introduced.
Authenticated EXECUTE grants do not substitute for body authorization checks.
Internal audit/request tables deny client table access; all twenty post-migration
application tables have RLS enabled. Profile/report exposure remains scoped.

**One least-privilege correction was necessary.** Hosted default privileges grant
EXECUTE on new public functions to `service_role` (and anon/authenticated). The
original migration revoked PUBLIC/anon/authenticated but omitted service_role.
Its body guards still checked the actor; no bypass was demonstrated. The pending
migration now explicitly revokes service_role in the single grouped REVOKE for
the eight new public RPCs, then grants authenticated EXECUTE as intended.
No existing function ACL was changed. Four focused pgTAP assertions cover new
RPC execution privileges, including no implicit PUBLIC grant.

Original source SHA-256:
`c322f525d1dd31b4a6feeabf130b220cc7f80bad845d739df73d12d82dba1094`.
Corrected source SHA-256:
`a93d179f6bea04eb4f4c8b6556ddf1aee46cc2949cbeda28eff64cbfa7d7f120`.
This supersedes the Task 11D source approval identity; renewed review is required.

ALTER/constraint validation and ordinary index creation take locks. Existing
role backfill also writes those rows. There is no concurrent-index/nontransactional
operation. Future transaction-local lock timeout is 5 seconds and statement
timeout 60 seconds; timeout must abort, not trigger an automatic retry.

## Isolated transition and preservation evidence

The rehearsal created a uniquely named container using the existing pinned
Supabase PostgreSQL 17.11 image, `--network none`, no published ports, no shared
database volume, and tmpfs storage. It never restored over an existing database.
Only Auth schema definitions were read from the existing local stack; no actual
user data or hosted backup rows were imported.

It applied the eleven dependencies, reconstructed the **observed hosted default
privileges**, and inserted approved reference fixtures plus eight explicitly
synthetic profiles with varied membership states, a synthetic existing role,
connection, opportunity, report and verification audit. The reconstructed
baseline matched all hosted application function signatures/bodies/config/ACLs,
table security, policies, indexes, constraints and triggers.

The derived batch committed successfully with an explicit COMMIT acknowledgement.
All original columns, counts and aggregate fingerprints across 45 non-history
tables remained unchanged. This includes catalogs, relationships, memberships,
profiles, connections, opportunities, reports and audit records. Role identities
were retained with the sole intended institution backfill. Exactly one history
record was added atomically; the two new private tables remained empty.

Exactly eight existing function bodies changed as reviewed:
`private.is_admin`, `private.member_verified`, `public.moderate_report`,
`public.pending_memberships`, `public.pending_memberships_v2`,
`public.report_career_opportunity`, `public.review_membership`, and
`public.verification_history`. Only the reviewed report SELECT policy changed.
All existing function grants were preserved.

Failure rehearsals used copies of this new synthetic database only:

- An orphan administrator role aborted with SQLSTATE `23502`; complete schema,
  data, ACL and history rollback, no COMMIT acknowledgement.
- An injected division-by-zero before history insertion aborted with `22012`;
  complete rollback, no COMMIT acknowledgement.
- Reapplication failed on duplicate schema creation, with no partial changes or
  duplicate history. This migration is deliberately once-only, not idempotent.

The safe machine-readable summary is
`supabase/review/admin_rehearsal_summary.json`: 28 recorded checks passed,
no failures. This is logical synthetic transition evidence, not a fresh restore
of current hosted personal records or a complete Supabase service recovery.

Rehearsal tooling failures were investigated rather than suppressed: comparison
initially mishandled JSON key ordering and the intentionally added history row;
quiet psql hid COMMIT tags; SQL boolean output needed normalization; and trying
to EXPLAIN a private-table join as authenticated correctly returned permission
denied. The final inner-plan measurement uses the SECURITY DEFINER owner context;
the actual RPC measurements still run as authenticated. No client grant was
weakened to make those checks pass.

## Security and application regressions

| Executed check | Result |
| --- | --- |
| Fresh migration database suite | 326 pgTAP assertions passed |
| Isolated owner/bootstrap checks | 12 passed |
| Owner role-operation checks | 10 passed |
| Actual local Auth/PostgREST administration API checks | 46 passed |
| Deployment-plan generator/lexer/hash tests | 5 passed |
| Dart format check | No changes required |
| Flutter analyzer | No issues |
| Full Flutter tests | 197 passed |
| Normal Android debug APK | Built successfully |

The security suites exercise anonymous/pending/ordinary/Staff non-admin denial,
editable profile/JWT metadata, forged institutions, suspended/stale sessions,
owner-only role operations, private audit/report boundaries, concurrent and
duplicate decisions, revision checking, and appeal behavior. API checks use real
local Auth/RPC boundaries, not only route mocks. Appeals do not restore status.
Fresh server role checks prevent a still-valid JWT retaining removed authority.

No new emulator or physical-device acceptance is claimed for Task 11E. Task 11D's
historical emulator result is separate; no Dart UI behavior changed here.

## Operational limits

One local run with 5,000 synthetic queue entries measured:

| Query | Execution time |
| --- | ---: |
| First queue page | 2,579.654 ms |
| Offset-4500 queue page | 2,485.117 ms |
| Overview counts | 1,744.759 ms |
| Equivalent filtered inner scan | 2,106.048 ms |

These are development-machine observations, not release SLAs. The filtered plan
uses Limit/Sort/Hash Join/Seq Scan/Hash/Seq Scan. Repeated per-row scope checks
are costly despite the status/user index; bounded output does not guarantee cheap
execution. NO-GO for unrestricted large queues until measured optimization and
repeat benchmarking. A small supervised pilot needs explicit latency acceptance.

Ordering has stable tie-breakers, but offset pagination is not a snapshot across
concurrent status changes. Refresh after a decision; avoid promising immutable
pages. Review revisions/locking and unique action IDs protect concurrent changes.
Audit data grows append-only; retention/export/access ownership remains unresolved.
Report correlated counts and historic closed appeals merit future query/index
review as volume grows. Existing request throttling is not an operational staffing
plan. As an illustrative capacity estimate only, five minutes per review over
four review-hours is 48 reviews/reviewer/day; college policy must set staffing,
escalation and monitoring. Do not fabricate institutional service targets.

## Backup and recovery

Existing backup identifier:
`sbgshejyvkptmrffiwvd/20261114T134947Z-3d9e4376`.
Manifest SHA-256:
`6ce4fa5779fbff0ec6bafc821ca25bddc5b2fcf52834bd7b49daaebc7d38dbfa`.
All fifteen encrypted file hashes match. Saved isolated restore evidence reports
52 tables, 50 fingerprint comparisons and 394 schema-object checks passed.
The original encrypted backup was not changed or decrypted again in this task.

This backup predates subsequent seven-migration/catalog deployment and is **not
a current predeployment recovery point**. A fresh authorized, verified backup
with an appropriate isolated recovery check is a mandatory future gate. None
was taken under this task's authority. DPAPI remains Windows-account bound;
reinstallation/another-account recovery and an independent encrypted recovery-key
process are not established. Logical database recovery does not establish full
Auth/SMTP/JWT/Storage-object/service restoration. Follow the existing Task 11B.3
recovery instructions only into a new isolated destination, never over hosted.

## Hash-locked future execution design

Migration: `20261115000100_institutional_operations.sql`.

| Artifact | SHA-256 |
| --- | --- |
| Corrected migration | `a93d179f6bea04eb4f4c8b6556ddf1aee46cc2949cbeda28eff64cbfa7d7f120` |
| Derived atomic SQL batch | `51f1a2e45de199d709bfdee415a319d1989c4b264b845b45e79dd70a2b589a3c` |
| Canonical execution plan | `3f4fc4b6f8ca52f5e15fde2b1163cf74e28b40be6b691ffa6f41a7dcae4638bb` |

The plan digest is SHA-256 of recursively key-sorted compact JSON `plan`, array
order retained, UTF-8 without BOM/newline; the envelope is excluded. Reviewed
implementation file hashes are in `supabase/review/admin_implementation_hashes.json`.

The source contains 45 top-level statements. The **derived** 49-statement batch
adds three SET LOCAL statements (lock/statement timeouts and standard string
semantics), plus an exact history insertion before the original COMMIT. The
stored history statements are original LF-normalized migration SQL as data.
There is one BEGIN and one COMMIT; schema, backfill, grants and history are atomic.
The batch is not falsely represented as unchanged source bytes.

The local generator has no network/hosted execution entrypoint and rejects CLI
arguments. The future transport is specified but a hosted executor is **not yet
implemented/reviewed**. It must use the pinned immutable image, host-network
IPv6 transport, exact host/port/database/role, `verify-full` with trusted Supabase
CA and hostname, connection timeout 8 seconds/client timeout 120 seconds,
read-only root/capability restrictions, no routing overrides, no Docker logging,
temporary private password handoff and raw batch Buffer stdin. Never use insecure
TLS fallback, command-line passwords or a prior catalog runner/approval hash.

## Exact future gates and incident handling

1. Review/approve the corrected migration, derived batch, plan and a new fixed
   executor implementation/hash; approve one attempt explicitly, not implicitly.
2. Authorize and verify a current encrypted backup and recovery feasibility.
3. Confirm exact project, CA/hostname/TLS and private direct authentication.
4. Fresh read-only checks: eleven expected history rows, this sole pending file,
   exact 51 catalogs, unchanged relevant data/security fingerprints, role scopes
   with no orphans/inactive institutions, no unexpected schema/grant drift.
5. Recheck all artifact hashes, dependency identities, history shape, environment
   restrictions, absence of concurrent DDL and an agreed low-activity window.
6. Send the exact derived batch once, no seeds, role provisioning, Auth/SMTP
   updates or unrelated SQL. Record sanitized BEGIN/COMMIT/exit evidence.
7. Independently verify history twelve, expected objects/RLS/ACLs, unchanged
   catalog/data fingerprints, intended role backfill and empty new private tables.
8. Any failure or missing acknowledgement: stop, preserve sanitized diagnostics,
   inspect read-only before classifying rollback/commit/unknown. Never auto-retry,
   repair history, provision a role, run a down migration or restore hosted.
   Any forward fix or recovery operation requires separate explicit authorization.

Any SQL, transport, target, hash, baseline or execution change requires renewed
review/authorization. No automatic redeployment is authorized by this report.

## Institutional decisions and verdict

College decisions remain outstanding: authorized verification authority; identity
evidence policy; reviewer appointment/removal; initial administrator bootstrap;
support/escalation ownership; moderation/appeals policy; privacy/retention/audit
access; infrastructure and credential custody. SMTP/domain and real email pilot
acceptance remain separate Task 11C prerequisites. No college approval or reviewer
was inferred, and no administrator was created.

**GO for technical review of the corrected migration and demonstrated local
transition. NO-GO for hosted execution now:** fresh backup, executable transport
review/private authentication and separate owner approval remain gates. NO-GO
for institutional/public operation until policy, staffing, email and ownership
decisions are resolved. Large queue rollout also needs performance work.

Competition APK SHA-256 remains
`aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.
The two pre-existing untracked Task 11B documents are preserved and excluded from
this checkpoint. No backup, credential or private hosted inventory is committed.
