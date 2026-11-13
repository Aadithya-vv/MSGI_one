# Task 02 verification — November 12, 2026

Historical record of the initial foundation before Task 02B rebranding.
The original name/path and original build results below are retained accurately.
Current branding is MSGI One; current setup instructions are in README.

Project: `D:\MSGI_nexus`. Flutter 3.50.0 stable / Dart 3.14.0.

| Check | Actual result |
| --- | --- |
| `dart format lib test` | 25 files checked; final pass changed none |
| `flutter pub get` | Successful stable resolution; lockfile retained |
| `flutter analyze` | No issues found |
| `flutter test` | All 24 tests passed |
| `flutter build apk --debug` | Successful, exit 0; final build 94.7 seconds |
| Route reachability | All eleven screens tested |
| Layout | All screens at 320/390/840 logical pixels and 100%/200% text size |
| Important behavior | Startup/welcome, bottom navigation, feature entry points, sample search/no-match, disabled credential inputs, unknown-route recovery |
| Secrets review | Source review and staged-text pattern scan found no credentials |
| Git ignore | Local Android SDK config, build output, Dart cache and original debug.log excluded |
| Android launch / visual testing | Not performed; no Android target available |

APK: `build/app/outputs/flutter-apk/app-debug.apk`, **166,096,908 bytes**.
This is a debug artifact, not a production-signed release, and is ignored by Git.

Resolved requested dependencies: `flutter_riverpod 3.5.0`, `go_router 18.1.4`,
`supabase_flutter 2.18.3`. Generated `material_ui` resolved to `1.11.0`.
Pub reports newer incompatible versions for three transitive packages constrained
by the current dependency graph. These informational notices do not block builds;
no forced upgrades were made.

The initial Kotlin build failed in shared_preferences_android incremental caches.
The reproduced stack trace reported cache storage as already registered.
Project-local `kotlin.incremental=false` resolved the failure; generated Gradle
and plugin versions are unchanged. Details are in `decisions.md`.

Builds used process-only Java IPv4/Windows proxy-discovery flags documented in
README. Android plugin builds installed required Platform 35 revision 2 and CMake
3.22.1 into the existing user SDK. The app's generated platform remains API 36.

`flutter devices` listed only Windows, Chrome and Edge, not Android.
Widget layout tests are not device visual tests or a full accessibility audit.
The map is a placeholder; auth, verification, recommendations and listings remain
explicit previews. Supabase is not initialized. No remote repository was created
or configured, and no code was pushed or deployed.

## Task 02B — rebranding verification

See `rebranding.md` for current MSGI One results: unchanged dependency lockfile,
clean analyzer, all 25 tests passing, and a successful Android debug APK with the
new display label and original application ID. Directory relocation is blocked
by a Windows file lock; the repository remains at its original location.

## Task 03A — implemented authentication/database foundation

No hosted Supabase project was created, connected or modified. Work remained in
`D:\MSGI_nexus` without another relocation attempt. Android ID remains
`com.msgi.nexus.msgi_nexus`; APK label remains MSGI One. Dependencies and lockfile
are unchanged from the baseline.

| Check | Actual result |
| --- | --- |
| `flutter pub get` | Passed; pubspec/lockfile unchanged |
| `dart format lib test` | Passed, 36 Dart files |
| `flutter analyze` | No issues found |
| `flutter test` | All 61 tests passed |
| Original eleven screens | Preserved and tested with appropriate injected sessions |
| Original 25 tests | Retained; auth interactions updated for guards/validation |
| New auth behavior | Restoration, stale reads, errors/logout, guard loops, privacy defaults, onboarding pending, recovery, suspension, missing configuration |
| `flutter build apk --debug` | Passed, 18.0 seconds |
| APK identity inspection | Original Android ID; MSGI One label |
| APK artifact | `build/app/outputs/flutter-apk/app-debug.apk`, 197,658,589 bytes |
| SQL migrations and 69 pgTAP assertions | UNEXECUTED; local Supabase CLI, Docker and psql unavailable on PATH |
| Hosted auth/email/API/deep links | UNEXECUTED; no project/configuration supplied |
| Android launch/visual testing | UNEXECUTED; only Windows/Chrome/Edge targets detected |

