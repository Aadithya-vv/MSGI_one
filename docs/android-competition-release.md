# Android competition release

## Task 12A freeze

The existing `MSGI-One-1.0.0-competition.apk` is frozen at SHA-256
`aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.
Do not run the historical build commands below to replace it. The wrapper now
refuses an existing artifact/checksum before reading signing material, and its
final copy cannot overwrite a concurrently created file. A new version/output
destination needs separate owner approval. This does not authorize a new build.
See [the release audit](task12a-competition-release-audit.md).

The standalone demo uses the existing `com.msgi.nexus.msgi_nexus` application ID,
`MSGI One` launcher label and `com.msgi.one.dev://auth-callback/` callback. Version
is currently `1.0.0+1`; increase the build number for future distributed updates.
No official college artwork has been added. The existing launcher icon is retained.

## Signing and reproducible build

Run from the repository in a trusted local Windows PowerShell:

```powershell
# Once only; refuses to overwrite an existing signing directory.
powershell -NoProfile -ExecutionPolicy Bypass -File tool/New-CompetitionSigning.ps1
# Subsequent builds use the same signing identity.
powershell -NoProfile -ExecutionPolicy Bypass -File tool/Build-CompetitionRelease.ps1
```

The execution-policy override applies to that process only. These scripts do not
change Windows policy, Android SDK settings, application ID or dependencies.
The dedicated RSA-3072 PKCS12 keystore lives outside the repository at
`%LOCALAPPDATA%\MSGIOne\signing\msgi-one-competition.p12`. Its random password is
encrypted with current-user Windows DPAPI in `password.dpapi`; directory access
is restricted to the creating Windows user. It is decrypted only into build
process environment variables and never printed or saved in Gradle properties.
Protect this Windows account; DPAPI is not protection against a compromised
logged-in session. Do not run verbose Gradle environment dumps while signing.

Release signing has no debug fallback. Direct release builds without complete
signing environment variables fail. Debug builds retain normal debug signing.
The wrapper does not accept extra Dart defines or load any backend JSON file.
It builds the offline-capable presentation launcher with no Supabase values.

Before distribution, independently back up the keystore **and its password** in
approved secure storage/password management, with restricted access and a recovery
test. DPAPI ciphertext alone is not a portable backup: losing this Windows account
or machine can make it unusable. Never regenerate the key to solve a password
problem; an update must use the same certificate. Do not put signing material in
Git, reports, screenshots, APK archives or chat. Backup completion requires the
owner's confirmation; automated key creation does not establish recovery readiness.

## Artifacts and installation

Ignored outputs are under `build/competition-release/`, including the clearly
named APK, SHA-256 checksum, certificate verification, acceptance report and
installation guidance. Verify the checksum before sharing/installing the APK.

Android cannot update a debug-signed installation with the dedicated release key.
Compare installed and release certificates first. Do not uninstall or clear data
without owner approval; removal loses local demo progress and authentication
sessions because backup is disabled. Keep the existing application ID. Do not
work around a mismatch with another package name or debug signing.

The release manifest disables backup and arbitrary HTTP. Debug-only localhost
network security resources are not part of the release manifest. Internet remains
required for the separately guarded real authentication path; the demo itself
works offline and does not create a Supabase session. No hosted catalog/data or
authentication changes are part of release preparation.

## Acceptance boundaries

The widget integration harness uses its own preference namespace and verifies
the presenter's real demo snapshot remains unchanged. It exercises real Android
rendering with simulated widget taps/keyboard input; this does not prove physical
touch ergonomics, the Samsung keyboard, TalkBack or Android gesture behavior.
It does not represent manual acceptance of the ordinary signed APK.

Always invoke debug device acceptance through `tool/Test-AndroidDemo.ps1
-DeviceId <id>` (or the existing offline emulator runner). Both explicitly pass
`--keep-app-running`: Flutter 3.50 `drive` otherwise stops **and uninstalls** its
test application on completion, deleting installed app data. A separate storage
namespace alone cannot protect against that uninstall. Do not run a bare
`flutter drive` against a device containing presenter data.

During Task 10A+B the initial Samsung command omitted this flag. Its functional
assertions passed, including snapshot preservation during execution, but Flutter's
cleanup then uninstalled the app and removed its local data without prior owner
approval. This was an execution error, not an owner action or an application
defect. It was disclosed immediately after the cause was identified. No recovery
of previous local progress/sessions is claimed. Future harness invocations retain
the installation; signed APK testing uses ordinary ADB installation/launch.

Fresh release installation is tested on a separately created AVD in ignored build
storage, leaving the existing emulator data intact. Record physical
and emulator results, debug versus release performance, and automated versus
manual results separately. Verify cold restart, role persistence and airplane/
offline navigation on the actual release APK. A successful activity launch timing
is not time-to-interactive or a scroll/frame performance measurement.

Manual Samsung checks: navigate all roles with normal touch and system Back,
type/search/edit using the Samsung keyboard, rotate the phone, inspect status and
navigation bars, and test larger system text. For TalkBack, enable it manually in
Settings → Accessibility → TalkBack, swipe through navigation/forms/cards, check
labels and focus order, and double-tap primary actions. Record results and restore
the owner's preferred settings. Do not claim unperformed checks passed.
