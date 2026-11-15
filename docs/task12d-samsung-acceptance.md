# Task 12D Phase 5: Samsung RC1 update and acceptance

Acceptance resumed November 16, 2026 (Asia/Calcutta). Starting checkpoint:
`014fd27bc5a2ae6aa9dae06376a90a031c0adcc0`.
The owner explicitly authorized one in-place update and non-destructive UI tests,
accepting the documented residual state-preservation risk. That single-use
installation authorization is **consumed**; it does not authorize another attempt.

## Preflight and exact installation outcome

| Gate / result | Observed evidence |
| --- | --- |
| Device | Authorized Samsung SM-M215G, serial `RZ8RA1DN4YA` |
| OS | Android 13 / API 33 |
| Installed before | `com.msgi.nexus.msgi_nexus`, 1.0.0 / code 1 |
| Old installed binary | Exact protected v1.0.0 SHA-256 match |
| Available `/data` | 4,269,812 KiB at preflight; exceeded conservative 512 MiB staging floor |
| Candidate | Exact approved path, 1.0.1 / code 2; minimum API 24 |
| Signatures | Both local APKs freshly verified using v2; same approved certificate |
| Installation attempts | **Exactly 1**, no retry |
| Installer result | **Success**, exit code **0** |
| Installed after | **1.0.1 / code 2**, same package, exact candidate hash |
| Installation continuity | Original first-install timestamp unchanged |

Executed once:

```text
adb -s RZ8RA1DN4YA install -r "D:\MSGI_nexus\build\competition-release-candidate\MSGI-One-1.0.1-rc1.apk"
```

Candidate SHA-256:
`3b8d41351b554e3603c9e0d747357a359b3ec1651d4431e7e9643534ab9bc2e7`.

