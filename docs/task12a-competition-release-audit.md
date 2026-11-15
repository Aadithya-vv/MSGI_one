# Task 12A: competition demo freeze and release audit

Reviewed 2026-11-15, starting branch `main`, HEAD
`dbc2d45ab51285ac757f90186c5e4ee94afd1959`.
Application: **MSGI One — One Community. Infinite Connections.**
Institutional context: Meenakshi Sundararajan Engineering College (MSEC).
The owner-provided submission target is November 30, 2026; official organizer
rules/deadline have not been supplied.

**GO for the supervised offline demonstration. NO-GO for formal submission or
broader distribution until official requirements, final materials and signing
recovery/owner approvals are resolved. No public rollout is authorized.**

## Frozen release identity

| Item | Independently observed result |
| --- | --- |
| Protected APK | `build/competition-release/MSGI-One-1.0.0-competition.apk` |
| SHA-256 | `aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809` |
| Historical checksum comparison | Exact match before testing and after debug integration/restoration. |
| Size | 57,966,548 bytes; approximately 55.28 MiB. Organizer size limit unknown. |
| Display name/version | MSGI One / `1.0.0`, version code `1`. |
| Android application ID | `com.msgi.nexus.msgi_nexus`, deliberately retained for identity/update compatibility. |
| Minimum / target API | 24 (Android 7.0) / 36, from APK metadata. Actual minimum-version device testing not performed. |
| Native ABIs | arm64-v8a, armeabi-v7a, x86_64. |
| Signing | One dedicated RSA-3072 competition signer; APK Signature Scheme v2 verifies. |
| Certificate SHA-256 | `857fbe0fc6d3366bb46c59745fce24eb03cef23b78a6b030a24148fb0d995cc4` |
| Structural/install checks | All 376 ZIP entries readable; AOT native app libraries present, no debug kernel blob; APK installs/launches on disposable API 34 emulator. |
| Release flags | Not debuggable; backup disabled; cleartext HTTP disabled. |
| Mode | Offline fictional demo, with an unconfigured separately guarded real-community entry. Not an activated hybrid hosted release. |

The existing release report identifies preparation commit
`93f710a2d694584e58cb583e047ff81dff17eafd`. That is historical provenance evidence,
not proof of a newly reproduced deterministic build. Current HEAD is later than
the APK. Source regression success is therefore reported separately from actual
signed-binary acceptance. No signed build was run or file replaced.

The signing directory was inventoried by filename/length only: competition
PKCS12, DPAPI password file and backup reminder exist outside Git. No private key
or signing password was opened, decrypted or printed. Presence does not prove
current keystore usability or independent recovery. Certificate data above came
from the APK, not private signing material. Owner confirmation of independent
key/password backup and a recovery test remains missing from recorded evidence.

### Freeze tooling correction

The old release wrapper could overwrite its fixed output with Copy-Item.
`Build-CompetitionRelease.ps1` now refuses an existing APK **or checksum before
accessing signing material or invoking Flutter**, and its final file copy is
exclusive (`overwrite=false`). No force/replacement option was added. PowerShell
AST syntax and guard order/copy semantics were checked statically; the signing
wrapper was not executed or used to build. A new version/destination requires
separate approval. This tooling fix needs no APK replacement.

## Dependencies and reproducibility

Current installed tools report Flutter 3.50.0, Dart 3.14.0, framework revision
`ab2912035e`, Android build-tools 36.0.0. Existing Android Studio JBR was selected
for apksigner in that process only; no JDK/tool installation or global environment
change was made. The signature verifier emitted native-access warnings but
verified the APK successfully.

The current lockfile exactly matches the normalized release-era lockfile at the
recorded preparation commit: 119 resolved packages. Full public inventory is
`competition-dependency-inventory.json`. Main external dependencies:

| Dependency | Locked version |
| --- | --- |
| material_ui | 1.11.0 |
| flutter_riverpod | 3.5.0 |
| go_router | 18.1.4 |
| supabase_flutter | 2.18.3 |
| flutter_map | 8.3.2 |
| latlong2 | 0.9.1 |
| url_launcher | 6.3.3 |
| shared_preferences | 2.5.6 |
| app_links | 7.2.2 |

