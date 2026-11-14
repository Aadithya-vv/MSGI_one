# Task 11B.1 — hosted Supabase audit and deployment plan

Audit date: 2026-11-14. Source HEAD:
`1db24e170c200d23f63acb7f72fd0864ba70bc16`; working tree initially clean.
This audit authorizes no deployment, catalog insertion, Auth change or administrator
assignment. Only this document is intended for commit; no push.

## Confirmed target and method

- Linked project reference and remote CLI target both match
  **`sbgshejyvkptmrffiwvd`**.
- Actual remote display name: **Aadithya-vv's Project**. CLI environment label:
  **production**. These differ from the conversational name `msgi-one-dev`.
  The owner previously designated this reference as development-only. The reference
  is authoritative; the CLI label does not itself establish business use. Preserve
  this distinction and verify the intended target again at deployment preflight.
- Migration history was read successfully using `migration list --linked`, then
  independently confirmed with `db query --remote=<reference> --read-only`.
  The SQL probe reported `transaction_read_only = on`.
- Schema/function/policy metadata and non-identifying aggregate counts were read
  with the same explicit read-only flag. No Auth users, emails, profile content,
  passwords, JWTs or privileged connection strings were selected or printed.
- `config diff` was read only; output was filtered in memory to nonsecret Auth
  policies. Raw configuration/SMTP secrets were not written into this report.
  A public GET to `/auth/v1/settings` required no signup, login or email request.
- Both the original dry run and an explicitly pinned, Vault-skipping dry run
  succeeded. The installed CLI deprecates `--linked` in favor of `--remote`.
  CLI-managed login initialization is distinct from application administrator
  provisioning; no application DDL/DML or privilege assignment was submitted.

## Observed migration history and exact order

| Order | Migration file | Hosted observation |
| --- | --- | --- |
| 1 | `20261112000100_membership_foundation.sql` | Applied |
| 2 | `20261112000200_secure_workflows.sql` | Applied |
| 3 | `20261112000300_fix_my_membership_ambiguity.sql` | Applied |
| 4 | `20261113000100_profiles_and_discovery.sql` | Applied |
| 5 | `20261113000200_map_and_connections.sql` | Pending |
| 6 | `20261113000300_mentor_matching.sql` | Pending |
| 7 | `20261114000100_career_bridge.sql` | Pending |
| 8 | `20261114000200_fix_career_filter_ambiguity.sql` | Pending |
| 9 | `20261114000300_staff_account_kind.sql` | Pending |
| 10 | `20261114000400_real_academic_onboarding.sql` | Pending |
| 11 | `20261114000500_review_academic_claims.sql` | Pending |

There are **4 applied and exactly 7 pending**; no remote-only version was reported.
The seven must remain in the order above. Task 11A's final three cannot be deployed
alone: they depend on map/network, mentoring and Career Bridge objects. The enum
addition must commit before the academic migration uses `staff`.

Read-only reproduction command, executed successfully:

```powershell
npx.cmd --no-install supabase db push --remote=sbgshejyvkptmrffiwvd --dry-run --skip-vault
```

It reported `dryRun: true`, exactly those seven filenames, `seeds: []`, and
`roles: []`. Nothing was applied. The CLI help states that a real push can
synchronize Vault secrets before migrations unless `--skip-vault` is used.
The proposed schema-only stage must retain that flag and omit `--include-seed`,
`--include-roles`, `--include-all` and any broad configuration push.

**A successful dry run is a plan check, not hosted execution or a restore test.**
It does not prove all SQL will execute, lock duration, data compatibility after
concurrent writes, or post-deployment API authorization.

## Observed schema and conflict checks

- Fourteen application tables exist: the original thirteen plus `profile_drafts`.
  All fourteen have RLS enabled; nineteen policies were observed.
- Nineteen application functions exist. Their whitespace-normalized body hashes
  match the corresponding latest definitions in the first four local migrations.
  This is a limited implementation-drift check, not a byte-for-byte historical
  migration checksum, a complete privilege audit or hosted security-test execution.
- `account_kind` contains `student` and `alumni`; `staff` is not present.
- `programmes`, `mentor_goals`, `mentor_blocks` and `opportunity_skills` are absent.
  Pending programme/affiliation/catalog-key, map-centroid and career-scope columns
  are also absent. No collision was found between inspected existing relation/
  function names and the pending migrations' newly created tables/indexes/functions.
  Deliberate `CREATE OR REPLACE FUNCTION` updates are not treated as collisions.
- Aggregate counts observed: institutions **0**, departments **0**, skills **0**,
  cities **0**, profiles **0**, opportunities **0**, administrator-role records **0**.
  These are snapshot counts; no personal records were retrieved. Zero profiles
  does **not** mean zero Auth accounts; Auth users were not enumerated.