Protected fallback SHA-256:
`aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.

Both certificate SHA-256 fingerprints:
`857fbe0fc6d3366bb46c59745fce24eb03cef23b78a6b030a24148fb0d995cc4`.

An exclusive local attempt reservation was created before invoking the installer.
Post-install inspection independently rehashed the installed APK. No rebuild,
re-sign, downgrade, uninstall, data clear/reset, backup/restore or second install
occurred. Only this application was targeted by installation commands; unrelated
application/background OS activity was not audited. No signing credential was
opened or changed.

## Actual physical tests

These are ADB-driven taps/swipes on the physical Samsung, not emulator results.
No new accounts, profile saves, connection sends/acceptances, mentoring changes,
opportunity saves, reset or logout were used to simplify testing.

| Check | Result and limits |
| --- | --- |
| Startup | PASS: launched installed RC1, restoring Staff / Faculty Home; no migration/setup error |
| Splash / welcome | Transient splash not separately captured; welcome intentionally not forced by exiting existing demo |
| Student | PASS: Home, discovery/filter panel, fictional profile, mentor/profile/Back, network, careers and own profile |
| Alumni | PASS: Home, profile, network, mentor and career screens |
| Staff | PASS: Home, discovery, mentor, career and profile/network views; restored original perspective |
| Navigation | PASS on exercised touch and Android Back paths |
| Profile / connection edits | NOT TESTED: avoided changing valued saved state |
| Background/resume | PASS: Android Home then app resume returned to Staff Home, without force-stop |
| Map | PASS: six stationary edge comparisons over three zoom levels, vertical movement and city-marker panel |
| Programme filter | PASS: Cybersecurity choice applied, expected fictional profile shown, filter cleared and directory restored |
| Stability | PASS within sampled scope: no crash/ANR, rendering/unhandled-error or token/secret pattern detected in app-process logs |

The first launch produced one activity-manager sample of 1,231 ms TotalTime. It
is not time-to-interactive, a sustained frame/jank measurement or an SLA. The
later launch resumed an existing activity. Human-perceived latency, TalkBack,
predictive Back, enlarged system fonts and landscape were not freshly tested.

An interrupted session left the app UI unavailable during the first resumed map
check. The harness stopped before map interaction. The owner then unlocked/opened
MSGI One manually and testing resumed. No keyguard bypass or additional install
was attempted. ADB authorization alone was not treated as an unlocked app screen.

## Data-preservation evidence

**Partial verification only; no complete preservation claim.**

- The installed binary changed in-place from the approved code 1 APK to approved
  code 2; first-install timestamp remained unchanged.
- Startup immediately restored the non-default **Staff / Faculty** perspective
  and active demo, rather than a new empty entry/Student fixture. Existing role
  state therefore remained accessible.
- Visible Staff profile and network labels were fingerprinted immediately after
  the update and again after the role walkthrough; both matched. The original
  Staff perspective was restored. This supports non-mutation **during testing**.
- No preinstallation private-content snapshot was taken. Exact preservation of
  every prior profile field, connection, goal, setting or cache is not observable
  from the available before/after evidence. They were not exported or reconstructed.
- No data loss was observed, but hidden/corrupt/inaccessible state cannot be
  excluded. Existing storage fallbacks and absence of verified state backup remain
  documented in [the readiness assessment](task12d-physical-device-readiness.md).

## Map evidence and screenshots

Physical captures remain local/ignored in `build/task12d-samsung/`. They contain
app-only demonstration evidence plus ordinary system chrome; they were not sent,
uploaded or committed. No unrelated app was opened for inspection. Public Git
evidence is limited to safe aggregate results and file hashes.

Key captures include `00-post-update-startup.png`, the Student/Alumni/Staff
walkthrough, opposing `map-*-east/west` images, repeated-edge comparisons and the
city-marker panel. The app's initial map and portrait Home were visually reviewed.
There are **45 physical-device screenshots**. Public filename/hash inventory:
`docs/task12d-samsung-evidence.json`. No raw images or private UI contents are
committed. The comparison crop is `(20,950,1040,600)` on the verified 1080×2340
captures, excluding status/header, zoom buttons and city sheet. At each of three
successive zoom levels, extra eastward/westward swipes left map pixels exactly
unchanged at the respective edge: **six comparisons passed**. Initial and edge
captures show a single world, with no repeated continents or endless panning.

At a zoomed-in view, a vertical swipe changed map-region pixels; zoom buttons
continued to work. Filtering to London exposed an individually identifiable
painted marker; tapping it opened the London alumni panel. The temporary search
was removed and World view restored before returning to Staff Home. The inherited
outer-marker semantics bounds are still a separate accessibility review issue;
the test targeted the painted button, not the oversized semantic region.

The programme filter selected the existing MSEC Cybersecurity programme, showed
the expected fictional result, then cleared the temporary filter. The visible
directory fingerprint matched its pre-filter state. Final profile/network
fingerprints again matched their initial post-update values after all tests.
The app was left on **Staff / Faculty Home**. No new connection, profile, saved
opportunity or mentoring value was written. Role switching was exercised and the
original role restored; this is not a claim that every internal write was absent.

## Presentation and remaining limits

Portrait titles, profile hierarchy, marker counts and navigation were readable
in reviewed physical captures. Existing horizontally scrollable quick actions can
clip the next action at the right edge; this is a known presentation limitation,
not proof of a RenderFlex overflow. Floating translucent device controls were
visible and left unchanged; their origin was not established and no accessibility
or display setting was altered to remove them.

No mirroring software was installed or activated. Actual projection, audience
viewing distance, external notification interruptions and human touch ergonomics
remain pending. Screenshot/window-sharing preparation is in
[the private mentor package](mentor-review-package.md). Do not represent these
captures as successful projector or screen-reader acceptance.

Phone Wi-Fi/mobile/display/security preferences were not changed. This is the
verified offline-only candidate with no real Auth entry or backend configuration;
no hosted mutation/email/SMTP/admin operation was invoked. Airplane-mode physical
operation and packet-level network absence were not freshly tested. Task 12C's
offline emulator evidence remains separate. Unapproved MSEC media remains absent.

No app code was modified, and neither signed APK was replaced. Earlier 212-test,
two-journey emulator and 54-test compatibility results are historical evidence;
no fresh Flutter build or software installation is claimed beyond the one update.

## Final status

Both local APKs and the installed candidate still match their approved hashes.
No new app defect requiring a rebuild was confirmed. All exercised core offline
UI paths passed, with the data-preservation and coverage limits above. No new
mirroring tool, phone setting or real-account action was introduced. Safe
documentation/evidence only is checkpointed; unrelated untracked files remain.

**PHYSICAL-DEVICE ACCEPTANCE: PARTIAL** overall: the core physical walkthrough,
map and in-place update passed, but complete pre-update data preservation cannot
be proved; splash/welcome was not forced by exiting existing state; actual
projection, human ergonomics and accessibility coverage remain pending. No data
loss was observed and no reset was used to reconstruct state.

**DISTRIBUTION: NOT AUTHORIZED.** Retain both signed artifacts and seek separate
owner distribution approval after the remaining review gates. The one-install
authorization must not be reused.
