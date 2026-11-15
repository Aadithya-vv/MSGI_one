# Task 12D: physical device and presentation readiness

Reviewed November 15, 2026 (Asia/Calcutta), HEAD
`50901e200e0d215445dba199057c6eefdf813f96`.
**Read-only Samsung inspection completed. Installation and physical RC1
acceptance remain PENDING. No installation command in this report was executed.**

## APK verification

| Property | Protected fallback | Candidate |
| --- | --- | --- |
| File | `build/competition-release/MSGI-One-1.0.0-competition.apk` | `build/competition-release-candidate/MSGI-One-1.0.1-rc1.apk` |
| Version / code | 1.0.0 / 1 | 1.0.1 / 2 |
| Size | 57,966,548 bytes | 56,049,560 bytes |
| ID | `com.msgi.nexus.msgi_nexus` | Same |
| Minimum / target API | 24 / 36 | Same |
| Native ABIs | arm64-v8a, armeabi-v7a, x86_64 | Same |
| Fresh signature verification | v2 verified | v2 verified |
| ZIP / security inspection | 376 readable entries; no findings | 376 readable entries; no findings |

Fallback SHA-256:
`aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.

Candidate SHA-256:
`3b8d41351b554e3603c9e0d747357a359b3ec1651d4431e7e9643534ab9bc2e7`.

Both certificate SHA-256 fingerprints freshly verified:
`857fbe0fc6d3366bb46c59745fce24eb03cef23b78a6b030a24148fb0d995cc4`.
No private signing material was accessed. Both binaries are unchanged; Task 12C's
76 artifact/evidence hashes also match. Static inspection is not an exhaustive
proof of absence of every possible runtime secret or security defect.

## Samsung: actual read-only observations

- Connected, authorized device `RZ8RA1DN4YA`, Samsung **SM-M215G**.
- Android **13**, API **33**; ABI list `arm64-v8a,armeabi-v7a,armeabi`.
- MSGI One installed as **1.0.0, version code 1**, min API 24 / target 36.
- Installed base APK SHA-256 exactly equals the fallback hash above. This
  establishes certificate compatibility by exact byte identity with the freshly
  signature-verified original, without pulling the APK or reading private data.
- Package ID matches RC1; code increases from 1 to 2; Android and ABI requirements
  are compatible. An in-place update **appears compatible**, subject to the
  package installer's checks. Actual installation success is untested.

Commands used: `adb devices -l`; device-scoped `getprop` for model/version/API/ABI;
`dumpsys package` filtered to version metadata; `pm path`; and `sha256sum` of the
installed base APK. No app launch, force-stop, install, uninstall, clear/reset,
notification inspection, app-private file access or physical UI test occurred.
Sanitized local evidence is in ignored `build/task12d/`.

## Data-preservation assessment

The release-era source identified by Task 12A is commit
`93f710a2d694584e58cb583e047ff81dff17eafd`. Its persistence/store files are identical
to current source, with matching Git blobs:

- `demo_persistence.dart`: `0ff3dd83d963434fb6746ad0b1d39064c44272a3`.
- `demo_store.dart`: `4296e7cf9e906f7fd8fb019daee69878ab6cd13a`.

`pubspec.lock` also has no changes from that reference. These are source-provenance
comparisons, not a claim that the old build was reproduced deterministically.

The app still uses `SharedPreferencesAsync` key
`msgi_one.competition_demo.v1`, with JSON payload format **3**. Snapshots contain
role, active flag, tick, profiles, connections, posts, mentoring goals, reports
and blocks. The storage namespace, fixture identities and serialization contract
are unchanged; no new migration is required for a valid v3 snapshot. Role,
profile edits, requests/statuses, saved posts and goal/privacy settings should
remain available under a successful same-package, same-signer `-r` update.

Existing format-1/2 upgrade handling is unchanged: some original sample wording
is refreshed for format 1, and format-2 academic affiliations are mapped to MSEC.
This is not a new RC1 migration. Transient route/tab state, search/filter controls,
map camera position and unsaved input are not all represented in the snapshot;
returning to Home/default filters is not proof that saved demo records were lost.

Startup has no unconditional storage clear/reset. However malformed JSON,
unsupported formats, invalid profile/relationship shapes or unavailable storage
can fall back to fresh/in-memory fixtures; subsequent mutations may write that
state. This pre-existing behavior means data preservation is **not guaranteed**.
The phone's stored contents were deliberately not inspected or exported.

RC1's offline-only flag removes real-account entry and ignores auth callbacks.
Startup restores demo state without invoking real-backend sign-out. Existing SDK
session contents were not inspected; the candidate does not provide real-account
access. Demo exit is not authentication logout.

Both APKs disable Android backup. No supported demo export/import or independently
verified phone-state backup is available in this task. The fallback APK is a
binary fallback, **not a backup of local state**. If preserving the exact current
demo state is essential, hold installation pending a separately approved backup/
export strategy. A higher version code alone does not establish preservation.

## Specific installation approval gate

Proposed operation, **NOT EXECUTED**:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s RZ8RA1DN4YA install -r "D:\MSGI_nexus\build\competition-release-candidate\MSGI-One-1.0.1-rc1.apk"
```

Owner must explicitly authorize this **SM-M215G / RZ8RA1DN4YA**, current verified
v1.0.0+1, exact RC1 path and SHA-256, as a data-retaining in-place update only.
Task 12D Phase 4 explicitly excludes installation from this task's authorization.
This proposed command has no downgrade, test-APK, permission-grant, uninstall or
clear-data option. Recheck device identity, installed version/signer and both
hashes immediately before any subsequently approved execution; stop on change.
Do not automatically launch, reset or otherwise test the phone beyond the next
authorization's scope.