Database test fixtures exercise actual grants/RLS/RPCs in a rollback transaction;
Flutter fakes do not prove database authorization. Static SQL review is not a
successful migration or RLS test run. See `supabase/tests/database/authorization.test.sql`
and `docs/security-model.md` for coverage and remaining gates.

Task 03B readiness: ready for an approved isolated-local validation and controlled
development integration task, NOT for deployment or a live-security sign-off.
First execute the SQL migrations/tests, then follow `docs/supabase-setup.md` for
approved catalogs/admin bootstrap, public config, email/recovery settings and
actual API/device tests. No production key or fake working backend is included.

## Task 03C.1 - clean migration verification

At baseline `5b0c72c5f38d18a1a97ee69ba82bc72c7e324cd8`, a fresh disposable
PostgreSQL instance used port 55322, project `msgi_one_clean_9a7b7923` and a
separate Docker network/volume. All three migrations applied in order, 69/69
pgTAP assertions passed, and all 13 RLS tables and 17 application functions
existed. Fixtures rolled back. Original port-54322 container identity, migration
history and row counts matched the baseline. Disposable container stopped with
storage retained. No repository modifications or commit were made by that task.
This supersedes historical entries marking local SQL verification unexecuted.

## Task 03C.2A - hosted preparation (November 12, 2026)

- Starting branch was clean at the verified checkpoint above.
- Reviewed SQL/configuration, authorization documentation, Flutter initialization,
  recovery adapter and Android manifest; no approved official catalogs found.
- Added an empty repeatable seed template: executed twice through local psql with
  ON_ERROR_STOP against the existing local database; both runs committed with
  INSERT 0 0 for both statements. Institution and department counts remain zero.
  This verifies SQL/schema compatibility and empty reruns, not populated catalog
  mapping/conflict behavior. Approved records still require separate validation.
- Existing Flutter configuration test passed (1 test): defaults close access and
  malformed/non-public keys are rejected. Build-time definitions already work.
- Git confirms config/backend.local.json is ignored. Reviewed preparation files
  contain no embedded credentials or privileged keys; public key prefixes and
  environment-variable names are explanatory only.
- Installed CLI help checked for link, migration list and db push. Documentation
  uses explicit remote ref, dry-run and skip-vault; no hosted command executed.
- git diff --check passed. No Flutter code/platform/dependency changes, builds,
  database resets, hosted connections or full test-suite reruns were performed.
- Remaining gates: approved catalogs, development project ownership/reference,
  independent admin bootstrap approval, SMTP/Auth policy, callback implementation,
  and hosted API plus Android email/recovery acceptance tests. See the deployment
  plan for exact future steps. Preparation does not prove hosted readiness.

## Task 03D - Flutter authentication integration (November 13, 2026)

- Started from a clean working tree. Owner reports hosted/local migration history
  matches; no hosted schema/admin operation was performed or independently tested.
- Reused build-time initialization, authentication adapter, Riverpod state machine
  and membership-aware GoRouter guards. Signup/recovery now send the exact mobile
  callback com.msgi.one.dev://auth-callback/. Android delegates links to Supabase
  app_links; application ID remains com.msgi.nexus.msgi_nexus.
- dart format lib test passed (38 files); flutter analyze: no issues.
- Full flutter test: 63 passed, including existing configuration, restoration,
  session/error/logout, route, incomplete/pending/suspended and recovery behavior.
  Two new SDK adapter tests verify signup/recovery callback requests against a
  loopback HTTP fixture with test-only PKCE storage and no hosted accounts.
- flutter build apk --debug --no-pub passed (Gradle 40.1 seconds). APK manifest
  inspection confirmed original application ID, callback scheme/host and Flutter
  deep-link handler setting. APK: build/app/outputs/flutter-apk/app-debug.apk.
- No public configuration was found in process/User/Machine Supabase environment
  variables or config/backend.local.json. The owner was asked to supply only the
  public configuration through the ignored file. Build therefore used no hosted
  values and correctly retains setup behavior. No real keys/URLs were committed.
- Actual hosted API/authentication tests: NONE. No account credentials available,
  no account created, and no verification/recovery email sent. Local SDK fixtures
  are not hosted authentication evidence. No Android target connected (only
  Windows, Chrome and Edge), so actual callback delivery remains UNVERIFIED.
- Required next steps: ignored public configuration, dashboard exact callback
  allowlist plus confirmed-email/password/SMTP policy review, approved catalogs,
  one consented registration on Android, confirmation, incomplete/onboarding/
  pending handling, login/restoration/logout/recovery checks. No self-verification
  or administrator provisioning belongs to this task.
