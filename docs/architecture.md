# Architecture â€” Task 04A

MSGI One is an Android-first, feature-first Flutter application with a prepared
Supabase authentication adapter and membership guards. Profiles and discovery
now use live repositories with a locally tested migration awaiting hosted
approval. Missing configuration shows setup, never a demo login bypass. Other
community features retain clearly labelled sample content.

## Composition and ownership

`main.dart` validates public build configuration, initializes Supabase only when
valid values are deliberately supplied, and injects bootstrap results into
Riverpod. `app.dart` composes the existing Material 3 theme, auth lifecycle
observer and provider-owned GoRouter. No privileged key is accepted or logged.

| Module | Responsibility |
| --- | --- |
| core/config | Branding and validated HTTPS/public-key build configuration |
| core/routing | Paths, provider-owned router, pure access redirect rules |
| core/theme | Existing navy/blue/gold Material 3 theme and spacing |
| core/widgets / core/errors | Existing shell, cards, loading/empty/safe errors |
| features/auth/domain | Repository contract, identity/membership/access states, onboarding data and validation |
| features/auth/data | Supabase adapter, safe error mapping, own membership RPC and catalog/onboarding calls |
| features/auth/application | Riverpod injection and race-safe session/membership state machine |
| features/auth/presentation | Startup/welcome, login/signup/recovery, onboarding, setup and membership states |
| features/home | Original dashboard and feature entry points |
| features/discovery | Authorized server-filtered directory, cursor pagination and safe details |
| features/alumni_map | Consent-safe geographic map with offline land and authorized city aggregates |
| features/connections | Authorized incoming/outgoing/accepted connections and profile actions |
| features/profile | Own professional profile, private drafts, privacy settings and repositories |
| features/catalog | Paginated authenticated reference catalog search |
| features/mentorship | Private goals, server-ranked explainable mentors and existing connection actions |
| features/opportunities | Scoped Career Bridge discovery, versioned publishing/drafts, archival and reports |
| supabase/migrations | Schema, constraints, grants/RLS and checked server workflows |
| supabase/tests/database | Transactional pgTAP role/RLS/RPC tests verified locally |

Domain models do not import Flutter widgets. The Supabase adapter implements an
injectable interface; test fakes exist only under test/. No code-generation or
new runtime dependencies were added, and pubspec.lock is retained.

## Navigation and access

Startup/welcome/auth forms are public only when backend setup is valid. Setup,
loading and error states fail closed. Authenticated incomplete users onboard,
pending users wait for institutional review, rejected/suspended users receive
restricted state handling, and verified students/alumni enter OneShell.
Recovery sessions go to password update without bypassing membership review.

OneShell preserves five bottom destinations and the original mentor/opportunity
entry points. All eleven original screens are tested using appropriate fake
sessions. The anonymous sample-dashboard button was removed; no runtime preview
flag bypasses guards. GoRouter refreshes from auth state changes rather than
being recreated per event. Safe internal destinations survive loading.

AuthController separates identity from membership. Generation counters prevent
late restoration/membership responses from undoing newer session changes/logout.
Unknown data, failed membership checks and auth stream errors close access.
Membership refreshes on resume, every sixty seconds and manually. Database
checks, not that polling interval, authorize every privileged operation.

## Database and integration boundary

Professional profiles contain no email or privileged membership/role fields.
Private membership/role/audit records have no client table grants. Base profiles
are self-only. Reviewed SECURITY DEFINER directory/map RPCs return explicitly
limited columns after caller/target checks; no exposed views are created.
Onboarding and verification share per-user locking and transactional invariants.
Admin roles are provisioned only through trusted server/owner operations.

See database-schema.md, security-model.md and authentication-flow.md for exact
relationships, privileges, states and workflows. See supabase-setup.md for the
required local SQL test and hosted-development integration sequence. Migrations,
RLS tests and actual Auth/email/deep-link flows are not claimed as verified live.

## Design and accessibility

Existing Material 3 colors and typography are preserved: navy #09285B, blue
#1557A0, gold #F5BF30, background #F5F7FC and white surfaces. Gold uses navy text.
System fonts/icons avoid external assets. Pages scroll and cap width at 960;
cards wrap into one, two or four columns. Form fields/buttons use the established
components, readable text and large tap targets. Original layout tests cover
320/390/840 logical pixels with 100%/200% text. New account states are also tested
with enlarged text. These are widget checks, not device or screen-reader sign-off.

Task 05 implements live map and professional connection repositories. See
[map/network contracts and local validation](task05-map-network.md) for
privacy, local fixtures, optional provider licensing and hosted prerequisites.
