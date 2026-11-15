# Competition submission checklist

Task 12A preparation, 2026-11-15. **Nothing has been submitted, uploaded or
published.** This is an internal preparation list, not invented organizer rules.

## What is known

- Project: MSGI One; tagline: One Community. Infinite Connections.
- Institution context: Meenakshi Sundararajan Engineering College (MSEC).
- Owner-provided target date: **November 30, 2026**. It is documented in
  `requirements.md`; an official organizer deadline/timezone is not supplied.
- The repository contains no identified official competition rulebook, organizer
  name, submission portal or official required-deliverables list. Historical
  project requirements are development plans, not competition regulations.

## Organizer/faculty confirmation required

| Requirement | Status / action |
| --- | --- |
| Competition name, organizer and category | UNVERIFIED; obtain official notice. |
| Final deadline, time, timezone and extension policy | UNVERIFIED; confirm the owner-provided November 30 target. |
| APK versus hosted app/live demo requirement | UNVERIFIED; disclose that the frozen APK is an offline fictional demonstration. |
| Report format, template, page/word limits | UNVERIFIED. |
| Slide deck format, slide limit and speaking/Q&A time | UNVERIFIED; no complete deck generated. |
| Screenshot quantity, dimensions and branding rules | UNVERIFIED; select actual captures after confirmation. |
| Video duration, format, resolution and narration rules | UNVERIFIED; video not created. |
| Team size, names, identifiers and consent | UNVERIFIED; obtain approved real details privately. Fictional demo names are not team members. |
| Faculty mentor identity/sign-off | UNVERIFIED; obtain actual consented details and approval. |
| Source-code/archive/repository access requirement | UNVERIFIED; do not disclose or push source without owner approval. |
| Portal URL, entry owner/account and upload permissions | UNVERIFIED; no portal interaction authorized. |
| File size, naming and compression rules | UNVERIFIED; APK is 57,966,548 bytes (about 55.28 MiB). |
| IP/ownership, third-party licenses and AI-use disclosure | UNVERIFIED; confirm college and organizer terms. No transfer/license acceptance is implied. |
| MSEC name/artwork/endorsement permissions | UNVERIFIED for official branding approval; no official logo or endorsement claimed. |
| Consent/privacy requirements for demonstration media | UNVERIFIED; use synthetic personas only. |

Record the official source/date and faculty confirmation for each row before
formal submission. Do not guess a portal from an unrelated competition.

## Internal file inventory (proposed, not organizer-mandated)

| Material | Location / readiness |
| --- | --- |
| Frozen signed offline APK | `build/competition-release/MSGI-One-1.0.0-competition.apk`; checksum in Task 12A audit. Do not overwrite. |
| Release audit and risk register | `docs/task12a-competition-release-audit.md`. |
| 90-second / 3-minute / 5-minute scripts and Q&A | `docs/competition-demo-script.md`. |
| Signed-APK screenshots and safe acceptance evidence | `build/task12a/signed-apk/`; real captures, fictional people. Local/ignored, not uploaded. |
| Source integration screenshots/results | Frozen copies in `build/task12a/source-integration-screenshots/` and Task 12A integration log; clearly separate debug/current-source evidence from signed release. |
| Architecture/security material | `docs/architecture.md`, `docs/security-model.md`, handover inventory. Historical sections require date/context when quoted. |
| Database and deployment evidence | Task 11E/11F reviews, migration history, local pgTAP/API evidence. Never package encrypted backups, secrets or private accounts. |
| Public dependency inventory | `build/task12a/dependencies.json`; lockfile retained, bundled license notices present. Formal licensing review remains pending. |
| Formal project report | Content outline below; organizer template/team details pending. |
| Complete presentation deck | Not produced; rules/faculty scope pending. |
| Narrated demo video | Not produced; duration/format and recording consent pending. |
| Team/mentor declarations and institutional acceptance | Missing approved details/sign-off. |
| Official submission receipt | Not applicable; no submission performed. |

## Twelve-section report/presentation content outline

| Section | Prepared content and evidence |
| --- | --- |
| Introduction | MSGI One connects students, alumni and staff; state offline demo scope first. |
| Problem | Discoverability, mentorship access and fragmented institutional networking; do not invent survey statistics. |
| Target users | Students seeking direction, alumni sharing experience, staff supporting the community. |
| Solution architecture | Flutter/Riverpod/GoRouter; isolated local demo; separately guarded Supabase Auth/PostgreSQL/RLS path. Diagram in handover inventory. |
| Feature walkthrough | Discovery, programme filters, profiles, explainable mentors, city map, connections and Career Bridge. Use actual captured screens. |
| Differentiators | Three perspectives, explainable relevance, offline presentation reliability, privacy-aware architecture. No trained-AI or adoption claims. |
| Technology stack | Installed SDK and actual locked versions from dependency inventory, not only pubspec version ranges. |
| Database/security | Protected membership/roles, narrow RPCs/RLS; eleven hosted development migrations and pending local admin migration. |
| Testing | Fresh Task 12A source and signed-APK checks; distinguish older local database/API evidence. |
| Scale/operations | Known admin queue cost, pagination limits, staffing, monitoring and backup/restore requirements. |
| Limits/rollout | Email/domain, current backup, admin deployment/approval, privacy and college custody gates. |
| Conclusion | Controlled college-owned pilot is the next stage; repeat the tagline without claiming production launch. |

## Final owner release checklist

- [ ] Confirm official rules and permitted offline-demo scope.
- [ ] Approve team/mentor details, institutional wording and AI/IP disclosures.
- [ ] Confirm independent recoverable signing-key/password custody privately.
- [ ] Rehearse on the already approved presentation device and projection setup.
- [ ] Select screenshots; create report/deck/video only to confirmed requirements.
- [ ] Verify the frozen APK SHA-256 again immediately before sharing.
- [ ] Review every package entry: exclude signing files, credentials, local config,
      backups, database exports, personal records, raw logs and unrelated files.
- [ ] Obtain explicit owner approval for final files, destination and submission.
- [ ] Submit only through the confirmed organizer channel; retain a safe receipt.

Suggested internal sequence: resolve rules/signing custody first, rehearse the
frozen experience next, then finalize media and faculty sign-off before the
November 30 target. This is planning guidance, not a fabricated organizer schedule.
