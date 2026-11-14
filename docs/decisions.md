# Engineering decisions — 2026-11-12

## Task 02 — historical foundation decisions

The following entries record the original project name and location at creation.
They are historical records; current branding and rebranding decisions follow.

1. **One project at `D:\MSGI_nexus`.** The workspace contained only `debug.log`;
   it is preserved and ignored. Package name: `msgi_nexus`; Android-only generation.
2. **Temporary Android identity:** `com.msgi.nexus.msgi_nexus`, generated from
   `--org com.msgi.nexus`. Approve the final ID before backend callback URLs or
   release signing. Display name: MSGI Nexus. Generated Gradle versions retained;
   see the necessary project-local workaround below.
3. **Existing stable toolchain:** Flutter 3.50.0, Dart 3.14.0; no tools upgraded.
4. **Flutter resolver-selected stable dependencies:** Riverpod 3.5.0, GoRouter
   18.1.4, Supabase Flutter 2.18.3. Keep caret constraints and commit the lockfile.
   No map SDK, code generation, extra networking or design package is needed.
5. **Retain generated Material dependency:** `material_ui` resolved to 1.11.0;
   the installed Flutter template imports its Material widgets from this package.
   Unused template Cupertino icons removed.
6. **Feature-first with useful boundaries:** data/domain layers only where there
   are entities/filtering. No placeholder repository or use-case scaffolding.
7. **Explicit public preview:** disabled credential fields collect nothing.
   Explore sample dashboard grants no authenticated access. Real guards/RLS are
   required when integrating auth; no simulated login/session is created.
8. **Riverpod-owned router and shared datasets:** GoRouter centralizes routes;
   transient search input is local state. Bottom-tab history persistence deferred.
9. **Accessible light theme:** system fonts/icons, navy foreground on gold,
   scrolling layouts, flexible cards, preserved enlarged text, no remote assets.
10. **Honest samples:** no fabricated real member, employer, vacancy or personalized
    recommendation. Local search is the only sample-directory behavior.
11. **No backend initialization:** SDK resolved only. Integration requires approved
    verification rules, schema, RLS and real public client configuration.
12. **Local checkpoint only:** no GitHub repository/push, deployment, external
    account connection, Supabase project or production signing identity.