- No dependency versions, SQL migrations, RLS, SDKs or global configuration changed.

### Task 03D - owner-supplied public configuration follow-up

The owner subsequently supplied the ignored backend.local.json. Validation
confirmed exactly the two expected public fields, the authorized development
origin and a publishable-format key without printing values. Git ignores the file.
Hosted GET /auth/v1/settings returned HTTP 200: email enabled, mailer_autoconfirm
false (confirmation required). Anonymous public-key POST requests to
my_membership, directory_profiles and pending_memberships each returned HTTP 401.
No privileged key, login password, account creation or email request was used.
These checks verify public API connectivity and anonymous denial only; signed-in
membership/REST privileges, session restoration and callbacks remain unverified
on the hosted project. The initial missing-configuration blocker above is resolved.

Configured Android build also passed:
`flutter build apk --debug --no-pub --dart-define-from-file=config/backend.local.json`
returned exit 0. Gradle output was captured only in ignored build output to avoid
printing encoded configuration arguments. The APK now contains the supplied
public build configuration; no real-device launch or signed-in hosted flow was
performed. Public build configuration is extractable by design; no privileged
credentials were used. Dependency lockfile remains unchanged.

## Task 03D - real Android authentication checkpoint (November 13, 2026)

- Flutter/ADB detected authorized SM-M215G, Android 13/API 33. Configured app
  built, installed and launched successfully on the physical device.
- User reported initially no visible signup feedback. Added visible validation
  notice, dismissed keyboard on submit and displayed the 12-128 character
  password requirement. Added regression assertion; the original cause was not
  conclusively established. After update, user confirmed signup notice/email.
- User verified hosted login, restored session after reopening, logout and
  remaining signed out after reopening. Incomplete-profile screen correctly
  reports missing institutional catalogs; community access is not granted.
- Confirmation link initially ended at localhost. Android package resolution
  correctly resolves the exact configured callback to MSGI One. Owner reported
  dashboard redirect changes. Successful email-to-app callback remains unverified.
- Recovery attempt failed with hosted POST /auth/v1/recover HTTP 429; dashboard
  screenshot shows project email limit 2/hour. No email delivery or password
  reset success claimed. Stop repeated requests; retry once after quota permits.
  No rate limit, hosted structure, RLS or administrator permission was changed.
- Final code checks: dart format lib test passed; flutter analyze no issues;
  flutter test 63 passed; configured flutter build apk --debug --no-pub passed.
  Updated APK installed and relaunched successfully. Interactive results above
  are user reports, distinct from automated tests and ADB launch evidence.
- Remaining: approved institution/department/skill catalogs, pending submission,
  recovery delivery/password update, successful cold/warm email callbacks and
  complete signed-in hosted API authorization acceptance checks. No personal
  account data, passwords, keys, tokens or callback links are recorded here.

## Task 03D follow-up - isolated local recovery (November 13, 2026)

Reused disposable msgi_one_clean_9a7b7923 database/volume/network. Started only
Auth, gateway, REST and Mailpit alongside it (API 55321, DB 55322, mail 55324).
Confirmation enabled and exact callback allowlist verified in running isolated
Auth. No hosted request, schema/policy/limit change or database reset performed.
Original port-54322 cluster/migration/row-count baseline remains identical.

Automated local API checks: 11 passed. Unconfirmed login denied; confirmation
redirect accepted; confirmed login succeeds; recovery email accepted; verification
issues a recovery session; that session permits password update; new password
logs in; consumed link rejected; invalid token rejected; second local email
accepted; expired token rejected. Expiry used only an aged recovery_sent_at on
the isolated synthetic fixture. These tests do not establish phone UI behavior.
Passwords were generated privately and not printed; temporary credential state
was removed. Local synthetic account/mail remain only in the isolated environment.

Code checks: formatted 39 Dart files, analyzer no issues, full suite 64 passed,
opt-in local configuration test passed separately, local debug APK build passed.
Installed/relaunched local-only APK on actual RZ8RA1DN4YA; process remains running
with no fatal markers. Default and opt-in tests reject LAN/arbitrary HTTP origins.
SDK diagnostic printing disabled; sampled Flutter output had no JWT/access-token/
refresh-token/password-field patterns. This is a scoped observation, not a claim
about every OS/service log. Raw CLI startup capture was replaced with a sanitized
outcome record because CLI status/start output can contain local keys.

