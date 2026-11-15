# Task 11D — administrator deployment readiness

Date 2026-11-15; starting HEAD `26ee39c70f9689e6647af5dcd1bc8dfb6de42741`.
**Implemented and validated locally. Not deployed to hosted Supabase.**
Target for any separately approved future deployment remains
`sbgshejyvkptmrffiwvd`. No hosted CLI/API/database mutation, SMTP change,
administrator provisioning or real-user invitation was performed in this task.
Pre-existing untracked Task 11B.2/11B.5 reports and signed competition APK are
preserved. No Android identity, signing or dependency change.

## Inspection and implemented checklist

- Reused existing profile/onboarding, protected membership/account role,
  verification audit, reports, owner bootstrap and Flutter guards/repository.
- Reviewed AGENTS, Task 11A and 11B deployment reports, security model and
  Task 11C.1/11C.2A preparation. Existing twelve-character client password,
  email confirmation, custom callback and independent verification remain.
- Added server-authorized context, scoped counts, paginated status/type queue,
  deliberate decisions, private paginated history, report queue/moderation,
  explicit opportunity archival and operational help.
- Added stale-revision protection, request-key idempotence, concurrency locks,
  safe reason categories, audited academic corrections and bounded appeals.
- Added institution binding to protected roles and owner-only role lifecycle.
  Never infer admin authority from self-declared Staff or email metadata.
- No document upload/evidence storage, public admin enumeration or unrestricted
  production/demo administrator switch was added. Native UI fixtures are in
  test/ only; no fake authorization is wired into the application.

## Forward-only migration and dependencies

New file: `supabase/migrations/20261115000100_institutional_operations.sql`.
Apply only after the eleven existing migrations, including academic onboarding
and `pending_memberships_v2`. Those historical migration files are unchanged.

Exact changes:

1. Private RLS-enabled `administration_audit` and `membership_requests`, with no
   direct client/service-role grants. Unique actor/request keys and one open
   membership request per user; supporting audit/review indexes.
2. Protected account-role `institution_id`, backfilled from existing profiles,
   NOT NULL/FK and trusted-insert binding trigger. Inactive/deleted/banned/
   unconfirmed or changed-institution role holders do not authorize operations.
3. New RPCs: `administration_context`, `administration_members`,
   `decide_institutional_membership`, `request_membership_review`,
   `own_review_status`, `administration_history`, `administration_reports`,
   `decide_institutional_report`.
4. Existing review/moderation RPCs delegate to checked transitions. Legacy
   pending/history projections also enforce institutional scope. Reporter SELECT
   retains own-report access and narrows admin reads to scoped targets.
5. `member_verified` also checks Auth deletion/bans; `is_admin` checks approved
   role institution against current verified profile and active institution.
6. Explicit resolve-and-archive soft-closes reported opportunities in the report
   transaction. Reports support fraud/spam/privacy in addition to prior categories;
   opportunity-report RPC validation is extended consistently.
7. Academic correction trigger records relevant before/after claims on an owned
   update during an authorized pending correction, not ordinary career edits.

New/changed functions are SECURITY DEFINER with empty search_path and qualified
objects. EXECUTE is denied to PUBLIC/anon, authenticated execution requires live
server checks, and private triggers have no client execute grants. No dynamic SQL
or caller-supplied actor ID is used. Parameters are bounded/validated. Verified
reviewer status plus protected role is necessary; a JWT alone is insufficient.
Private notes/reporter identity are not returned by public discovery or own-status.
Subject advisory/row locks and report row locks protect revisions. Identical
request IDs/payloads do not duplicate audits; altered or stale requests fail.

## Data compatibility and deployment risks

Role institution backfill is intentionally fail-closed. **Before deployment,
read-only check all role holders have an existing reviewed profile and the intended
institution binding.** A role without a profile blocks NOT NULL migration rather
than silently assigning a scope. Existing community-wide admin behavior becomes
institution-scoped; owners must approve that intentional restriction. Cross-college
staffing/expansion needs separately approved role assignments, not profile editing.

Migration changes the existing report-reason CHECK and role table, obtains normal
DDL locks and creates private indexes/tables. Review concurrent-write/lock windows,
backup currency and current schema drift first. Old client RPC signatures remain,
but newly strict state/stale/scope checks may reject operations previously allowed.
Do not roll out the new admin client before the migration. Before migration,
missing RPCs fail closed with safe UI errors rather than a privilege fallback.
Existing bootstrap operation now requires the new audit table/migration.

No hosted data compatibility inspection was performed beyond the previously
verified deployment reports/local linked reference context; no claim is made that
remote admin candidates or role rows satisfy these new requirements. Migration
readiness does not authorize applying it. Roll back by reviewed forward fix; never
reset hosted databases or remove audit history to regain access.

## Owner operations and institutional approvals

`bootstrap_initial_admin.sql` remains an explicit trusted-owner operation with
confirmed/onboarded/pending candidate, catalog/profile checks, no existing admin,
independent approver/purpose and idempotence guard. It now records a role event in
the protected operations audit as well as verification history. The bootstrap's
legacy subject-as-actor convention is documented; retain the independent owner's
change record and approver label rather than inventing a reviewer session.

`manage_administrator.sql` is a separate owner-only grant/revoke operation with
independent approval, confirmed human operator, verified subject, bounded reason,
scope checks, audit and last-active-institution-admin guard. No hosted candidate
was provisioned, role revoked or administrator account created in this task.

