# Approved MSGI One logo integration

Verified November 16, 2026. Uses the owner's supplied and approved MSGI One app
logo. Separate MSEC crest/photo restrictions remain.

## Artwork and implementation

Original: `assets/branding/msgi-one-logo-original.png`, 1254×1254 with alpha.
SHA-256: `6b2ba085ddf111e60508f8507b73d7034f5bebf981da3b9b9469f862aa1b7f54`.
The double file extension was corrected; original bytes are unchanged. The
original embedded in the APK independently hashes to this same value.

`msgi-one-emblem.png` is a lossless crop `(150,118,960,774)` above the wordmark.
No redraw, color filter, cleanup, stretching or replacement lettering was used.
Existing source edge artifacts remain. `tool/Prepare-BrandAssets.ps1` verifies
the source hash and reproduces native proportional sizing/padding.

- Flutter welcome/loading: full approved image through `BrandMark`.
- Shared application shell: emblem plus app-name text.
- Demo Home/subpage headers: emblem plus name at normal widths, emblem-only on
  narrow/enlarged layouts to preserve room for role controls.
- Android launcher: five legacy density PNGs and an adaptive foreground/background.
- Splash: full logo on older Android launch backgrounds; padded emblem in
  Android 12+ day/night launch themes. Background uses existing `#F5F7FC`.

The adaptive foreground has a 108-dp canvas with artwork width 60 dp; Android 12+
splash uses a 288-dp canvas with artwork width 168 dp. Padding follows the safe-area
principles in [Android adaptive icon guidance](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)
and [Android splash guidance](https://developer.android.com/develop/ui/views/launch/splash-screen).
API 34 native rendering was inspected; older Android splash rendering is compiled
and configured but was not separately exercised.

No app ID, authentication behavior, membership policy, Gradle configuration or
dependency version changed. `pubspec.lock` is retained; no new graphics plugin.

## Actual verification

| Check | Result |
| --- | --- |
| Formatter | 105 lib/test files; formatted |
| Analyzer | No issues |
| Full Flutter suite | **214 passed**, including two new logo/widget checks |
| Android debug build | Succeeded; assembleDebug 92.4 seconds |
| App identity | MSGI One; `com.msgi.nexus.msgi_nexus`; minimum API 24 |
| Candidate version | `1.0.2-logo-debug`, code `3` (build overrides only) |
| Candidate mode | Debug-only, offline competition flag, no backend defines |
| Emulator | `MSGI_Task12A_Disposable`, `emulator-5556`, API 34 |
| Ordinary APK checks | Launcher, native splash, welcome, roles, all three role headers, mentor/profile headers, 2× text |
| Sampled diagnostics | No crash, render or missing-asset error |
| Screenshots | **12**, with hashes in `logo-integration-evidence.json` |

This was actual ordinary-debug-APK acceptance, separate from the unit/widget
suite. Wi-Fi/data were disabled on the disposable emulator, and font scale was
restored. Only this workspace-owned AVD was uninstalled/reinstalled. No account
or email test was attempted; no Flutter integration-test journey was rerun or
claimed here. Native splash, welcome, launcher and normal/enlarged headers were
visually inspected. Existing enlarged-text/dense-content limitations remain;
no whole-app accessibility or physical OEM launcher acceptance is claimed.

## Artifact and evidence

Debug APK: `build/logo-integration/MSGI-One-logo-debug.apk`.
SHA-256: `768da38a4e3d82f7d75a1cdba54b9051f2ecc048144d122ed9e32c08379750c8`.
This debuggable artifact is not a replacement signed competition release.

Local screenshots/logs: `build/logo-integration/`. Captures include launcher,
`native-startup-{1,2,3}.png`, `welcome-logo.png`, role selection, Student/Alumni/
Staff/mentor/profile headers and `large-text-emblem-header.png`.

Both protected signed APKs still match their original hashes:

- v1.0.0: `aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.
- v1.0.1 RC1: `3b8d41351b554e3603c9e0d747357a359b3ec1651d4431e7e9643534ab9bc2e7`.

No Samsung command/installation, hosted operation, signing-key access, push or
replacement signed release occurred. The disposable emulator was shut down after
capture; storage retained. Unrelated untracked reports are preserved. The owner
subsequently requested a logo-only Git checkpoint; its scope includes the approved
artwork, branding resources/widgets, tests, reproduction tools and documentation.
The debug APK, raw captures and temporary build files remain outside Git.
