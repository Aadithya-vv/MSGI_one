# MSGI One

**One Community. Infinite Connections.** Android-first alumni networking for MSGI.

Choose **Explore Demo** to try the isolated fictional Student, Alumni or Staff
experience without accounts, backend configuration or internet. Simulated changes
stay on the device. See the [presentation guide](docs/demo-presentation-guide.md)
and [demo architecture](docs/task08a-demo-experience.md).

Real community features retain Supabase authentication, membership verification,
privacy and server authorization. Login never grants verified access. Real entry
requires reviewed public build configuration; missing configuration shows setup.
Official catalogs and pending hosted migrations require separate approval.

## Development

Current repository: `D:\MSGI_nexus`; Dart package: `msgi_one`. The requested move
to `D:\MSGI_One` is pending: Windows rejected the verified repository rename
because a process has an open handle. The original repository/history are intact.
Task 03A deliberately works in this existing directory and does not retry relocation.
Android application ID remains `com.msgi.nexus.msgi_nexus` intentionally.

Verified setup: Flutter **3.50.0 stable**, Dart **3.14.0**, Android API **36**,
Build-Tools **36.0.0**, NDK **28.2.13676358**, Android Studio Java **25.0.4**.
Use the generated Gradle wrapper; no global Gradle installation is required.

```powershell
cd D:\MSGI_nexus
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d <android-device-id>
```

Preferred development device: `MSGI_One_Pixel_4a_API_34` / `emulator-5554`.
The offline demonstration is exercised on this emulator. Physical-device checks
remain separate; the project does not change Windows security settings.

Kotlin incremental compilation is disabled for this project to work around a
reproduced Windows cache-registration failure; see the engineering decisions.

```powershell
dart format lib test
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

APK: `build/app/outputs/flutter-apk/app-debug.apk` (debug, not production signed).
If Java downloads time out on this machine, retry with these terminal-session-only
options used successfully during toolchain validation:

```powershell
$env:JAVA_TOOL_OPTIONS = '-Djava.net.preferIPv4Stack=true -Djava.net.useSystemProxies=true'
```

This uses existing Windows proxy discovery. It does not set proxy credentials,
disable TLS or change system settings. Try ordinary builds first.

## Dependencies

| Package | Resolved version | Purpose |
| --- | --- | --- |
| flutter_riverpod | 3.5.0 | Shared state and dependency injection |
| go_router | 18.1.4 | Centralized navigation and shell |
| supabase_flutter | 2.18.3 | Authentication adapter; initialized only with reviewed public configuration |
| material_ui | 1.11.0 | Material widgets from installed Flutter template |

`pubspec.lock` pins the transitive resolution. No dependency upgrades without a
demonstrated reason. No external images, fonts or branding assets are downloaded.

## Screens

| Screen | Route |
| --- | --- |
| Startup | `/` |
| Welcome | `/welcome` |
| Login / signup forms | `/login`, `/signup` |
| Dashboard | `/home` |
| Discover alumni | `/discover` |
| Global alumni map | `/map` |
| My network | `/network` |
| Profile | `/profile` |
| Mentor recommendations preview | `/mentors` |
| Career opportunities preview | `/opportunities` |

Without backend configuration, `/setup` explains the development integration
requirements. With a reviewed backend, users sign up, confirm email, complete
`/onboarding`, and wait at `/verification-pending` for trusted approval. Rejected
or suspended accounts go to `/membership-status`. Loading/error/recovery routes
fail closed. Only verified members reach the five bottom destinations and
mentor/opportunity screens. Directory and profiles now use authorized repositories;
other feature data remains labelled samples.

## Engineering documentation

- [Architecture and future Supabase integration](docs/architecture.md)
- [Requirements and MVP scope](docs/requirements.md)
- [Engineering decisions](docs/decisions.md)
- [Agent conventions](AGENTS.md)
- [Task 02 verification results](docs/verification.md)
- [Task 02B rebranding results and relocation blocker](docs/rebranding.md)
- [Database schema and RPCs](docs/database-schema.md)
- [Security model and unexecuted database-test gates](docs/security-model.md)
- [Authentication flow](docs/authentication-flow.md)
- [Exact next Supabase setup steps](docs/supabase-setup.md)

Next: approve policies/catalogs and run the migrations plus pgTAP tests on an
isolated local stack before any authorized hosted-development integration. The
SQL tests are unexecuted while local CLI/Docker/PostgreSQL are unavailable. Do
not treat Flutter fakes as RLS evidence. Follow `docs/supabase-setup.md` to supply
actual public build configuration only after review. Never bundle privileged
keys; client configuration does not replace authorization. No external accounts,
hosted Supabase projects or remote repositories are created here.

Task 05 implements live map and professional connection repositories. See
[map/network contracts and local validation](docs/task05-map-network.md) for
privacy, local fixtures, optional provider licensing and hosted prerequisites.

Task 06 implements deterministic, server-ranked mentor recommendations at
`/mentors`, private career/learning goals and existing professional connection
actions. See [mentor matching](docs/task06-mentor-matching.md) for algorithm,
privacy, local test commands and hosted prerequisites.

Task 07 implements the live Career Bridge: jobs, internships, referral flags,
project posts, scoped discovery, private drafts, author edits/closure/archive and
moderation reports. See [Career Bridge](docs/task07-career-bridge.md) for publishing
permissions, local test commands and hosted deployment requirements.

## Competition UI

Task 08B refines the shared theme, dashboard highlights, discovery filter sheet,
mentor cards and Career Bridge controls. See
[UI audit and validation limits](docs/task08b-ui-polish.md).
Build without backend defines for the offline demo. Real community access retains
all existing configuration, authentication and membership requirements.

## Consumer experience

Task 08C adds compact result feeds, retained demo tabs, a full-viewport offline map
and named fictional professional identities. Existing saved demo activity upgrades
without affecting real authentication storage. See the
[consumer experience audit](docs/task08c-consumer-experience.md).