College must approve: designated reviewers/owners and role scope, accepted offline
evidence, categories/notes policy, support channel, appeals and correction rules,
moderation and suspension/restoration decisions, role lifecycle/MFA, privacy and
retention, staffing/escalation and independent recovery. Proposed defaults are
not an assertion of MSEC policy. See institutional-admin-operations.md.

## Verification evidence

The clean runner copies only the existing isolated Auth schema (no records), creates
a new network-disabled tmpfs PostgreSQL container and applies **all 12 migrations
in chronological order**. All **322 pgTAP assertions** pass: existing 276 plus
46 new operation/role-isolation cases. It stops only its new container. No existing
database reset or volume deletion. Original eleven migrations remain unchanged.

Owner bootstrap: **12 rollback-only assertions passed in that disposable empty
database**. The default existing-stack bootstrap test correctly refused to
provision while prior synthetic administrator fixtures existed. Rather than delete
those roles or weaken the guard, its optional disposable target is now validated
as network-disabled/tmpfs-only and uses the correct /tmp socket. No hosted target
or arbitrary URL is accepted. Owner role lifecycle: **10 rollback-only checks**
passed on isolated local data, including last-active-admin protection.

Local API: **46 checks passed** at fixed API 55321/Mailpit 55324. Real synthetic
signup/confirmation/login and three-role onboarding; metadata/ordinary Staff
denial, bounded pages, self-review denial, exact retry, actual concurrent reviewers,
safe history/categories, suspension/reinstatement with old JWTs, appeals without
access, owned claim edits/audit, private report moderation and live role revocation.
Generated passwords/tokens remain in process memory and are not logged or saved.
Fixture role grants created by each run are removed at its completion; unrelated
existing roles/data are preserved. Synthetic fixture records remain local.

Flutter: existing 193 plus four new authorization/pagination/moderation/large-text
tests; final full-suite/analyzer totals are recorded at checkpoint below.
Emulator-5554 (`MSGI_One_Pixel_4a_API_34`) native acceptance passed: server-authorized
screen wiring using explicit synthetic test repositories, review cancel,
deliberate report decision and help navigation. This is **native UI acceptance**,
not a real hosted/admin-login test. Actual database/API security is verified
independently above. Samsung was neither required nor installed/uninstalled.

Debug APK build succeeded. Native integration builds use a test entrypoint; a
final normal lib/main.dart debug build is retained separately from the signed
competition APK. No release signing operation occurred. Offline demo regression
is covered by the full Flutter suite, not a new physical-device acceptance claim.

## Remaining operating limitations and next approvals

Queue offsets are bounded to 10,000, with deterministic ordering but no snapshot
across concurrent page changes; refresh/restart at page one during batch work.
No automatic official-record verification, bulk approvals, persistent assignment,
warning delivery, notifications, admin AAL2 challenge UX or legal evidence upload.
Long history remains available through restricted legacy verification history;
new history is paginated. No representative-scale query/load benchmark or staffing
SLA is claimed. The handover guide includes explicit workload assumptions.

Next: independently review the migration/scope/data-backfill risks; verify current
hosted history and owner recovery, take/review backup and plan a guarded dry-run;
obtain separate schema-deployment approval. Then separately approve an existing
consented, confirmed, onboarded administrator and owner operation. SMTP, DNS,
real-user signup and public invitation remain separate blocked/approval stages.
Do not infer deployment/provisioning authorization from this local checkpoint.

## Final checkpoint

- Formatter: 98 files checked, no outstanding formatting changes.
- Analyzer: no issues. Full Flutter suite: **197 passed** (193 retained + 4 new).
- Database: **322 pgTAP**, **12 isolated bootstrap**, **10 owner-role** checks passed.
- Actual local API/RPC security: **46 checks passed**; simultaneous reviewer and
  stale JWT tests exercised real local Auth/PostgREST, not Flutter mocks.
- Native emulator integration: **1 test passed** on emulator-5554 with test-only
  fixtures. No hosted admin login or real institutional verification is claimed.
- Normal debug APK: `build/app/outputs/flutter-apk/app-debug.apk`, build passed.
- Existing isolated development schema and migration history now include version
  `20261115000100`; only that new history row was appended after validation.
  No old history row, existing account or unrelated database was reset/deleted.
- Competition APK unchanged, SHA-256:
  `aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.
- No dependency upgrades, hosted mutations, SMTP changes, push or Samsung action.

The automatic approval reviewer initially rejected a test variant that would have
saved a generated emulator password. That file-writing option was removed before
execution; final API credentials stayed in memory, and native UI acceptance used
separate clearly synthetic test-only repositories. No password fixture was saved.

## Task 11E follow-up (2026-11-15)

See [the hosted deployment review](task11e-admin-hosted-deployment-review.md).
Read-only hosted inventory confirms eleven migrations and the exact 51 reference
records; this administration migration is still pending. Hosted default public
function privileges exposed an omitted explicit `service_role` revocation for
the eight new RPCs. The pending migration was corrected locally in that single
grouped REVOKE; four additional assertions bring the database suite to **326**.
The Task 11D hash is superseded by
`a93d179f6bea04eb4f4c8b6556ddf1aee46cc2949cbeda28eff64cbfa7d7f120`.
The isolated eleven-to-twelve transition, atomic history recording, failure
rollback and preservation checks pass. No hosted deployment or provisioning
occurred. Fresh backup, reviewed executor, private authentication and separate
owner approval remain required; large-queue performance needs attention.
