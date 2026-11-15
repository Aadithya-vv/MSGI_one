# Task 12C: signed competition release candidate

Date: November 15, 2026 (Asia/Calcutta). Starting HEAD:
`a1c299ba3298ce91fcbc7307d8bb22c4b4ae2804`.
Scope: local offline candidate construction and disposable-emulator acceptance.
No distribution, submission, hosted changes or physical-device modifications.

## Artifact identity and fallback protection

| Property | Frozen fallback | New candidate |
| --- | --- | --- |
| Path | `build/competition-release/MSGI-One-1.0.0-competition.apk` | `build/competition-release-candidate/MSGI-One-1.0.1-rc1.apk` |
| Version / code | 1.0.0 / 1 | 1.0.1 / 2 |
| Bytes | 57,966,548 | 56,049,560 |
| Application ID | `com.msgi.nexus.msgi_nexus` | Same |
| Display name | MSGI One | MSGI One |
| Minimum / target API | 24 / 36 | 24 / 36 |
| Native ABIs | arm64-v8a, armeabi-v7a, x86_64 | Same |
| Verified signature | APK Signature Scheme v2 | Same |

Fallback SHA-256:
`aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.

Candidate SHA-256:
`3b8d41351b554e3603c9e0d747357a359b3ec1651d4431e7e9643534ab9bc2e7`.

Both APKs independently verify with certificate SHA-256:
`857fbe0fc6d3366bb46c59745fce24eb03cef23b78a6b030a24148fb0d995cc4`.
This is the existing dedicated competition identity, not the Android debug signer.
Candidate is 1,916,988 bytes smaller (about 3.31%); size alone is not a quality
claim. Version overrides are fixed in the candidate wrapper, leaving ordinary
development pubspec versioning and Android application identity unchanged.

## Frozen scope and security

The candidate includes the finite-world map fix, existing demo experiences and
the MSGI One design system. MSEC uses a clean text-only institution card, with no
photo slots, broken-image icons or pending-approval placeholders. Official campus
photographs and crest remain excluded; permission is still unconfirmed. The
inspection-only source copies remain ignored and unbundled. See
[media approval inventory](msec-media-approval.md).

`MSGI_COMPETITION_ONLY=true` hides real signup/sign-in and ignores incoming auth
callbacks before backend initialization. The normal development default retains
working authentication. No backend defines/config files are supplied to signing.
Real users, administrative operations, SMTP, hosted schema and authorization
rules are not activated by this build. All demo personas and activity remain
explicitly fictional; Staff is not an administrator.

APK inspection reads all 376 ZIP entries. AOT libapp libraries and bundled map/
license notices are present; no debug kernel is present. The manifest has no
debuggable flag, disables backup and cleartext traffic. Existing INTERNET access
is retained from the shared manifest; the only additional uses-permission is the
AndroidX signature-scoped dynamic-receiver permission. No location, contacts,
storage or camera permission is requested. No privileged-key patterns, hosted
project literal, private signing/config files or prohibited-media filenames/
original byte hashes were found. Static scanning is not a proof against every
obfuscated secret or every possible runtime action.

The existing `com.msgi.one.dev://auth-callback/` intent filter retains exact host
and path matching; competition mode ignores it. Signed-binary callback acceptance
is recorded below. No hosted authentication test or email request is part of QA.

## Signing and build procedure

`tool/Build-CompetitionCandidate.ps1` has a fixed output/version/mode. It checks
the original hash and refuses an existing candidate or checksum before private
signing access. It uses the existing Windows-account DPAPI password handoff only
in process environment variables, clears/restores those variables in finally,
disables Gradle daemon use, verifies certificate continuity and copies exclusively.
No key/password was changed, committed, printed or passed on the command line.
The old release wrapper remains frozen and unchanged.

PowerShell's system execution policy blocked direct script invocation; a child
process-only `-ExecutionPolicy Bypass` ran the reviewed wrapper without changing
machine policy. The first compilation failed because `--no-pub` retained an
integration-test entry in GeneratedPluginRegistrant after integration. Removing
that optimization lets Flutter regenerate its own plugin files using the existing
lockfile; no Java/Gradle/dependency change was made. A later successful build
stopped before copy because Windows PowerShell interpreted an apksigner Java
warning as an error. The wrapper now captures stdout/stderr separately and checks
the verifier process exit code and expected certificate explicitly. The final
build succeeded (assembleRelease 30.7 seconds; earlier successful compilation
70.3 seconds). Native verification stderr was empty on the final run.

The build reported a CupertinoIcons-family warning while optimizing icons.
Material icons were tree-shaken normally. Rendered welcome/Home/map controls were
inspected; no missing-icon defect was observed there. No dependency was added to
silence an otherwise unused-family warning.

## Automated source validation

- Formatter: 105 files checked, zero remaining changes.
- Flutter analyzer: no issues, including final integration driver.
- All Flutter tests: **212 passed** (the previous 211 plus competition-entry
  callback/backend-isolation coverage).
- Two Android integration journeys passed, plus runner teardown; 21 screenshots.
  These are debug/current-source tests with the competition flag, distinct from
  ordinary signed-binary acceptance. Tests reject HTTP creation and assert zero
  attempts; preserve the independent preferences namespace/sentinel.
- Map tests cover non-wrapping CRS, viewport containment/fractional display
  sizes, antimeridian normalization, zoom, resize, vertical movement and markers.