Interactive local confirmation/recovery/password-update and cold/warm-start plus
invalid/reused/expired link handling are PENDING owner testing via Mailpit.
No commit yet: finish interactive verification before checkpointing this task.
Hosted recovery remains unverified and subject to its 2-emails/hour quota.
Approved reference catalogs still block actual alumni profile onboarding.

### Local recovery-after-logout defect

Interactive local confirmation returned to the app. On recovery after logout,
first click stayed on email-entry and repeat click showed access-check failure.
Code inspection found the logout barrier ignored every later non-null session,
while recovery requests bypassed AuthController. Recovery now goes through the
controller; only an explicitly requested SDK-validated passwordRecovery event
can cross that barrier. Late normal sessions remain blocked, including after
failed logout. Request generation checks prevent stale requests rearming recovery.
Regression test covers unsolicited recovery denial after logout, normal stale
session denial after a request, accepted recovery and pending membership after
password update. Invalid/consumed links still fail closed. Interactive retry of a
fresh local recovery link is required; never reuse the consumed link.

### Final local recovery verification

Owner confirmed the updated physical-phone flow works: newest local recovery link
opens password reset, password update succeeds, and login with the new password
succeeds. Local confirmation-to-app was also reported successful earlier.
The earlier interactive-pending entries are superseded for those successful
flows. Reused-link access-check failure was observed before the fix; invalid and
expired links were verified automatically at the local API, not interactively
on Android. Separate cold-start/warm-start coverage was not recorded.

Final verified code checks: analyzer clean, 65 Flutter tests passed, local debug
APK built and installed/relaunched. Post-test sampled Flutter logcat contained no
JWT/access-token/refresh-token or password-field patterns. Both hosted/local
config files remain ignored and separate. Hosted recovery is still unverified
under its 2-emails/hour limit; no hosted emails or settings changes were used.
The phone currently retains the LOCAL-only test build. Rebuild/reinstall using
hosted public configuration without LOCAL_AUTH_TESTING before hosted testing.
Alumni onboarding remains blocked by approved institution/department/skill data;
this task does not provision catalogs, verified membership or administrators.

## Task 04A - complete onboarding, profiles and discovery

Started clean at 9ff4b8e12e916982dc10f2dc5b7bf252c02c4a30. Added the fourth
forward-only migration ONLY to existing disposable msgi_one_clean_9a7b7923 on
55322. No hosted schema/data/Auth operation or database reset was performed.
The original 54322 cluster, migration history and row counts match the saved
baseline. Dependencies, lockfile, Android ID and official seed.sql are unchanged.

Implemented validated student/alumni professional input; numbered onboarding
sections; owner-only explicit server draft save/resume; account-scoped in-memory
buffer across membership refresh routes; retries retaining entries; own profile
view/edit and consent; mentoring preference; safe alumni details; repository-backed
catalogs with search/pagination and institution-dependent departments; server-side
name/institution/department/graduation/profession-company-domain/skill/consented-city
filtering and UUID keyset pages. Pending users may view/edit their own submission;
verified education/category/batch edits are denied server-side. New submissions
remain pending and cannot provision verification/admin privileges.

Database tests: 103 pgTAP assertions passed (original 69 + new 34). Added tests
cover draft ownership/RLS, pending/verified/suspended access, immutable verified
education, profile and mentoring persistence, filter/page bounds and location
consent. Original suite had one broad membership fixture insert; after real local
API profiles existed it collided with those rows. Restricted that insert to its
own seven synthetic IDs. Assertions/policies remain unchanged; rerun passes.

Local API tests: tool/test_local_profiles.cjs passed 25 checks using two generated
synthetic confirmed @example.test accounts, local Mailpit and explicitly local
catalog fixtures. Verified actual REST/RPC catalog reads, drafts, student/alumni
submission, pending denial, own-profile nested contract, cross-profile denial,
combined discovery filters, safe projection/hidden city, detail access, verified
education denial, professional/privacy edit and live suspension with existing JWT.
Synthetic verification was owner-side isolated test fixture setup with audit
reasons; no administrator role created. Synthetic records remain only in that
isolated environment. Official seed stays empty; approved catalogs still needed.

