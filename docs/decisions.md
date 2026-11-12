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
