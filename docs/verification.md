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