Flutter regression coverage includes existing auth/session/recovery/navigation,
student/alumni validation, roundtrip fields/consent, bounded query parameters,
cursor pagination and retry, private progress restore after scope restart, save
failure retry, empty catalogs, department reset, pending-only editing routes, and
unsaved progress preservation across membership checks with logout clearing it.
Final analyzer/test/build command results are recorded below after completion.

Android availability was checked once: no connected devices. Physical-device
onboarding/profile/discovery tests are PENDING, not passed. No emulator started
and work did not wait for a phone. Hosted onboarding/discovery is UNVERIFIED;
requires explicit review/deployment of the fourth migration, faculty-approved
catalogs, proper trusted reviewer provisioning and separate hosted/device checks.

Final Task 04A commands/results:
- dart format lib test: 48 files, final pass unchanged.
- flutter analyze: no issues found.
- flutter test --no-pub: all 77 tests passed, including all earlier auth tests.
- flutter build apk --debug --no-pub --dart-define=LOCAL_AUTH_TESTING=true
  --dart-define-from-file=config/backend.auth-test.local.json: exit 0.
  APK: build/app/outputs/flutter-apk/app-debug.apk (local-only debug configuration).
- npx.cmd supabase test db --workdir <isolated-root>: 103 assertions passed.
- node tool/test_local_profiles.cjs: 25 API checks passed.
- Local schema: 14 RLS-enabled tables and 19 application functions.
- git diff --check passed; real local/hosted configuration values and privileged
  key patterns were not found in intended changed files. Both config files ignored.
- Unsaved in-memory progress survives membership-refresh route transitions and
  clears on logout; explicit private save is still required for process restart.
- No dependency upgrade, hosted deployment, database reset, emulator or push.

## Task 04B.2 - hosted preparation and reviewer workflow (November 13, 2026)

Read-only hosted migration history confirms all four versions deployed to
sbgshejyvkptmrffiwvd. Owner explicitly designated the project development-only
despite the CLI main-environment production label. Hosted counts before/after:
institutions=0, departments=0, skills=0, cities=0, profiles=0, administrator roles=0.
The proposed consented developer UUID exists and has confirmed email, but no
profile/membership or administrator role. No email/address/token was retrieved.
Owner deferred institutional/city population; no invented official records used.

Prepared a render-only, validated, idempotent import manifest and SQL generator,
with a proposed 20-skill list awaiting approval. Execution refuses unapproved
manifests/opt-ins and missing/inactive parents; no IDs/names/active flags change.
Official seed.sql is unchanged. Prepared an atomic owner-only administrator
operation with approval, confirmed-user, complete pending profile, matching
reviewed kind, active-catalog, audit and existing-administrator guards. Exact
account-specific disabled review SQL exists only in the user's Temp folder;
real UUID/reason are not committed as operational parameters. No hosted data or
administrator privilege mutation occurred. Canonical provisioning is not an RPC.

Added /admin/reviews using existing pending_memberships/review_membership RPCs:
server-authorized entry, bounded queue, explicit kind/evidence acknowledgment/
audit reason, safe retry, self-review prevention. Existing pending/verified/
rejected/suspended route behavior is preserved. No new migration/schema/grant.

Actual checks:
- dart format lib test: 52 files, final unchanged; flutter analyze: no issues.
- flutter test --no-pub: 83 passed (all previous 77 plus review workflow tests).
- Existing isolated pgTAP: 103/103 passed.
- Owner bootstrap operation: 12 transactional pgTAP checks passed, rolled back.
- Generated import SQL: 9 transactional pgTAP checks passed, rolled back.
- Renderer node:test: 4 passed (including quote/dollar-body injection safety).
- Extended local REST/Auth tests: 35 passed, including real reviewer queue,
  self-review denial, approval/audit, rejection/restoration/suspension and existing
  JWT denial. Two synthetic local accounts confirmed through Mailpit only. Actual
  guarded owner operation provisioned a LOCAL fixture reviewer, with its role
  removed in finally; direct query confirmed zero remaining local admin roles.
- Hosted-configured flutter build apk --debug --no-pub passed. No emails sent.
- Existing emulator restarted after it went offline. Hosted-configured app
  launched successfully on emulator-5554. Login/signup/recovery navigation and
  forms rendered; no credentials entered or forms submitted. Hosted Auth settings
  GET returned 200 using only public configuration. This is NOT hosted onboarding,
  profile-edit, admin-approval or authenticated directory acceptance.
