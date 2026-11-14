# Real MSEC signup and onboarding — Task 11A

## Status and safety

Implemented locally; **not deployed to hosted Supabase**. This is not approval to
invite real students/alumni or a public-capacity claim. Starting HEAD was
`6718a9d318284e4c8971f7381a06e1cd3093eddb`, containing the verified competition
release and already-committed AGENTS.md conventions. The initial working tree
was clean; there was no outstanding AGENTS.md edit to preserve. No push is part
of this task.

The signed competition APK remains at `build/competition-release/` with SHA-256
`aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.
It is not rebuilt or overwritten. The dedicated keystore is not read, rotated or
changed. Android application ID, callback, signing configuration and dependencies
are unchanged. Samsung is detected but its signed installation/data are not
modified. New code needs a separately reviewed future APK with a higher version
code before distribution; this task builds debug only.

## Implementation checklist

- Reuse Supabase email/password Auth, existing callback gateway and membership guards.
- Add self-declared Student, Alumni and Faculty / Staff signup choices; persist
  only an untrusted UX hint in Auth metadata, never a role or verified flag.
- Provide confirmation/resend, request loading, safe rate-limit messages and
  existing-account login. Preserve recovery and session handling.
- Normalize programmes separately from institutions and academic departments.
- Extend real onboarding/profile editing and administrator review projections.
- Verify local migration order, ownership/RLS, Auth/Mailpit, community RPCs and UI.
- Preserve demo isolation and stop before any hosted deployment or public rollout.

## Database order and compatibility

All eight historical migration files are retained unchanged. Apply new migrations
in this order, after those dependencies:

1. `20261114000300_staff_account_kind.sql`: commit the `staff` enum addition.
2. `20261114000400_real_academic_onboarding.sql`: programmes, composite institution
   FK, profile programme/affiliation fields, nullable optional department/years,
   validated own-profile save, compatible legacy RPCs and `discover_alumni_v2`.
3. `20261114000500_review_academic_claims.sql`: admin-only
   `pending_memberships_v2` with readable academic claims.

PostgreSQL requires the enum addition to commit before using its new value.
Programme-less legacy institutions/profiles retain their department pathway;
MSEC onboarding requires a selected programme for students/alumni. No existing
profile is rewritten or automatically reclassified. Staff has no student academic
years or degree programme; designation plus department or affiliation is required.
Alumni may omit an unknown joining year. Staff skills are optional.

Existing public RPC signatures are retained. Nullable-department compatibility
replaces inner department joins with checked optional joins: a supplied inactive
department still excludes a profile. Verified member, visibility, city consent,
mentor opt-in/block and audience checks remain. Programme-only alumni are no
longer silently excluded from discovery, mentoring, map or career publishing.
`discover_alumni_v2` adds an independently bounded programme filter/projection.
New clients require the new migrations; old hosted databases will show unavailable
catalog/review data rather than receiving a client-side security fallback.

The owner-only initial administrator operation now understands programme-only
profiles and reviewed staff affiliations. It still requires explicit independent
approval, an existing confirmed candidate, complete onboarding, audited purpose
and no existing initial administrator. It is never exposed as a public RPC or
called by Flutter. The existing approval RPC and its authorization are retained.

## MSEC catalog

`supabase/catalogs/msec.sql` is a separate reviewed, transactional, repeatable
owner operation. It requires an explicit approval flag; that flag is **not** an
environment detector or substitute for checking the target. The local runner
additionally pins the API to port 55321 and the named isolated Docker database.
The normal empty official `supabase/seed.sql` template remains unchanged.

The catalog contains one MSEC institution, exactly nine undergraduate and four
postgraduate programmes, and Science and Humanities as an academic department.
Programme names retain the established Task 09 spelling, including degree
abbreviation punctuation. Application UUIDs and keys are stable implementation
identifiers, not official college codes. No programme-to-department mapping,
intake, additional institution or institutional endorsement is invented. Existing
demo names/identifiers are preserved; real database programme IDs are independent.

No personal records, administrator accounts, cities or skills are included in
the official MSEC catalog operation. Synthetic skills, cities and consenting
test accounts are separate local fixtures and must never become hosted catalogs.
Faculty approval of production catalog ownership, supported staff affiliations,
starter skill/city lists and corrections remains required before rollout.

## Real onboarding and trust model

Signup → local email confirmation → app callback → own profile/draft → pending
institutional review → explicit administrator approval → permitted community.

The form restores draft/profile data, loads institution-dependent programmes and
departments, validates role-specific years and professional fields, and provides
optional city, directory and map choices. Directory/map defaults are private.
Programme selection never assigns authorization department membership. Verified
academic claims cannot be silently edited; ordinary professional/privacy fields
remain editable through the ownership-checked RPC. Unknown/rejected/suspended
states stay closed with explanatory UX and official-channel review guidance.

Keep these concepts distinct:

| Concept | Authority |
| --- | --- |
| Self-declared account type | User claim/profile, not a privilege |
| Confirmed email | Supabase Auth; not proof of institutional affiliation |
| Pending/verified/rejected/suspended membership | Protected server membership |
| Administrator | Explicit private server role and verified membership |

Staff selection never grants administrator or alumni-publishing privileges.
Even independently verified Staff remains an ordinary verified member unless a
separate administrator role is explicitly approved. Base profile/draft reads are
own-only; directory data is a limited server projection. Profile save rejects
foreign ownership/role fields, unconfirmed/banned accounts, inconsistent catalog
references and academic changes after verification. No client grants/RLS are
removed. Membership and authorization are rechecked server-side with existing JWTs.

## Email, abuse and operating readiness

The versioned local `supabase/config.toml` now defaults to required email
confirmation, the exact Android callback, a 12-character server password minimum
and a 60-second email interval. These are preparation defaults, not an assertion
that running services or hosted settings were changed. The existing isolated
Auth stack already has confirmation/mobile redirects enabled but retains its
legacy six-character server minimum and one-second synthetic-test email interval.
All generated test passwords meet the client minimum of 12. Before rollout,
explicitly apply/review the stronger server password and email policies; do not
mistake client validation for authoritative server enforcement. The existing
port-54322 stack was not restarted to consume these versioned defaults.

Hosted default email limits previously blocked recovery (HTTP 429). Before real
signup, configure a production SMTP provider with authorized sender/domain,
SPF/DKIM/DMARC, bounce/complaint handling and delivery monitoring. Verify actual
confirmation, recovery and resend templates/redirects without disabling email
confirmation. Allow exactly `com.msgi.one.dev://auth-callback/` for the retained
competition/development identity; decide the long-term production identity and
secure Android App Links separately. Never put SMTP or privileged keys in Flutter.

