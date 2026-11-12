# Task 02B — MSGI One rebranding

Verified on November 12, 2026. This is a controlled modification of the existing
repository, not a recreated project.

## Current identity and location

- Display name: **MSGI One**.
- Tagline: **One Community. Infinite Connections.**
- Dart package: `msgi_one`.
- Android application ID and namespace: `com.msgi.nexus.msgi_nexus` (unchanged).
- Current project path: `D:\MSGI_nexus`.
- Requested destination: `D:\MSGI_One` (not created).

The working tree was clean at the start. Original HEAD was
`060b7fc3729b1580bc191762ede886dfaf10b142`; the existing history is preserved.

## Changed files and scope

- `pubspec.yaml`: package name and description; dependency constraints unchanged.
- `lib/core/config/app_config.dart`: current application name and tagline.
- `lib/app.dart`, `lib/main.dart`: renamed application class; Material title uses
  the shared name constant.
- `lib/core/widgets/nexus_shell.dart` → `one_shell.dart` and
  `nexus_widgets.dart` → `one_widgets.dart`: branding identifiers and shared label.
- `lib/core/theme/app_theme.dart`: branding identifier rename only; theme values unchanged.
- `lib/core/routing/app_router.dart`, `lib/core/errors/error_state.dart` and the
  affected feature screens: updated renamed-widget/theme references and imports.
- `lib/features/auth/presentation/auth_screens.dart`: signup branding, shared
  constants, centered longer tagline; login/preview behavior unchanged.
- `test/app_test.dart`, `test/discovery_test.dart`: package imports, branding
  expectations and a regression test for startup/shell branding.
- `android/app/src/main/AndroidManifest.xml`: display label only.
- `README.md`, `AGENTS.md`, `docs/architecture.md`, `docs/requirements.md`,
  `docs/decisions.md`, `docs/verification.md`, and this record: current branding,
  accurate history, verification and relocation status.
- Ignored local IDE module filenames and `.idea/modules.xml`: updated module
  references without changing global IDE settings.

`pubspec.lock`, Android application ID/namespace, Kotlin activity package,
dependency versions, Gradle settings, routes and feature behavior are unchanged.

## Actual verification in the original directory

| Command / check | Result |
| --- | --- |
| `flutter pub get` | Passed; lockfile unchanged |
| `dart format lib test` | Passed |
| `flutter analyze` | No issues found |
| `flutter test` | All 25 tests passed, including the previous 24 tests |
| All eleven screens | Reachability and interaction tests passed |
| Responsive layouts | Existing 320/390/840-width, 100%/200%-text tests passed |
| `flutter build apk --debug` | Passed, 34.2 seconds |
| APK inspection with Android Build-Tools aapt | Label `MSGI One`; package `com.msgi.nexus.msgi_nexus` |

APK: `build/app/outputs/flutter-apk/app-debug.apk`, 195,657,438 bytes. This is an
ignored debug artifact, not a production-signed release. Build-time Java network
options remained terminal-session-only; no global tools were changed.

No device launch or device visual testing is claimed. Pub still reports three
informational newer-version notices for constrained transitive dependencies;
no dependency upgrade was made.

## Relocation blocker

Only after successful code/test/APK verification, a native PowerShell directory
move was attempted from the parent directory, with exact resolved source and
destination checks and refusal to overwrite an existing target. Windows returned:

> The process cannot access the file because it is being used by another process.

The source `.git` and original HEAD were rechecked and remain intact. The new
destination is absent. No forced deletion, repository copy, reset or history
rewrite was attempted. The owner of the open handle has not been established.

Close editors, terminals or other processes holding the folder before retrying
the move from its parent directory. After a successful move, update current
README location instructions, refresh generated Flutter package/build metadata,
and verify the build in the new location. Historical paths below should remain.

## Intentional old references

- Android ID, namespace, Kotlin activity package/path: explicitly preserved.
- Original Task 02 decision/verification records: historical evidence, clearly labelled.
- Original directory in current setup instructions and this blocker record:
  accurate because relocation failed.
- Existing Git history and the requested rebranding commit message: preserved.
- Old filenames in this change record: explain Git-tracked renames.

There are no old-brand strings or package imports in current Dart code, or old
branding in the Android display label. The previous tagline is no longer used.

The foundation is ready for future Supabase integration, subject to the existing
requirements to approve verification rules, schema/RLS and real public client
configuration. No backend account, credentials or real authentication was added.