- No MSEC institution-name match or reserved institution/department UUID match
  was found. Programme IDs/keys cannot conflict with a pre-existing programme
  table at this snapshot because that table does not exist yet. Recheck after
  migration and immediately before any approved catalog insertion.

The observed empty tables reduce current backfill/constraint risk. They do not
eliminate DDL locks, concurrent-write risk or out-of-band drift after this audit.
The proposed migrations add structures/defaults and replace protected functions;
they do not drop application tables or reset data. `DROP NOT NULL` permits optional
academic fields, while validated RPCs and FKs preserve claim rules. Career Bridge
adds a URL check `NOT VALID`: future writes are checked, but this declaration alone
does not certify legacy URLs (there are currently no opportunity rows).

## Compatibility and application risks

- New clients require programme-aware discovery/review RPCs and real catalog
  structures. The currently hosted four-migration backend cannot satisfy Task 11A.
- Old clients cannot submit a proper MSEC programme or understand verified Staff
  membership. After MSEC catalog insertion, old department-only MSEC submissions
  may be rejected. Coordinate the new client rollout; do not invent department
  aliases or weaken server validation to keep old onboarding working.
- The verified competition APK is a preserved demonstration artifact, not proof
  of compatibility with this future real-user backend. Its offline demo remains
  independent. A future distribution requires a higher version code, the existing
  application ID/signing identity, and separately verified hosted integration.
- Nullable departments must not grant department-scoped opportunity access.
  Programme choice is educational data, not authorization department membership.
  Reviewed RPC compatibility retains verified status, active supplied departments,
  directory/map consent, mentor eligibility and opportunity audience checks.
- Auth confirmation is not institutional verification. Staff/alumni claims must
  remain pending until a legitimate authority reviews them; Staff is not an admin
  or an automatic alumni publisher.

Task 11A's recorded local evidence remains: 193 Flutter tests, 276 pgTAP assertions,
12 bootstrap checks and 207 local API checks, plus Android local callbacks and
restart/demo acceptance. Those checks were **not rerun against hosted** here.

## MSEC catalog prerequisites

Review `supabase/catalogs/msec.sql` independently after schema approval. It inserts
one MSEC institution, nine UG and four PG programmes, and Science and Humanities
as a separate academic department. UUIDs/application keys are implementation
identifiers, not official college codes. No programme-to-department mapping,
additional college, intake or personal record is supplied.

The operation is transactional and repeatable, but not a no-op: matching catalog
keys can update names/levels, conflicting names/UUIDs can abort it, and its final
count check expects thirteen `msec-*` programmes. It must not overwrite unknown
catalogs or disable deliberately inactive entries. The existing empty official
`supabase/seed.sql` template is separate and unchanged.

The flag text `msec-task11a-local` is an explicit-operation guard, **not a local-host
detector or authorization for hosted use**. Do not run the file during the schema
stage or automatically add it to migration seeds. Require separate owner approval
of exact names/identifiers and post-migration conflict checks first.

The MSEC operation contains **no skills or cities**. Student/alumni onboarding
requires at least one catalog skill, so MSEC insertion alone is insufficient.
Approve a real starter skill catalog/import separately; never copy synthetic
fixtures. City is optional, but real map participation needs reviewed city records
and suitable approximate centroids. Approve institutional catalog ownership,
correction procedures and any actual authorization-department assignments.

## Observed Auth configuration and SMTP gaps

The public Auth settings confirm: email provider enabled, signup enabled, and
email autoconfirm **false** (email confirmation required).

The full-scope read-only config diff reported no drift for the declared mobile
redirect allowlist or email-confirmation setting. Relative to the checked-in
configuration this supports the expected callback
`com.msgi.one.dev://auth-callback/`; it is not an email-delivery/deep-link test.
No drift was reported for the prepared 60-second email interval. The redirect
allowlist was not independently retrieved as a raw settings dump.

| Nonsecret setting | Hosted observation | Local prepared value / action |
| --- | --- | --- |
| Password minimum | 6 | 12; separately approve server enforcement |
| Site URL | `http://localhost:3000` | Local also has a loopback fallback; decide a valid hosted fallback |
| Email OTP length | 8 | 6; preserve the stronger hosted setting unless separately reviewed |
| TOTP enrollment/verification | Both enabled | Local false; do not overwrite blindly |
| SMS confirmation | Enabled | Local false; outside current email-only scope |

The diff also includes pooler/storage differences and unmanaged settings, including
the email-send rate limit. **Do not run a blanket `config push`** to erase drift:
that could disable existing MFA or reduce OTP length while altering unrelated
infrastructure. Any future Auth change needs a narrowly reviewed plan and approval.

SMTP provider/setup, sender authorization, delivery health and current email quota
were not established by these checks. No SMTP credentials were requested or
printed. The previous two-emails/hour recovery incident is historical evidence,
not proof of today's quota or provider configuration. Confirm production SMTP,
authorized sender/domain, delivery monitoring and launch capacity privately before
inviting users. Keep confirmation enabled. No hosted email was triggered here.