13. **Project-local Kotlin cache workaround:** the Android build repeatedly failed
    at `:shared_preferences_android:compileDebugKotlin`, with incremental cache
    storage reported as already registered. Set `kotlin.incremental=false` in
    `android/gradle.properties`. This trades some Kotlin rebuild performance for
    reliability; no global caches, tool versions, or plugin versions are changed.
    Revisit after incremental compilation is verified reliable on this setup. See
    [Kotlin compilation and caches](https://kotlinlang.org/docs/gradle-compilation-and-caches.html).
14. **Plugin SDK requirements:** Gradle automatically installed Android Platform 35
    revision 2 and CMake 3.22.1 in the existing user SDK while compiling plugins. The app
    still targets the generated API 36 configuration; no SDK downgrade occurred.

Package references: [Riverpod](https://pub.dev/packages/flutter_riverpod),
[GoRouter](https://pub.dev/packages/go_router),
[Supabase Flutter](https://pub.dev/packages/supabase_flutter).

## Task 02B — controlled rebranding to MSGI One

- College-suggested competition name: **MSGI One**. Tagline:
  **One Community. Infinite Connections.** Dart package becomes `msgi_one`.
- Preferred final repository location: `D:\MSGI_One`, moved only after code,
  analysis, tests and Android build verification in the original location.
  Verification passed, but Windows rejected the move with a file-in-use error.
  The repository remains at `D:\MSGI_nexus`; the destination does not exist.
  Retry relocation after the open handle is released; no force or copy was used.
- Preserve the existing Git history and Android application ID/namespace
  `com.msgi.nexus.msgi_nexus`, including its Kotlin activity package and directory.
  These technical identity references intentionally keep the original name.
- Update Material app title, startup, branding components, signup preview,
  Android display label, imports, tests and current project documentation.
  Shared visible branding uses `AppConfig` to avoid inconsistent future labels.
- Rename only branding-related Dart identifiers and widget filenames. Routes,
  feature behavior, theme values, dependencies and Gradle settings are unchanged.
- Historical Task 02 entries, verification evidence and Git commit messages
  retain their original names/paths for traceability; they are not current setup
  instructions. No remote is created and no history is rewritten.

## Task 03A — authentication and database security foundation

1. Work in the existing locked directory; do not retry relocation. No hosted
   project, schema, key or external account is created/connected by this task.
2. No auth.users creation trigger. `submit_onboarding` is one database transaction
   with a per-user advisory lock, constraints, skills, pending membership and an
   initial audit record. Failure leaves no partial profile. Review takes the
   same lock so verified institutional claims cannot race a profile resubmission.
3. Professional profiles, private memberships and private administrator roles
   are separate. User metadata and claimed category never confer authority.
   Initial catalogs and the first administrator require trusted server operations.
4. Base profiles are self-readable only. Narrow SECURITY DEFINER directory/map
   RPCs enforce current membership and return explicit safe columns. There are
   no exposed views. All definers have empty search paths, schema-qualified
   references, revoked PUBLIC/anon execution, and runtime checks. Private tables
   have RLS and no client grants. Self-only RLS/grants remain separate from RPCs.
5. Connection creation derives sender from auth.uid(). Canonical unordered UUID
   pairs reject duplicates/reversals. Row-locked transitions enforce pending-state
   and recipient/sender action ownership. No direct client insert/update grant.
6. MVP opportunity publishers are verified alumni or verified administrators.
   Students can browse published listings; scope can change only with explicit
   requirements/policy tests. Already published content is not automatically
   deleted by author suspension; moderators must review it separately.
7. Build configuration accepts HTTPS origins and current publishable keys only.
   Legacy JWT-format anon/service keys are rejected deliberately. Missing/invalid
   values or initialization failure show setup. No demonstration backend or key
   is bundled. Configuration values and raw backend errors are never displayed.
8. Auth repository injection is test-only; no production preview bypass flag.
   Session identity and current database membership are separate states. Async
   results are generation-checked so stale reads cannot undo sign-out/session
   changes. Read/restore failures close routes; failed logout stays closed until
   retry. Membership refreshes on resume, manually and every sixty seconds.
9. Route guards are UX only. Database state is checked on every privileged SQL
   statement/RPC; UI refresh timing does not authorize database operations.
10. Password policy is 12–128 characters in forms; hosted Auth must enforce the
    corresponding minimum and email confirmation. Recovery uses generic responses.
    Mobile email/recovery callbacks and cold-start links remain Task 03B work.
11. Android gains internet permission, disallows cleartext and disables app backup
    to reduce session-backup exposure. SDK default app-private session storage is
    retained without adding a storage dependency; device-at-rest hardening still
    requires review before production. Android ID and Gradle settings are unchanged.
12. Database pgTAP tests are written against actual roles/SQL, not Flutter fakes.
    No local CLI/Docker/PostgreSQL was detected on PATH; do not call SQL tests
    passed without executing them. No large tools are installed for this task.

## Task 03D - development callback ownership

Reuse Supabase Flutter's existing app_links/PKCE integration; disable Flutter's
competing activity deep-link handler, while retaining GoRouter for internal app
routes. Use one exact project-specific development callback for confirmation and
recovery, shared by the auth adapter and Android manifest. No new dependencies,
Android ID changes or authorization shortcuts. Real cold/warm-start device tests
remain required; local SDK request tests do not establish callback delivery.

## Task 03D follow-up - isolated local Auth support

Debug builds can explicitly opt in to 127.0.0.1 HTTP using LOCAL_AUTH_TESTING and
a separate ignored public config; Android cleartext access is limited to loopback
in the debug source set. Release/profile builds still require HTTPS. This supports
USB reverse forwarding without changing SDKs, hosted limits or global trust.
Supabase debug printing is disabled explicitly because SDK diagnostics can include
callback URLs or raw server errors. Mailpit links are sensitive mailbox contents,
not diagnostic logs. See local-auth-testing.md for isolation and restoration.

## Task 04A - profiles and alumni discovery

New forward-only migration `20261113000100_profiles_and_discovery.sql` adds bounded
company/domain/biography/degree fields, an owner-only profile_drafts table, and
save_member_profile(jsonb)/discover_alumni(...) RPCs. Existing RPC signatures and
private authorization records are unchanged. Apply/review locally first; hosted
deployment requires separate explicit approval. It has NOT been deployed hosted.

Drafts are explicit server saves, scoped by authenticated user and account_allowed;
no plaintext local profile persistence dependency is added. Partial data survives
restart only after Save progress privately. No anonymous sample bypass exists.
Successful submit atomically writes profile/skills/mentoring, clears draft and
leaves new membership pending. Pending users may edit/view only their own profile.
Verified users can edit professional content/consent but cannot change verified
institution, department, category or batch through this RPC. Review RPC and profile
submission share the existing advisory lock. No administrator is client-provisioned.

Discovery returns verified, confirmed-email, directory-opted-in alumni only; callers
must be verified members. It returns a fixed professional projection, never auth
email, role, private audit, interests, draft or approval data. City/country are
returned AND filterable only when map consent is enabled. Filtering is server-side,
with deterministic UUID keyset pagination (20 rows + one lookahead, max server 50).
UUID order is stable but intentionally not alphabetical; there is no exact total
count. The original directory RPC remains available for backward compatibility.

The explicit synthetic catalog seed is separate from official seed.sql, opt-in
and used only by an isolated-local acceptance script. Synthetic account verification
in that script is a server-owned authorization fixture with an audit reason, not
an administrator role or a public provisioning path. Never run it hosted.

## Task 04B.2 - approval boundaries and reviewer UI

Use a render-only catalog manifest/import tool with explicit approval gates;
official institution/city data remains on hold. The guarded owner bootstrap is
separate from migrations/seeds and refuses missing pending profiles or ambiguous
existing administrators. No public provisioning RPC or client role assignment.
The first-bootstrap audit records the external approver explicitly, rather than
fabricating a second user. See task04b2-hosted-acceptance.md for prerequisites.

Administrator UI reuses pending_memberships/review_membership, pins no client
admin claim, and treats successful server queue authorization as the capability
check for showing its entry. Route/UI checks are not a database security boundary.
Every mutation requires the actual server-side verified administrator check,
self-review denial and private audit. No new schema or grants are required.

## Task 05 - consent-safe geography and connection state

Use flutter_map with bundled public-domain Natural Earth land as the default,
avoiding an unapproved production tile service. Optional MapTiler use requires
explicit review of a logo-exempt plan and retains linked text attribution.
City catalog centroids are quantized, not user coordinates. Aggregate and detail
RPCs enforce identical verification/consent criteria before filtering/pagination.
Group markers client-side without downloading the alumni directory.

Add forward-only RPCs rather than changing legacy contracts. Pair locks plus the
existing unique relationship constraint serialize connection requests; direction
and participant checks precede idempotency. Removed connections retain history as
cancelled. Network rows hide unavailable peer details; student connection
eligibility is distinct from availability of an alumni public profile. Server
checks remain authoritative. See task05-map-network.md for contracts and limits.

## Task 06 - deterministic evidence-based mentor matching

Rank on the server over authorized, visible opted-in alumni. Use existing skills,
public professional domains and career interests; private goals belong only to the
requester. Missing signals are omitted and evidence caps prevent inflated sparse
scores. Availability alone yields zero. Relevance is not AI success probability.
Store objectives privately without pretending they affect this version's score.
Use bounded keyset responses and UUID ties; reapply filters after goals change.

Add mentor_goals and mentorship-scoped private exclusions in migration six;
explicit RPC guards, empty search_path and unchanged existing RLS preserve the
server authorization boundary. Reuse catalog search and connection controls,
with no new dependencies. See task06-mentor-matching.md for formula and limits.

## Task 07 - Career Bridge and preserved publishing policy

Reuse can_publish (verified alumni/authorized administrators), existing kinds,
draft/published/closed states and reports. Add explicit scope, required skills,
referral flag and archival without weakening prior RLS. Closed/draft/archive data
stays author-only. Mask private author identities and guard public profile links.
Retry-safe client request IDs avoid duplicate creation; updated_at guards edits.
Scope IDs come from the author profile, never client-selected institution IDs.

Career relevance is explicit skill coverage, not AI inference. Bound server pages
and tuple cursors; revalidate application URLs before a confirmed external launch.
Use existing catalog UI and SDK integration tests with simulated input only.
Keep the applied base migration and its forward-only filter qualification fix.
See task07-career-bridge.md for contracts, constraints and validation instructions.

## Task 08A - explicit isolated competition demo

Use a parentless repository scope rather than fake Auth sessions or relaxed real
membership guards. A separate presentation identity supports shared ownership UI.
Demo fixtures and persistent state never enter Supabase. Use one versioned demo
preference; reset never clears real SDK storage. Defer real initialization to an
explicit entry or validated callback. Dispose the real client before demo entry,
without signing out, and hand callbacks to the real SDK with fail-closed handling.
Reuse existing feature screens with small presentation parameters rather than
scattered mode conditionals. Keep staff separate from administrator authorization.
Existing locked app_links/shared_preferences are direct dependencies, unchanged
in version. See task08a-demo-experience.md for boundaries and validation limits.

## Task 08B - progressive disclosure and repository-backed dashboards

Reuse feature repositories for dashboard highlights in both isolated and real
scopes; remove production sample-preview labeling when content is now authorized
repository data. Do not invent community metrics. Auto-disposed highlight queries
fetch existing bounded pages and refresh when revisiting the dashboard. Separate
presentation copy is injected at demo composition, not used for authorization.
Use a keyboard-aware filter sheet and compact expandable details to prioritize
results without removing controls. Retain actual score evidence and server filters.
Provide an inner transparent Material in PageBody because navigator transitions
can insert opaque backgrounds above the shell Material and hide ListTile ink.
No packages, backend contracts or permissions change. See task08b-ui-polish.md.

## Task 08C - content-first feeds and isolated tab retention

Keep demo disclosure visible as a compact information action instead of repeating
long warnings on every screen. Fictional organizations remain explicitly labeled;
never add fabricated production metrics. Upgrade version-one demo placeholder copy
selectively while preserving user edits, graph transitions and privacy choices.
Use stateful branches only inside the independent demo router to retain tab state;
real membership/authorization architecture is unchanged.

Use bounded sliver builders for discovery/mentor/opportunity rows and existing RPC
pagination, not full-directory downloads. Shared compact search, status, person and
skeleton components unify feeds. The map uses its content viewport with floating
filters, draggable authorized city results and fixed attribution. No location data,
consent or backend contracts change. See task08c-consumer-experience.md.

## Task 09 - programmes are not authorization departments

Represent supplied MSEC programmes independently from academic departments. Expose
the local programme catalog only through explicit demo composition; do not reuse
the existing departments table/RPC parameter for degrees or silently ignore an
unsupported hosted programme filter. Keep identifiers stable and document their
internal scope. Preserve existing demo graph state during academic-catalog upgrade.
Only Science and Humanities is supplied as a department; no alumni mapping is
inferred. Empty affiliations do not grant department-scoped demo visibility.
Use pushed detail routes with pop/fallback return behavior and explicit save results
to preserve parents without duplicate opportunity editors/details. Existing server
authorization remains unchanged. See task09-msec-integration.md.
# Dedicated competition signing and acceptance storage

Task 10A+B replaces the generated release-to-debug signing fallback with explicit
release-only environment credentials. A local Windows helper provisions one
non-overwriting key outside Git with DPAPI-protected password storage and a
restricted directory ACL; the build helper supplies credentials only to the
build process and accepts no backend defines. Missing release signing fails closed.
The existing application ID, version and callback are retained. Owner-approved
data removal is required to replace a debug-signed installation with this key.
Native integration acceptance now uses a separate persistence namespace and
asserts the presenter's actual demo snapshot is unchanged. This permits physical
debug testing without resetting the owner's demo data. See
`android-competition-release.md` for backup and manual acceptance requirements.
# Task 11A — real academic claims and local launch gate

Keep degree programmes separate from authorization departments. MSEC receives
stable application identifiers, nine undergraduate and four postgraduate
programmes, and only the supplied Science and Humanities department. Composite
foreign keys tie both academic references to the institution. Programme-only
profiles are supported by compatible protected discovery/map/mentor/career RPCs;
a degree choice never creates a department permission. Official MSEC catalog
insertion is a separate guarded owner operation, not the normal empty seed.

Staff is a self-declared account kind and, after independent verification, an
ordinary member kind. It is not an administrator or alumni publisher. Keep email
confirmation, institutional status and administrator grants distinct. Existing
RPC signatures remain; v2 discovery/review projections add programme support.
An enum-only migration commits before dependent schema changes. No historical
migration or hosted infrastructure is changed.

Successful profile persistence publishes an independent revision signal before
membership refresh. Profile/draft/buffer providers consume that signal; the Auth
controller must not read/invalidate providers that depend on itself (a Riverpod
cycle) or rely on a form that a route redirect may dispose. Draft-save feedback
is inline to avoid obscuring Submit/Log out on subsequent screens. SDK storage
can be injected for isolated native acceptance; production defaults are retained.

Task 11A tests real local Mailpit/Android callbacks and process restoration on a
separate debug emulator, with no Samsung replacement or competition APK rebuild.
Versioned Auth defaults are hardened for future application, while existing live
stack settings and all hosted settings remain untouched. Public invitations need
institutional/SMTP/privacy/operational approval and an independently reviewed
deployment, as documented in `real-user-launch-readiness.md`.