Runtime presentation uses bundled land geometry, local synthetic state, system
fonts/icons and Android plugins. It needs no email provider, map tile service,
hosted catalogs, administrator or Supabase session. The map asset's repository
attribution records Natural Earth public-domain data; credit is visible. Bundled
license notices are present. Formal dependency/IP compliance and competition
disclosure requirements are not claimed completed merely by this inventory.

## Feature truthfulness matrix

| Workflow | Frozen offline release / observed evidence | Separate backend/source status |
| --- | --- | --- |
| Startup, entry, role selection | Clean install/startup, three role choices; no account/internet needed. | Configured real authentication is a separate entry. |
| Student discovery/profile | Name search, fictional profile, programme/skill presentation, filter controls and no-match state. | Programme filter application also exercised by current-source integration. |
| Mentor discovery | Actual deterministic ranking and explanations over local synthetic profiles, availability and connection state. | Authorized server-side matching is separately implemented; not a trained model. |
| Map | Bundled world geography and synthetic city-level clusters/list render offline. No live GPS. | Real map queries require authorized consent-aware backend RPCs. |
| Connections | Simulated request, request persistence across process restart and incoming acceptance verified on signed APK. | Actual networking authorization is separately locally API-tested. No real alumni contacted. |
| Careers/referrals | Fictional jobs/internships/projects; Alumni Create opportunity action revealed by horizontal swipe. | Full creation/draft/type flow executed in current-source integration. Referral availability is an indicator, not a completed real referral/application. |
| Alumni profile | Fictional professional identity and profile navigation; mentoring screen renders. | Source integration exercises mentoring availability and editing. |
| Staff | Home, profile, discovery, mentor and career views; profile explicitly denies administrator equivalence. | Protected administrator operation is local-only and separately gated. |
| Persistence/reset/exit | Role and simulated relationship restore; reset confirmation restores Student; exit/re-entry work. | Source integration also verifies independent preference namespace/sentinel. |
| Real signup/login | Frozen APK reaches a setup-required screen; no hosted configuration is bundled. | Prior hosted auth observations and local recovery tests are historical, not fresh Task 12A results. |
| Institutional administration | Not presented as an activated feature of this APK. | Twelfth migration/executor locally tested, not deployed. |

All people, affiliations, employers and activity shown are fictional. MSEC's
supplied institution/programme names do not verify those identities or establish
college endorsement. No registered-user count, adoption metric or real graduate
claim is made. Messaging, booking, push notifications, CV upload and trained AI
are not demonstrated implemented capabilities.

## Executed acceptance

A new workspace-only AVD, `MSGI_Task12A_Disposable`, device `emulator-5556`, used
the already installed Android 14/API 34 x86_64 image and Pixel 4a profile, 2 cores,
2,048 MB RAM, host GPU and operational WHPX. It has separate new storage under
`build/task12a/avds/`; no existing AVD data was reset. No Samsung command,
installation, uninstall, app reset or data clear was issued.

**Signed binary:** 38 unique screen assertions/captures passed across the base,
interaction and appearance checks. Scope includes all three perspectives,
Student discovery/map/network/profile/mentors/opportunities, Alumni profile/
mentor/publishing action/acceptance, Staff discovery/mentor/opportunities/profile,
Android Back, exit/setup fail-closed path, simulated request persistence, empty
search, reset, native search keyboard, system font_scale 2.0, landscape and OS
night mode. The app intentionally retains its light theme under OS dark mode.
The signed APK was restored after debug integration; appearance settings were
restored. Only this explicitly disposable emulator was uninstalled/reinstalled.

Offline evidence: Wi-Fi `0`, mobile data `0`, airplane mode `enabled`, active
default network `none`. No authentication email/account creation was attempted.
Sampled signed-app process logs showed no crash/ANR, overflow/unhandled exception
or token-pattern match. This is sampled diagnostics, not a lifetime crash proof.