Remaining risks: no verified private-state backup; unexpected serialization or
storage failure; installer/device-policy/free-space rejection; OEM behavior;
unverified RC1 hardware ergonomics, keyboard and projection. Successful installer
return does not establish functional or data-preservation acceptance.

On installation failure, preserve the existing installation and stop; never
uninstall/clear/retry as a shortcut. After a successful update with a defect,
record sanitized symptoms and seek a reviewed **forward fix** with the same signer
and higher version code. Reinstalling code 1 over code 2 is a downgrade and may
be rejected; do not promise `-d` or the old APK will restore private data. Use the
original on a separately approved device or the existing screenshot fallback
while a remedy is reviewed. No recovery modification is authorized here.

## Projection review and operator workflow

Task 12C's verified emulator captures were reviewed, including Student/Alumni/Staff
Home, mentor cards and map. Portrait hierarchy, navy headings and gold markers
are legible on the inspected laptop images. Headings and primary actions are
larger than secondary profile/institution text, which needs zoom on a projector.
Horizontal quick-action labels can wrap awkwardly and filters require swiping;
avoid showing a dense full-height phone image as if every small label is readable
from the back of a room. Keep portrait proportions, narrate the current role and
enlarge detail views as needed. Do not stretch the image to landscape.

Source-color calculations give navy/white **14.32:1**, muted/white **6.35:1**,
navy/gold **8.44:1** luminance contrast. These selected opaque color pairs are not
a whole-app accessibility certification or a projector brightness measurement.
TalkBack focus/marker semantics, predictive gestures and room viewing distances
remain unverified. Task 12C's enlarged-text and touch/Back results are emulator
evidence only; no new emulator or Samsung walkthrough was run here.

`scrcpy` was not detected on PATH; no mirroring software was installed or searched
in unrelated private stores. Actual phone mirroring, projector/cable operation
and notification interruption behavior are **PENDING**. No Windows display,
phone Do Not Disturb, network or security setting was changed.

Simplest prepared review path: open the local signed-RC1 screenshots in the
existing image viewer/IDE and share that window through the already approved
presentation tool, clearly calling it recorded emulator evidence. Select Home,
discovery, mentor, map and the other two roles. Keep the offline images available
locally. If a live emulator is used later, use an existing approved displayable
AVD and the reviewed RC1; this task did not start or modify one.

For live phone projection, first obtain update/launch and screen-sharing consent,
then use an already installed approved mirroring method after checking Samsung
support. Do not assume USB-C video output or Phone Link screen support. Rehearse
the actual cable/window from the audience position. Owner may choose notification
quieting, charge/power and screen timeout manually; verify restoration afterwards.
Share only the app/window, close private chats/email, and never expose a credential
or notification while projecting. No notification contents were read here.

## Acceptance checklist

All physical RC1 checks below remain **PENDING**, independent of Task 12C results.

| Physical check | Expected result | Status |
| --- | --- | --- |
| 1. Approved in-place update | Version 1.0.1/code 2, same ID/signer, existing state retained | PENDING approval/execution |
| 2. Startup | No crash/setup screen; saved role or honest entry | PENDING |
| 3. Student | Student Home, clearly fictional | PENDING |
| 4. Alumni | Alumni Home and mentoring/profile actions | PENDING |
| 5. Staff | Staff Home; no administrator equivalence | PENDING |
| 6. Discovery/filters | Search, programme and skill filters, empty result | PENDING |
| 7. Mentors | Explainable deterministic relevance and profile/Back | PENDING |
| 8. Connections | Simulated request/status; no real contact | PENDING |
| 9. Opportunities | Fictional listing/detail; Alumni form where intended | PENDING |
| 10. Profile | Own profile, editing, privacy preferences | PENDING |
| 11. Map boundaries | Repeated east/west swipes at multiple zooms stop at edges | PENDING |
| 12. City markers | Tap visible city marker; correct alumni panel | PENDING |
| 13. Offline persistence | Pre-update records, role and interactions survive restart | PENDING |
| 14. Background/resume | Same expected app state; no crash | PENDING |
| 15. Exit/re-entry | Returns to demo entry; no real logout/email required | PENDING |
| 16. Display/projection | Portrait, keyboard, scrolling, Back, audience readability | PENDING |
| 17. Stability | No observed crash/ANR across rehearsed path | PENDING |
| 18. Hosted isolation | No live Auth, email, backend mutations | PENDING physical walkthrough |

No hosted operation was performed by Task 12D. For the later walkthrough, record
PASS/FAIL, exact candidate/device, tester/date and sanitized evidence; do not fill
these cells from older hardware acceptance or emulator results. Avoid Reset demo
or destructive sample edits on valued state unless separately consented.

## Fresh local checks and completion

**54 focused Flutter tests passed** covering persistence/legacy restore,
corrupt-state fallback, role/profile changes, competition-only callbacks and map
bounds. Log: `build/task12d/compatibility-tests.log`. Task 12C's 212 tests, two
integration journeys, 53 signed screenshots and six edge comparisons are prior
verified evidence, not newly executed physical tests. No app code, dependency,
platform configuration, APK or signing material changed; no full build was needed.

[Private mentor-review preparation](mentor-review-package.md) is ready locally.
No package was sent/uploaded, no mentor contact invented, no push performed.
Read-only preflight **GO**; physical RC1 acceptance and projection acceptance
**PENDING**. Stop here for the owner's specific update decision.