- Secret-value scan and git diff --check passed; both public config files ignored.
  Generated Kotlin session markers ignored; Android configuration/dependencies
  and all four migrations unchanged. Existing user AGENTS.md edit preserved.

Remaining hosted acceptance: approved institution/department/skill catalogs,
consented developer pending onboarding and reviewed kind/independent authorizer,
explicit owner approval of concrete bootstrap operation, then controlled hosted
student/alumni/reviewer flows. City data optional if map visibility remains off.
No push, hosted seed, role assignment, schema operation or registration rollout.

## Task 05 - local map and connections (November 13, 2026)

- dart format lib test: passed; SDK integration test also formatted.
- flutter analyze: no issues.
- flutter test: 91 passed, including map grouping/rendering/consent-safe panels,
  explicit filter snapshots, empty/offline/retry, profile actions, request tabs,
  navigation guards and existing authentication/onboarding regression coverage.
- Isolated local pgTAP: 146/146 passed (103 existing + 43 new assertions).
  A final rerun exposed an older unscoped pagination count after API fixtures
  persisted. Its three pagination calls now filter by their own test institution;
  the full suite passes without deleting data or reducing coverage.
- Real local REST/Auth API script: 34 passed. Synthetic accounts confirmed only
  through isolated Mailpit. Checks cover map consent/filtering/projection,
  duplicate/opposite requests, unauthorized reads/mutations, accept/remove/cancel,
  declined-request replay, self-denial and suspension with an existing JWT.
- Original database cluster/migrations/table counts match its saved baseline.
  Isolated private.account_roles count is zero. No administrator provisioning.
- Android local debug APK build passed before the emulator SDK test dependency;
  final regular-entry APK and emulator acceptance results recorded below.
- Changed-file scan against local/hosted key values passed; configuration ignored.
  Four existing migrations, official seed and Android application ID unchanged.

These are local results. Hosted map/network acceptance and physical-device testing
remain pending; migration five requires separate hosted deployment approval.

Final Task 05 emulator/SDK verification:
- Flutter-native integration_test/map_network_test.dart passed on the existing
  Pixel 4a API 34 / emulator-5554, using actual local GoTrue and PostgREST calls.
  No repository overrides/fakes. Verified geographic rendering, explicit city and
  domain filters, zoom/pan/world view, marker selection, consented city panel,
  safe alumni detail navigation, incoming acceptance, accepted network card,
  confirmed removal, profile request status, outgoing tab and cancellation.
- Decline/idempotency/unauthorized transitions are covered at SQL/API layers;
  decline was not separately exercised by the emulator integration scenario.
- Sampled Flutter logcat contained no fixture password, access/refresh-token URL
  patterns, RenderFlex overflow or unhandled-exception patterns. This is a sampled
  diagnostic check, not a guarantee covering every future device log.
- The private synthetic credential fixture was removed after success. The test
  APK was removed by Flutter; normal-entry debug APK rebuilt for manual use.
- Earlier ADB accessibility-based attempts stopped on locator/keyboard/startup
  handling and are not counted as passed. The existing emulator was restarted
  once after disconnecting. The committed SDK test replaces that brittle driver.
- Bundled offline geography tested; optional MapTiler tiles were not enabled.
  Provider key, approved plan and license review remain optional prerequisites.
- No push, hosted schema/data/auth-limit change, real email, database reset or
  privileged account provisioning. User AGENTS.md edit remains uncommitted.

## Task 06 - intelligent mentor matching (November 13, 2026)

- Deterministic server scoring, not a trained AI model. Weighted normalized
  skills/domain/availability/interests, missing-data renormalization and explicit
  evidence caps. No personal overlap yields zero relevance points.
- Isolated database suite: 186/186 pgTAP assertions passed (146 existing + 40 new).
  Exact/partial/missing/one-signal scores, equal-score cursors, unavailable/hidden/
  suspended/unconfirmed/student candidates, active institutions, bidirectional
  exclusions, private goal reads/writes, forged identity, bounds/sort guards,
  existing connections and suspended requester JWT denial covered.
- Local API script: 27 checks passed with three synthetic @example.test accounts,
  Mailpit confirmation, real GoTrue/PostgREST and explicit isolated verification
  fixtures. No administrator role assignment. Tests include goal persistence,
  self-only RLS, explanations, safe projections, pagination, filter ordering,
  opt-out/visibility/block/suspension and real connection status.
