# Task 12B: branding preparation and bounded map

Starting commit: `2036bb2c1289e64f7bf32c0d7270954780ef60f2`.

## Media approval boundary

The owner clarified that redistribution permission is **not confirmed** for the
three official candidates. Authorizer and role remain unknown. Original files
were acquired for local inspection only, under ignored
`build/task12b/reference-review/`; neither those files nor their review thumbnail
are bundled or committed. No distribution variants or pubspec entries were made.

See [media provenance and approval inventory](msec-media-approval.md) for exact
URLs, dimensions, hashes and proposed placements. The official
[homepage](https://msec.edu.in/) identifies the crest; the
[gallery](https://msec.edu.in/gallery.html) supplies campus.jpeg and infra2.JPG.
The latter depicts a sports field, not an entrance. Website provenance and its
copyright notice do not establish permission to redistribute.

The shared MSEC identity component uses factual institution text and explicitly
labelled generic image placeholders. It appears on welcome/loading, demo Home,
demo own profile and the real own profile only for MSEC affiliation. The campus
placement is proposed on welcome; compact crest placements are reserved on the
other cards. No invented crest, generated campus photograph or altered official
logo is used. MSGI One's existing mark, name and tagline remain intact.

## Map root cause and correction

flutter_map 8.3.2's default Epsg3857 wraps longitude and replicates worlds. The
previous unconstrained camera and zoom floor of zero allowed repeated continents
and indefinite horizontal travel. Polygon drawInSingleWorld alone does not stop
CRS replication.

`SingleWorldMercator` delegates public projection APIs to Epsg3857 while omitting
longitude wrapping. `SingleWorldCameraConstraint` contains the projected viewport
within one world, with a viewport-dependent minimum zoom. A one-pixel interior
margin handles the package's floored projected centers on fractional Android
logical sizes. Near-identical projected centers return the existing camera to
avoid floating-point update jitter. Zoomed vertical movement remains available.
Map-ready and viewport-resize callbacks enforce the bounds; polygons draw in one
world and optional licensed tiles use finite bounds. Marker grouping normalizes
equivalent longitudes, keeps opposite dateline edges separate and ignores invalid
coordinates. City locations and authorization rules are unchanged.

The map reserves space below its search header, keeping city markers reachable.
This corrected a confirmed London-marker obstruction. The former fixed map-height
test now checks meaningful viewport coverage and separation from search controls.

## Verification

| Check | Actual result |
| --- | --- |
| Dart formatting | 104 files checked; formatted |
| Flutter analyzer | No issues |
| Flutter unit/widget tests | 211 passed |
| Android integration | Two journeys passed, plus teardown |
| Integration screenshots | 21 captured |
| Debug APK | Build succeeded; assembleDebug 28.4 seconds |
| APK media inventory | 552 ZIP entries; none of the three unapproved media files |

The two native journeys cover the existing three-role offline flow and targeted
map edge clamps, extreme pans, zoom, vertical movement and city interaction.
They ran on the explicitly disposable API 34 AVD `MSGI_Task12A_Disposable`,
`emulator-5556`, not Samsung or another development AVD. Offline HTTP rejection
remained enabled. The separate ordinary debug APK also underwent an offline ADB
walkthrough with Student, Alumni and Staff perspectives.

During validation, a real-asset fake-async widget fixture stalled and was replaced
with a deterministic test polygon; native tests use the actual bundled map.
The native screenshot conversion must run in each test. Native fractional-size
testing exposed polar overshoot, corrected with the pixel margin and new unit
cases. An initial guest System UI cold-boot wait dialog was dismissed with Wait;
it is not reported as an application ANR or a release performance measurement.

## Evidence and artifacts

- Before: `build/task12b/before/` (8 PNGs, original frozen release).
- After: `build/task12b/after/` (10 PNGs, separate debug candidate).
- Native journeys: `build/task12b/integration-screenshots/` (21 PNGs).
- Logs: `build/task12b/analyze.log`, `flutter-tests.log`, `integration.log`,
  `debug-build.log`; integration-summary.json records completion.
- Reviewed screenshots include welcome, map minimum and east edge; minimum view
  shows one world rather than the original repeated continents.
- Debug candidate: `build/task12b/MSGI-One-task12b-debug.apk`.
  SHA-256: `374df651ae2854e105fa05f06ed8cc2ebbab04ad97cf0abb1c107c63ae693d54`.
- Protected competition APK SHA-256 remains
  `aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.

All 56 files pinned by the Task 12A release manifest were rehashed and matched.
`task12b-review-manifest.json` records the 39 new screenshot hashes. The final
capture helper waits for role/profile transitions before screenshots; an early
role-choice transition capture was replaced with the settled student Home.
The owned disposable emulator was shut down after verification; its storage was
not deleted.

The screenshot helper verifies the disposable AVD name and installed APK identity.
Its uninstall/install operations target that disposable AVD exclusively. No
physical-device installation, signing change, hosted operation, email, database
reset or dependency upgrade was performed. Database/API security suites were not
rerun because this change does not alter their contracts; no new hosted acceptance
is claimed. Existing unrelated untracked reports are preserved.

## Remaining acceptance

The map and placeholder candidate are ready for local QA. Actual campus image and
official crest display, optimization and offline-image acceptance remain pending
media permission. Obtain approval identifying exact assets, authorized role,
offline APK/Git redistribution scope and permitted transformations/attribution.
Do not represent this candidate as completion of official-media integration.
Keep the existing signed competition APK frozen. Recommend a separate signed
release only after permission, final media acceptance and explicit owner approval;
no replacement release was signed or distributed here.