**Current source:** formatter checked 97 files with zero changes; analyzer found
no issues; **197 Flutter tests passed**. One complete Android integration journey
passed (runner also counts teardown), with 17 newly captured screenshots. It
applied a programme filter, edited profile/programme data, searched/viewed alumni,
requested/accepted connections, explored mentor/profile/Back and map navigation,
created a fictional project opportunity, tested Staff restrictions, restored
state, reset and enlarged text. HTTP creation was forbidden and the asserted
attempt count was zero. A real preference namespace/sentinel was preserved.

Integration used `--keep-app-running` and no backend defines on the disposable
AVD. Flutter first rejected the release/debug signature mismatch, then replaced
the disposable installation as permitted. No physical app was involved. Its
debug build succeeded as part of the run; no separate signed/release build ran.
Database/API security tests were not repeated: no schema, authorization or real
backend code changed. Task 11F's 326 pgTAP/46 API results remain historical evidence.

Reproduction after separately booting this named disposable AVD:

```text
node tool/audit_competition_apk.cjs
node tool/audit_competition_demo.cjs
node tool/audit_competition_interactions.cjs
flutter drive --driver=test_driver/demo_driver.dart --target=integration_test/demo_experience_test.dart -d emulator-5556 --no-pub --debug --keep-app-running
node tool/audit_competition_appearance.cjs
```

The signed tools reject other devices/AVDs and accept no device override. Do not
copy the Flutter drive command to a valuable emulator or Samsung. All screenshots
and safe local evidence are inventoried in `competition-release-manifest.json`.
Build logs and binary media stay ignored/local, not uploaded or committed.
Source screenshots were copied byte-for-byte to
`build/task12a/source-integration-screenshots/` so later integration runs using
the shared Task 08 output cannot silently replace this evidence. The disposable
AVD was shut down after all checks; its workspace storage was not deleted.

Harness corrections are disclosed: absent-package `pm path` exit 1 was expected;
Android rejected a legacy airplane broadcast (replaced by supported connectivity
command); XML numeric-newline entities needed decoding; View profile was the
actual card action; Create opportunity required a horizontal chip swipe; and a
broad VALIDATED search matched network *requests*, not an active network. Final
offline verification uses the actual default-network state. These were test/tool
issues, not evidence of broken app workflows. No security setting was weakened.

## UI, accessibility and performance review

Actual captures were inspected for Student home, mentors, map, Staff profile,
keyboard search, enlarged text and landscape. Navy/blue/gold styling is coherent;
normal-size labels, profile hierarchy and disclosures are readable. The header
keeps role/demo context and Back returns from mentors to Home.

At font_scale 2.0 quick-action labels break words awkwardly and the horizontal
row needs scrolling; normal-size filters also hide actions to the right.
Landscape has limited vertical room and needs scrolling. These are P2 candidate
improvements, not silently reported as perfect accessibility. Existing tests
check narrow/enlarged layouts without exceptions, not complete visual conformance.
Standard primary controls use 48-unit minimum targets and labeled navigation;
TalkBack focus/order and every icon/control remain unverified on a screen reader.
The generated launcher icon is retained; no official MSEC artwork was added.

Native search keyboard/focus and Android Back key were tested. All physical
Samsung ergonomics, Samsung keyboard, cutout cases and predictive Back gestures
remain untested in Task 12A. Historical owner acceptance is separate. Any physical
retest needs separate approval and must preserve its installation/data.

Android activity-manager launch samples on the release were 2,325 ms at initial
installation and 1,073 ms after force-stop/relaunch. These are two individual
activity-launch observations, not time-to-interactive, frame/jank measurements
or an SLA. No debug rendering statistics were used as release-performance claims.
Sustained scroll/frame/memory profiling remains pending.

## Security and privacy review

- APK contains no detected private signing/config files, PEM private-key patterns,
  long secret-key prefixes or privileged service-role JWT literals in inspected
  code/assets. The known hosted project literal was absent. Static pattern scans
  cannot prove absence of every obfuscated/runtime secret.
- Manifest requests INTERNET plus an app-private AndroidX signature permission.
  No camera, contacts, location, SMS or storage permission was found. Exported
  launcher/callback is expected; AndroidX profile receiver requires DUMP permission.
- No release debuggable flag, debug kernel or debug localhost security override;
  backup/cleartext disabled. APK v2 signature and installation verify structure.