Supabase's current built-in provider is limited to organization-team addresses
and two messages per hour; it is not a public-signup mail service. Custom SMTP
also requires explicit quota/delivery planning. These recommendations were
checked against [Supabase SMTP guidance](https://supabase.com/docs/guides/auth/auth-smtp),
[Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits) and
[the production checklist](https://supabase.com/docs/guides/deployment/going-into-prod).
This documentation lookup did not access the hosted MSGI project.

Signup errors and duplicate-account notices must avoid account enumeration. The
SDK/backend may intentionally return an indistinguishable duplicate response;
do not claim a second account was created. The client shows safe retry/rate-limit
feedback and throttles confirmation resends; backend limits remain authoritative.
Choose CAPTCHA/risk controls, signup/IP/email quotas, connection-request abuse
limits, moderation/report handling and a staffed verification process before
public distribution. Pair-level connection idempotence is not a per-user spam
budget. Never auto-approve all users or trust editable Auth metadata.

Queries have bounded server pagination and existing ownership/catalog/skills
indexes. Directory substring and mentor ranking query plans still require
representative-volume analysis; current FTS indexes do not automatically optimize
every substring predicate. The bounded admin review queue is not a scalable
case-management system. No hosted stress test or 10,000-concurrent-user capacity
claim is made. Plan alerting for Auth/email failure, 429s, database latency,
connection/report abuse and review backlog, with redacted logs and budget limits.

## Privacy, backup and institutional decisions

Before real invitations, approve a privacy notice/consent language, purpose and
retention periods, visibility defaults, account export/deletion handling and
responsible support contact. Account deletion/export is an operational prerequisite,
not implemented as a new public client capability here. Existing audit/connection
FKs require a reviewed deletion/anonymization procedure; do not promise a simple
unrestricted cascading Auth deletion. Avoid precise location or unnecessary PII.
Define suspension/appeal procedures and independent verification evidence.

Document database/Auth/storage backups, retention, recovery access and a restore
exercise. Production backup availability depends on the chosen plan/settings and
has not been verified here. Protect signing material with independent password
escrow and recovery testing; existing release backup acceptance remains an owner
action. Synthetic local fixtures and disposable snapshots are not production backups.

## Local execution and verification

The isolated stack is `msgi_one_clean_9a7b7923`: API 55321, PostgreSQL 55322,
Mailpit 55324. Existing development DB 54322 is preserved. Docker Desktop was
started using its existing installation; no reset, volume deletion, hosted
connection or software/dependency installation occurred. The first attempt at
the new academic migration rolled back on SQL quoting; it was corrected while
unapplied and then applied normally. Historical SQL was never edited.

Use the installed CLI with the isolated workdir, explicitly local migration up
and `supabase test db`; do not reset the root workspace database. The local API
runner seeds approved MSEC reference records idempotently and creates only
synthetic `@example.test` accounts, with local Mailpit confirmation enabled.
Fixture verification is labelled synthetic and is not real institutional approval.
No real administrator was provisioned in this task.

Executed counts and final emulator results are recorded in `verification.md`.
The dedicated native runner uses emulator-5558 and `--keep-app-running`, local
ADB reverse forwarding and actual Android intents from local confirmation/recovery
emails. It suppresses passwords, callback URLs and tokens. It never installs on
Samsung or changes the application ID. Old test failures caused by changed null
serialization/unsupported-programme expectations were updated to the reviewed
contract; no authorization assertion was removed.

Local API commands (each runner checks its fixed isolated target and reads only
the ignored local public configuration):

```powershell
node tool/test_local_real_onboarding.cjs
node tool/test_local_profiles.cjs
node tool/test_local_network.cjs
node tool/test_local_mentors.cjs
node tool/test_local_careers.cjs
node tool/test_local_bootstrap.cjs
node tool/test_local_real_onboarding_emulator.cjs
```

The native runner expects the dedicated local AVD on emulator-5558 and the already
running isolated stack. It records only a non-secret test namespace in
`build/task11a-session-run.json`. `integration_test/local_session_launcher.dart`
can reuse that same namespace for actual standalone process-restart checks via
`tool/test_local_session_restart.cjs`; it refuses nonlocal configuration. This
support entry is not the production main or the competition artifact.

Final results: 193 Flutter tests, 276 pgTAP assertions, 12 separate rollback
bootstrap checks and 207 local API checks passed. Real local Android intents,
three-role onboarding, SDK recreation and two actual process restarts passed.
Offline demo native regression and the ordinary unconfigured debug APK build
also passed. No new physical-device acceptance or hosted result is claimed.

Native testing also found and fixed two real UI defects: draft-save snackbars
could obscure Submit/Log out, and membership navigation could dispose the form
before its cached absent-profile result was invalidated. Save feedback is now an
inline accessible status, and the controller invalidates profile/draft state
before refreshing membership, with identity/disposal guards. Focused regressions
cover both. Per-account registration hints also reload on identity changes.
The SDK's optional storage injection is used only by the test harness to isolate
sessions across repeated runs; normal production storage behavior is unchanged.

## Task 11B — hosted rollout gate (commands are NOT executed here)

1. Obtain explicit approval for the target development project
   `sbgshejyvkptmrffiwvd`, the exact pending migration set and reference records.
   Verify the project reference before any linked command. Do not infer hosted
   migration history from local success: earlier documentation reports three
   deployed migrations, and later tasks discussed a fourth; current remote state
   is deliberately not queried in Task 11A.
2. Inspect linked migration history and a `db push --dry-run`. Review all missing
   historical dependencies (map/connections, mentor matching, Career Bridge and
   ambiguity fix) before the three new Task 11A migrations. Require a separate
   human deployment approval. Do not amend already deployed SQL to shortcut this.
3. Back up the intended project, assess compatibility/rollback-by-forward-fix and
   temporarily prevent mixed old/new client rollout where catalog contracts differ.
   Keep development and production projects/accounts separate.
4. After approved migration deployment, separately approve and apply the reviewed
   MSEC catalog owner operation. Resolve pre-existing name/UUID conflicts manually;
   never overwrite unknown catalogs or seed synthetic institutions/profiles.
5. Configure production SMTP, confirmation/recovery redirects and abuse controls.
   Provision an initial administrator only against an existing consented,
   confirmed, independently approved account with explicit audit approval.
6. Use separate JWTs to smoke-test anonymous, incomplete, pending Student/Alumni/
   Staff, verified, rejected, suspended and approved administrator accounts.
   Verify own-only writes, private-schema denial, role isolation and revocation
   with an existing JWT. Check discovery, programme filters, privacy, map consent,
   mentor blocks, connections, audience-scoped careers and reports/moderation.
7. Verify real Android confirmation/recovery, logout/session restoration, retries
   and offline demo isolation without production data in demonstration mode.
8. Prepare a separately versioned signed client only after hosted smoke tests,
   institutional/privacy approval, operational ownership and recovery readiness.
   Preserve the existing competition APK and do not invite real alumni before
   these gates are complete.