## Administrator, privacy and recovery gates

No application administrator role exists at this snapshot. Before using
`supabase/operations/bootstrap_initial_admin.sql`, independently approve a specific
consented developer account, verify confirmation/non-banned status and complete
genuine onboarding, and record the approver, reviewed kind, purpose and audit reason.
Auth account identity/status were not inspected in this audit. Recheck that no
initial administrator already exists immediately before the approved operation.
Never assign privileges through client fields or editable Auth metadata, and do
not create an administrator as part of schema/catalog deployment.

Also unresolved: institutional verification authority/evidence and review staffing,
approved skills/cities, privacy notice and consent/retention policy, export/deletion
procedures, moderation/suspension ownership, abuse controls and operational alerts.
No public capacity or 10,000-concurrent-user claim is supported by this audit.

Backup availability/retention, latest successful recovery point, recovery access
and a restore exercise were not verified. Obtain owner evidence of a fresh,
recoverable backup before schema mutation. Confirm recovery coverage for database/
Auth data, storage objects and relevant configuration; do not assume one backup
covers every service. Protect signing-key/password recovery independently, without
putting credentials in Git or chat. No backup/restore/reset was executed here.

## Staged deployment and validation checkpoints

1. **Approval/preflight:** lock reviewed source commit and migration files, reconfirm
   the pinned reference and owner-designated development purpose, record backup/
   recovery evidence, and repeat the read-only history plus Vault-skipping dry run.
   Require exactly four applied/seven pending and no new collisions. Reassess if
   counts/history have changed. Public invitations and new-client rollout remain gated.
2. **Separately approved schema-only stage:** apply the seven files in listed
   chronological order, using the pinned target and `--skip-vault`. No seed, role,
   Auth, administrator or configuration synchronization. Do not wrap the enum and
   its consumers into one transaction. The CLI has no inspected version-limit
   flag; do not invent per-version push flags or remove migration files to simulate
   checkpoints. If file-by-file operator checkpoints are required, review a separate
   supported execution/history-recording procedure before starting.
3. **Schema checkpoint before any data operation:** expect eleven applied versions;
   verify programme/mentor/block/opportunity-skill tables and RLS, new columns/FKs,
   `staff` enum value, v2 RPC signatures, least-privilege grants and safe function
   search paths. Verify no catalog/admin/profile records were created by this stage
   and no Auth policy changed. Stop on unexpected objects, ACLs or partial history.
4. **Separate catalog stage:** obtain exact approval for MSEC and a real skill list,
   rerun collision checks, execute only reviewed owner operations, then verify 9 UG,
   4 PG and the separate academic department. Audit idempotence and visibility;
   do not insert any synthetic profiles, institutions or demonstration activities.
5. **Separate Auth/administrator stage:** approve targeted SMTP/password/fallback
   changes while preserving stronger existing policies. Verify one confirmation/
   recovery cycle using consented accounts and a controlled email budget. Provision
   an initial administrator only after its independent approval and profile review.
6. **Hosted smoke-test gate:** with separate accounts/JWTs, verify anonymous and
   pending denials, Student/Alumni/Staff onboarding, own-only edit/restore, independent
   approval/audit, Staff non-admin/non-publisher behavior, directory programme filters,
   privacy/map consent, mentor eligibility/blocks, connection transitions, career
   ownership/audience/URLs, reports/moderation and suspension with an existing JWT.
   Verify actual Android callbacks and the separately versioned client. No bypass
   or email-confirmation disabling is acceptable to obtain a passing result.
7. **Forward-fix checkpoint:** if any migration fails, stop, record the last committed
   version and sanitized error, and inspect read-only actual state. Earlier files
   may already be committed; do not assume an all-seven atomic rollback. Do not
   reset databases, edit applied SQL, drop the enum, blindly repair migration
   history or delete data. Review/test a new forward corrective migration and obtain
   approval. Restoration from backup is a separately approved recovery operation,
   not an automatic rollback. Retain all checkpoint evidence.

## Recommendation and protected release

**NO-GO for immediate deployment or public signup.** The seven-file schema plan
is a viable conditional candidate: history/objects align, inspected tables are
empty and the dry run is clean. Approval and verified backup/recovery are still
required before mutation. Real onboarding additionally needs approved reference
data, administrator/verification ownership, SMTP/Auth decisions and hosted smoke
tests; schema deployment alone does not satisfy those gates.

Only read-only checks and documentation validation were performed. No migration,
seed, Auth update, administrator assignment, device installation/uninstallation,
reset, hosted application-data write or push was executed.

The signed competition APK was not rebuilt or changed; SHA-256 remains
`aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.