- Demo repositories are in a parentless Riverpod scope with null Auth/client;
  only explicit real-community choice initializes its separate session. Current
  source rejects foreign callback scheme/host/path/credential/port shapes and
  does not log callback URLs. No live token/link test was performed here.
- Demo preferences contain synthetic state only; do not enter real personal data.
  They are app-private, not independently encrypted. The configured real SDK's
  default session persistence is not a demonstrated Keystore-backed storage
  solution; review sensitive-session storage before a public real-account release.
- No app print/debugPrint call was found in reviewed lib source. Sampled logs
  showed no token markers; no packet capture/full forensic log audit was performed.
- No hosted Supabase operation, RLS/verification change, real account invitation,
  SMTP activation or signing-identity change was performed by Task 12A.

## Submission, demonstration and handover

Created: `competition-demo-script.md` (90-second, 3-minute, 5-minute, offline
fallback and judge Q&A), `competition-submission-checklist.md` (all organizer
requirements explicitly UNVERIFIED, twelve-section content outline and inventory),
and `college-handover-inventory.md` (architecture diagram, ownership and approvals).
No full deck, formal organizer-template report or video was generated. Team,
mentor, portal, formats, IP/AI disclosure and submission consent remain to confirm.
No project or source code was submitted, uploaded, published or pushed.

## Release risk register

| Priority / ID | Finding and evidence | Impact / resolution | Existing APK affected? / new APK? |
| --- | --- | --- | --- |
| P0 | None observed within the executed offline scope. | Not a claim of production security or exhaustive device coverage. | No known P0. |
| P1-R1 | Official competition rules/portal/deliverables absent from repository search. | Formal submission gate: obtain organizer/faculty confirmation, then finalize report/deck/video/team details. | Suitability unverified; new APK only if confirmed rules require capabilities this offline build lacks. |
| P1-R2 | Independent signing key/password recovery not evidenced; local presence only. | Distribution/update custody gate: owner verifies approved backup/recovery privately. Never regenerate the signing identity as a workaround. | Current APK works; no new APK needed to resolve custody. |
| P1-R3 resolved locally | Build wrapper could overwrite the protected artifact. | Added pre-signing freeze refusal and exclusive copy; static guard/syntax checks pass. | Existing APK unchanged; no new APK required. |
| P2-R4 | Horizontal actions and enlarged quick-action word breaks; captured at system font_scale 2.0. | Rehearse chip swipe, use readable portrait settings; improve layout only in a separately approved candidate release. | Yes; new APK for UI improvements. |
| P2-R5 | TalkBack/predictive gestures, older API hardware, projection and sustained release profiling unverified. | Complete a non-destructive acceptance plan; no Samsung action without separate approval. | Coverage gap; new APK only if a confirmed defect needs fixing. |
| P2-R6 | Setup-required screen exposes development wording; retained generated launcher icon. | Keep real sign-in out of demo; any consumer-copy/artwork update requires a separately reviewed release and approved branding. | Yes; new APK for changes. |
| P2-R7 | Report/deck/video/official details not final. | Prepared script/outline/checklist; finish to confirmed rules before owner-approved submission. | No APK change necessarily. |
| P3-R8 | Hosted admin/email, current backup, DPAPI portability, privacy/staffing/custody and session-storage decisions pending. | Separate controlled operational approvals; public launch remains NO-GO. | Offline demo unaffected; future real release/deployment needs review. |
| P3-R9 | Local 5,000-entry admin queues cost about 2.4 seconds/page in Task 11F. | Optimize/benchmark before a large pilot; no capacity/adoption claim. | Offline demo unaffected; future backend change separately reviewed. |

## Completion boundary

Protected APK and signing files were not modified. No hosted changes, Samsung
actions, valuable database resets or push occurred. Unrelated untracked Task 11B
reports were preserved/excluded. Only safe documents/audit tooling and the freeze
guard are checkpointed. Any new signed build, public rollout, official submission
or hosted operation requires separate owner authorization.

**Competition release recommendation: GO for the frozen, honestly labelled
offline demonstration; NO-GO for formal submission/distribution until the P1
confirmation/custody gates and final owner review are complete.**
