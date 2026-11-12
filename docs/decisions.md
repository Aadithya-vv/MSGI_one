# Engineering decisions — 2026-11-12

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
