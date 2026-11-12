# MSGI One engineering conventions

1. Follow Flutter and Dart best practices and the installed SDK's APIs.
2. Use feature-first architecture under `lib/features/`.
3. Keep business logic separate from UI; add data/domain boundaries when needed.
4. Prefer Riverpod for shared application state and dependency injection.
5. Centralize navigation and future authentication guards in GoRouter.
6. Keep widgets focused and reusable. Use shared theme and spacing tokens.
7. Never hardcode secrets, private credentials, or privileged API keys.
8. Never bypass authentication, verification, authorization, or backend RLS.
9. Never present mock data as real. Preserve explicit preview and sample labels.
10. Write tests for important application behavior, especially navigation, state, and access rules.
11. Run `dart format lib test`, `flutter analyze`, and `flutter test` after relevant changes. Verify Android builds when changing dependencies or platform configuration.
12. Do not upgrade dependencies without a demonstrated reason; retain `pubspec.lock`.
13. Avoid unrelated changes and system-wide tool/configuration modifications.
14. Explain important architectural decisions in `docs/decisions.md`.
15. Do not silently introduce major new dependencies. Prefer the existing stack.
16. Protect existing functionality during refactoring; update meaningful tests.

The current app is a public, offline foundation preview. It has no authenticated
session, backend initialization, network-backed directory, or real user data.
Supabase integration must introduce session/verification guards and database
policies before exposing any protected feature. Public preview routes are not
an authentication mechanism and must not be reused as one.

Flutter 3.50 generated `material_ui`; use its Material widgets consistently.
Preserve generated Android Gradle configuration unless a concrete error requires a change.
