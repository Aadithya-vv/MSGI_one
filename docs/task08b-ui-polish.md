# Task 08B UI audit and implementation

Baseline: e9cf649a51e075172a31eaa892c5904d036c7618.

## Prioritized audit

1. Discovery: inline catalog controls pushed results below several screens.
   Mentor cards repeated explanations and status; career status/sort controls
   competed with results. Prioritize progressive disclosure and readable cards.
2. Dashboards: production still used legacy sample previews. Replace highlights
   with injected repositories, keep demo counts explicitly fictional and derive
   them from the packaged store, and share responsive quick links.
3. Visual consistency: unify typography, outlines, chips, buttons and notices;
   improve avatar hierarchy, narrow-phone gutters and card spacing.
4. Entry/forms: make perspectives descriptive, expose account creation explicitly,
   keep real verification separate, improve password visibility and validation.
5. Map/network/profile: improve controls, city-list accessibility, person identity,
   privacy readability and profile navigation while preserving authorized fields.
6. Validate full route matrix, large text, keyboard insets, long labels and actual
   offline emulator journeys. Correct defects before checkpoint.

## Screen review and changes

- Startup/splash and welcome: retained navy/gold brand and existing auth routing;
  shared typography/button styling applies. Entry adds clear account creation and
  descriptive Student/Alumni/Staff cards without self-provisioning privileges.
- Login/signup/recovery: consistent outlined fields and accessible password
  visibility toggle; submission, confirmation and recovery behavior unchanged.
- Demo and real home: responsive quick links plus repository-backed mentor and
  recent career highlights with explicit empty/error/retry states. Demo statistics
  are derived from its fictional store. No fabricated real counts.
- Discovery: keyboard-aware scrollable filter sheet, dependent catalogs, active
  indicators, validation before dismissal, cancel restores original filters,
  loaded-result count, initials avatars, education/batch and selected skills.
- Mentors: compact identity/availability/relevance summary, real shared skills,
  expandable detailed reasons and matching explanation, collapsed refinement
  controls. Points are relevance, never probability. Connection actions retained.
- Global map: secondary domain filter collapsed, responsive map height, existing
  grouping/privacy/attribution intact, labeled controls and accessible city list.
- Network: consistent avatars and spaced cards, existing request actions intact.
- Career Bridge: visible category controls, collapsed author/status/sort controls,
  clearer category/status labels, readable organization/location hierarchy and
  explicit simulated-copy variant injected only at demo composition.
- Career detail/editor: shared form theme, skill tags, unchanged ownership/status,
  URL validation, external confirmation and draft/publish mechanisms.
- Profiles/privacy: recognizable avatar, readable skills; no private fields added.

## Architecture and accessibility

No new packages, dependency upgrades, hosted operations, migrations or Android
configuration changes. Demo still uses its parentless scope and null Auth/client.
Real repositories and guards remain authoritative. Home highlights fetch bounded
existing RPC pages and display only a small subset; no full directory download.

PageBody supplies a transparent Material surface inside navigator transitions,
preventing material_ui ListTile ink from being hidden by transition backgrounds.
Fields keep errors/helper text wrapping. Sheets account for keyboard insets and
safe areas; scrolling dismisses the keyboard. Initials are decorative, not duplicate
screen-reader names. Notices are live regions and use a short fade disabled by
reduced-motion settings. Standard Material interaction feedback is preserved.

## Validation

See verification.md for final executed counts and emulator results. Database tests
are unnecessary for these presentation-only changes and are not rerun. Hosted
catalog approval, pending migrations and real release acceptance remain separate.

Final automated results: analyzer clean; 151 Flutter tests passed. Offline native
multi-role integration passed, with 16 screenshots including 200% text. Normal
unconfigured debug APK built successfully. No major overflow in inspected views.
At enlarged text the header wraps and long forms require more scrolling. Manual
TalkBack, real hardware/IME and hosted acceptance remain final-release checks.

Before submission: rehearse the three-perspective script and reset procedure;
prepare an approved signed build, capture final presentation media, and perform
physical-device/accessibility acceptance. Hosted deployment/catalog/admin work
requires its existing separate approvals and is not a prerequisite for offline demo.
