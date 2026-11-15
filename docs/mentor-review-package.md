# MSGI One: private mentor review preparation

Prepared November 15, 2026. **Local preparation only: not sent, uploaded,
published, submitted or approved for distribution.** Mentor name/contact and
review appointment are not supplied. Presenter contact: **[owner to provide]**.

## Build under review

- App: **MSGI One — One Community. Infinite Connections.**
- Candidate: **1.0.1 RC1**, Android version name `1.0.1`, code `2`.
- Local APK: `D:\MSGI_nexus\build\competition-release-candidate\MSGI-One-1.0.1-rc1.apk`.
- SHA-256: `3b8d41351b554e3603c9e0d747357a359b3ec1651d4431e7e9643534ab9bc2e7`.
- Application ID: `com.msgi.nexus.msgi_nexus`.
- Certificate SHA-256:
  `857fbe0fc6d3366bb46c59745fce24eb03cef23b78a6b030a24148fb0d995cc4`.
- Minimum Android **7.0/API 24**; packaged ARM64, ARM32 and x86_64 libraries.
  Minimum-API hardware coverage is not established. Candidate was actually
  exercised on Android 14/API 34 emulator; RC1 Samsung Android 13 acceptance is
  still pending. A supported OS number is not a guarantee for every device.

## Scope to explain before review

This is an **offline competition demonstration**, not public real-user signup.
All displayed people, employers, affiliations, opportunities and interactions are
fictional. MSEC programme names provide institutional context; fictional people
are not represented as actual graduates. Official campus photos/crest are absent
because redistribution permission is not confirmed. Staff is a community
perspective, not administrator access. No accounts, passwords or email requests
are required. Do not enter real personal information into the demo.

Mentor recommendations use deterministic, explainable weighted relevance, not a
trained AI model or a probability of success. Connections and career actions are
local simulations; they do not contact alumni, submit job applications or send
notifications. No chat, appointment booking or public backend rollout is claimed.

## Installation guidance — approval required

Do not install this APK on the currently connected Samsung under Task 12D.
[The device-readiness report](task12d-physical-device-readiness.md) contains the
exact proposed `adb -s RZ8RA1DN4YA install -r` operation and data risks for owner
approval. The phone currently has the exact protected v1.0.0 APK, with a matching
signer; code 2 appears eligible for an in-place update. Do not uninstall, clear
data, grant extra permissions or attempt a downgrade to resolve any rejection.

After separate consent, an authorized operator should verify the APK hash, device,
installed package/signer/version, state-preservation needs and available space
before the approved update. Stop if any differs from the plan. No supported
private-state export/backup has been verified; same-package updating normally
retains the data directory but **preservation has not been tested on this phone**.
The original APK does not back up saved demo state. Do not promise rollback.

Installation, launching, screen sharing and any reset/data-changing walkthrough
must stay within the next approval's scope. No request to disable Play Protect,
Windows security or device security is part of this package. Do not install
software or broadly enable unknown-source installation to facilitate a review.

## Suggested five-minute private walkthrough

| Sequence | Presenter action after appropriate approval | Expected result |
| --- | --- | --- |
| 1 | Explain fictional/offline scope, then Explore Demo | Three role choices; no login/email |
| 2 | Student → Home → Discovery | Student context, search and programme filters |
| 3 | Open fictional alumnus, then Back | Professional identity, skills and education; predictable return |
| 4 | Home → Find a mentor → Why this mentor/profile | Evidence-based relevance and availability; no AI-confidence claim |
| 5 | Map → zoom and repeated east/west pans → marker | One finite world, bounded camera, city-level fictional alumni |
| 6 | Connections and Opportunities | Simulated statuses and career listings; no real messages/applications |
| 7 | Home role menu → Alumni → Profile/mentoring | Alumni perspective and availability; any edits require state-owner consent |
| 8 | Home role menu → Staff / Faculty → Profile | Institutional community perspective, not administration |
| 9 | With approval, background/reopen; then Demo controls → Exit demo | Saved role/interactions restore; explicit re-entry, not real-account logout |

Keep existing demo state. Do not use Reset demo merely to make a review match a
script. Demonstrate connection/request/edit actions only with the state owner's
consent; they persist locally. If creation takes too long, show the form and exit
without saving. On careers/filters, swipe horizontal chips to reveal more actions.

The existing [demo script](competition-demo-script.md) has extended narration/Q&A
written for v1.0.0. For RC1, use the version/hash above and offline-only entry;
do not follow its old instruction to choose a real sign-in path.

## Laptop/projector review

Available recorded evidence: `build/task12c/signed-apk/` (53 actual signed-RC1
emulator captures). Useful images include `00-entry-offline.png`,
`02-student-home.png`, `03-student-discovery.png`, `07-student-mentors.png`,
`04-student-map.png`, `10-alumni-home.png` and `12-staff-home.png`.
Verify against `docs/task12c-release-manifest.json`; keep images local.

Show portrait images at their correct aspect ratio in an existing viewer and
share only its window with an approved presentation tool. Enlarge profile/mentor
text for the audience; avoid shrinking the phone to a narrow strip on a large
landscape slide. Clearly identify screenshots as recorded emulator evidence.
Screenshots do not prove touch response, physical update or live connectivity.

Actual projector, cable, mirroring support and room readability remain pending.
`scrcpy` is not on the inspected PATH; none was installed. Do not assume this
Samsung supports wired video or any specific phone-mirroring product. Prepare an
already approved emulator/screenshot fallback rather than making untested hardware
promises. Any future notification quieting/display changes are owner-controlled;
hide private notifications and share the minimum window. No setting changed here.

## Evidence and limits

- Fresh Task 12D: APK/signature/manifest verification, read-only Samsung metadata/
  installed-APK identity, unchanged persistence contracts, **54 focused tests**.
- Prior Task 12C: analyzer clean, **212 Flutter tests**, two Android source
  integration journeys, ordinary signed candidate walkthrough, six map-edge pixel
  comparisons. These are not new Samsung results.
- Pending: RC1 in-place update/data retention, physical touch/keyboard/Back,
  TalkBack, Samsung projection, actual room readability and sustained performance.
- Known polish limits: horizontally scrollable controls, enlarged-label wrapping,
  and map semantics requiring further accessibility review. Some secondary text
  is too small for a room when the entire portrait image is reduced.
- Real-user launch, SMTP, administrator provisioning, institutional permissions,
  independent signing recovery and competition organizer/faculty requirements are
  separate gates. Owner-provided target: November 30, 2026; official rules are not
  established by this package.

## Mentor feedback form — unfilled

- Reviewer/role (with consent): **[to provide]**
- Review date/build/device/projection method: **[to record]**
- Is the problem and student/alumni/staff value understandable? **[feedback]**
- Are fictional-data and offline limitations clear? **[feedback]**
- Are programme terminology and institutional wording appropriate? **[feedback]**
- Are mentor explanations useful and accurately described? **[feedback]**
- Are discovery, map, connections and careers understandable? **[feedback]**
- Which labels/navigation/contrast details are difficult at presentation distance?
  **[feedback]**
- Any crash, blocked action, hidden keyboard field or data-retention concern?
  **[sanitized reproduction; no credentials or personal records]**
- Priority: **[blocking / important / optional]**; owner/action: **[to agree]**
- Faculty/organizer requirements still needed: **[to confirm]**
- Recommendation/sign-off: **[not yet obtained]**

Do not collect passwords, tokens or real alumni records as review feedback. No
mentor endorsement, delivery, institutional approval or submission is implied.
