# MSGI One

**One Community. Infinite Connections.** Android-first alumni networking for MSGI.

Task 02 is a branded, offline foundation: a responsive dashboard, eleven screens,
Riverpod-managed sample content and GoRouter navigation. Authentication,
verification, database access and live maps are not implemented. Every profile
and opportunity is explicitly a sample.

## Development

Current repository: `D:\MSGI_nexus`; Dart package: `msgi_one`. The requested move
to `D:\MSGI_One` is pending: Windows rejected the verified repository rename
because a process has an open handle. The original repository/history are intact.
Close applications or terminals using the folder before retrying relocation.
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

Enable USB debugging on your Android phone and personally authorize the computer.
No Android device or working emulator was available for launch validation.
Emulator acceleration requires separate hypervisor setup; the project does not
change Windows security settings. Restart terminals/VS Code after PATH changes.

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
| supabase_flutter | 2.18.3 | Future integration; not initialized |
| material_ui | 1.11.0 | Material widgets from installed Flutter template |

`pubspec.lock` pins the transitive resolution. No dependency upgrades without a
demonstrated reason. No external images, fonts or branding assets are downloaded.

## Screens

| Screen | Route |
| --- | --- |
| Startup | `/` |
| Welcome | `/welcome` |
| Login / signup previews | `/login`, `/signup` |
| Dashboard | `/home` |
| Discover alumni | `/discover` |
| Global alumni map placeholder | `/map` |
| My network | `/network` |
| Profile | `/profile` |
| Mentor recommendations preview | `/mentors` |
| Career opportunities preview | `/opportunities` |

Get started → Explore sample dashboard. Bottom navigation reaches Home, Discover,
Map, Network, Profile. Dashboard cards reach mentorship and opportunities.
Unknown routes provide safe recovery. Sample directory search matches fields/cities.

## Engineering documentation

- [Architecture and future Supabase integration](docs/architecture.md)
- [Requirements and MVP scope](docs/requirements.md)
- [Engineering decisions](docs/decisions.md)
- [Agent conventions](AGENTS.md)
- [Task 02 verification results](docs/verification.md)
- [Task 02B rebranding results and relocation blocker](docs/rebranding.md)

Next: approve verification requirements, final application ID, schema and RLS
before implementing authentication. Never embed service-role keys. Build-supplied
public keys/endpoints are extractable and do not replace backend authorization.
No external accounts, Supabase projects or remote repositories are created here.
