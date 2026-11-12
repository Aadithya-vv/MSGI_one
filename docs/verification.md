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