- No database/API suites were repeated: SQL, RLS and backend contracts unchanged.

Logs and public runtime evidence are local/ignored under `build/task12c/`:
`flutter-tests.log`, `analyze-final.log`, `integration.log`, `release-build.log`,
`signature-verification.txt`, `candidate-badging.txt`, `candidate-manifest.txt`,
`apk-inspection.json`, and `integration-summary.json`. Signing secrets are not
part of that evidence or the committed report.

## Ordinary signed candidate acceptance

Acceptance status: **passed** on the ordinary signed APK, independently from
debug/source integration.

The base walkthrough passed 21 screen checks. Deeper interactions produced 15
additional unique captures: keyboard/name search, profile disclosure, a simulated
connection request and restart persistence, no-match state, filter controls,
Alumni mentor/publishing entry, incoming acceptance, reset and enlarged text.
Actual programme application, opportunity form editing and profile edits are
also covered by the separate source integration; they are not silently relabelled
as ordinary signed-APK assertions.

The map walkthrough captured both edges and repeated outward swipes at three
successive zoom levels. All **six stationary map-region pixel comparisons**
matched exactly after additional outward swipes (crop excludes status/header,
controls and city sheet). Source/native numeric bounds independently verify the
camera's longitude/latitude limits. Inspected signed edge screenshots show no
replicated world or endless horizontal movement. London filtering and tapping
the painted city marker opened the alumni panel. Background/resume, a synthetic
invalid auth callback, exiting the demo and re-entry all passed. No account logout
is claimed: this is an offline demo with no authenticated backend session.

The first marker assertion tapped the outer Android semantics region, whose
bounds cover the map viewport, rather than the visible marker child. Inspection
confirmed the numeric button's actual bounds; the harness now taps that button.
The final interaction portion was resumed explicitly with `--finish`, retaining
the twelve already captured edge images; pixel validation then passed. The APK
was not changed to accommodate the test. This semantics-boundary observation is
an accessibility review item; TalkBack behavior remains unverified.

There are **53 signed-candidate screenshots** in `build/task12c/signed-apk/` and
21 debug integration screenshots in `build/task12c/integration-screenshots/`.
Welcome, Student Home, initial map and opposing zoomed boundaries were visually
inspected. Safe hashes are recorded in `task12c-release-manifest.json`; no image
or raw runtime log is committed. Sampled signed-app diagnostics show no crash/ANR,
overflow/unhandled exception or token-pattern finding. Wi-Fi/data are off,
airplane mode enabled, active default network none. That is bounded acceptance
evidence, not a lifetime crash guarantee or a release-performance benchmark.

Target is the explicitly disposable workspace AVD `MSGI_Task12A_Disposable`,
device `emulator-5556`, API 34 x86_64, Pixel 4a, 2 CPU cores, 2,048 MB RAM, host
GPU and usable WHPX. Storage is separate from normal development AVDs. Only this
AVD may be uninstalled/reinstalled. Samsung was not queried or modified.

## Comparison and remaining limitations

The original permits visible repeated continents and unconstrained horizontal
travel. The candidate uses the Task 12B non-wrapping Mercator adapter and
viewport-aware bounds/minimum zoom, preserving zoomed vertical navigation.
Signed-binary edge comparisons corroborate the source numeric assertions.

Welcome/Home/profile now use text-only institutional context. The entry no longer
offers an unconfigured real-account path in the competition build. Both releases
retain synthetic discovery, mentors, simulated connections/careers and three-role
navigation. The native launcher icon is unchanged; official MSEC media/endorsement
is not claimed. No new major feature was introduced.

Physical Samsung acceptance of this new binary is deliberately **not performed**.
API 24 hardware, other GPUs/OEM keyboards, screen-reader focus order, predictive
Back gestures, projection compatibility and release-performance benchmarking are
not established. Existing enlarged-text quick-action wrapping/horizontal scrolling
remain P2 polish limitations, not claimed fully accessible. Independent signing
recovery/custody and organizer/faculty rules/sign-off remain distribution gates.
The owner-provided target is November 30, 2026, not a verified organizer deadline.

No outstanding P0/P1 app defect was identified within the executed offline scope.
The 56 Task 12A frozen files and 39 Task 12B screenshots still match their hashes.
The existing-candidate wrapper guard was executed and rejected replacement before
signing access. Android configuration, pubspec/lockfile and unrelated untracked
reports are preserved. The disposable emulator is shut down after acceptance;
its storage is retained.

**RELEASE CANDIDATE GO** for owner review and supervised offline demonstration
selection. Prefer this candidate for its verified bounded map and clean entry,
while retaining v1.0.0 as fallback. This is **not distribution or submission
approval**: owner approval, organizer/faculty requirements, independent signing
custody and presentation-device/projection acceptance remain gates. Do not claim
public onboarding, official media licensing or new Samsung acceptance.

Reproduction uses the fixed disposable target only:

```text
node tool/audit_competition_candidate.cjs
node tool/audit_candidate_demo.cjs
node tool/audit_candidate_interactions.cjs
node tool/audit_candidate_map.cjs
powershell -NoProfile -ExecutionPolicy Bypass -File tool/Compare-CandidateMapEdges.ps1
```

Do not copy install/uninstall commands to Samsung or a valuable emulator. The
candidate builder deliberately refuses to rebuild over the existing output.