- Flutter unit/widget tests: 102 passed (11 new), including data serialization,
  evidence explanations, filters/pagination, profile navigation, empty/offline/
  retry, preference loading/saving failure, required list bounds, catalog selection
  while editing objectives, hiding/Undo and pending-member guards. Existing
  authentication, recovery, onboarding, map and networking regressions preserved.
- Flutter-native emulator scenario passed on Pixel 4a API 34 / emulator-5554:
  actual local sign-in, live recommendations/explanations, domain filtering,
  private objective edit and reload, catalog search, mentor profile, request
  creation, return navigation/status and cancellation. No repository fakes.
  Keyboard input transport is simulated to avoid the installed SDK's documented
  real-IME/injected-input race; manually typed physical-device acceptance pending.
- Sampled Flutter logs: no fixture password/access-token/refresh-token URL
  patterns, overflow or unhandled exceptions. The private fixture was removed.
- Fixed a Material surface assertion during preference navigation and a duplicated
  catalog search label; regression tests cover both. Earlier failed native input
  attempts are not counted as passes. The final synchronized-input scenario passed.
- Formatter and analyzer clean. Normal-entry local debug APK build completed;
  integration test APK is not the final distributable.
- Migration six applied ONLY to isolated DB 55322. No hosted operation, reset,
  push, administrator provisioning, dependency upgrade or Android ID change.
  Official seed and the five prior migrations unchanged. AGENTS.md edit excluded.

Hosted mentor acceptance remains pending reviewed deployment of migrations five
and six, approved catalogs, complete consenting verified accounts and explicit
alumni mentoring opt-in. See task06-mentor-matching.md for formula and limits.

## Task 07 - Career Bridge (November 14, 2026)

- Formatter/analyzer: clean. Flutter tests: 117 passed (15 new Career Bridge
  tests), including listing filters/cursors, URL validation, draft retry, versioned
  edits, close/archive confirmation, author links, reports, capability guards,
  unavailable/network states and a narrow phone editor at enlarged text scale.
- Isolated pgTAP: 237/237 assertions passed (186 existing + 51 new). Checks cover
  alumni-only/authorized-admin publishing, student/pending/suspended denial,
  spoofed author/scope, URLs, duplicate creation, stale updates, skill filters,
  institution/department audiences, private drafts/author names, reporting,
  idempotent transitions and archives retaining moderation records.
- Real local Auth/PostgREST API: 46 checks passed with three explicitly synthetic
  @example.test accounts and isolated Mailpit confirmation. Actual current/stale
  edit versions, RLS-hidden drafts/skills, cross-institution scope, referral/remote/
  skill filters, cursor continuation, author masking, report retry/moderator denial,
  close/archive retention and existing suspended JWT publishing denial verified.
- Flutter-native emulator integration passed on Pixel 4a API 34 / emulator-5554.
  Verified listing/search, external-link destination confirmation (cancelled before
  opening), report submission, public author profile navigation, actual editor
  type/audience/remote/referral/skill fields, draft save, edit/publish, category
  filtering, closure, archival and My posts. Real local services; no repositories
  mocked. Text input transport simulated to avoid the installed SDK's IME race.
- Sampled Flutter logs contained no fixture password/access-token/refresh-token
  URL patterns, overflow or unhandled exception patterns. Private fixture removed.
- Local tests caught SQL kind-filter ambiguity; corrected in a NEW forward-only
  migration, preserving applied migration seven. Native initial uppercase-header
  locator and widget off-screen tap issues were corrected in test drivers, not
  counted as passed attempts. Final scenarios and regressions passed.
- Normal main.dart local debug APK built, replacing the integration test APK.
- No new dependencies, Android configuration changes, hosted operations, reset,
  administrator provisioning or push. Official seed and previous six migrations
  unchanged. User AGENTS.md edit remains excluded from the commit.

Migrations seven and eight require separate hosted review/deployment approval.
Verify hosted history and all other pending prerequisites before deployment.
Manual external-browser completion, physical-device and hosted acceptance remain
unverified. Draft saving is explicit and requires valid title/description; closed
and archived posts remain author-only. Report resolution uses existing protected
backend moderation; no new moderation dashboard was added.
