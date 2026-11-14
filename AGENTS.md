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

Task 03A includes authentication adapters, membership-aware guards and unapplied
SQL migrations. No hosted Supabase project is connected. Without reviewed public
build configuration, show setup; never allow anonymous sample-dashboard access.
Feature content remains explicitly labelled samples. Test fakes belong only in
test/. Never substitute client route checks for database grants/RLS/RPC checks.
Membership and administrator roles come only from protected server records,
never from self-declared profile type or user-editable Auth metadata.
Run database security tests on an isolated local stack before hosted integration;
report unavailable/unexecuted checks accurately. Do not move the locked workspace
or connect to a hosted project without the next task's explicit authorization.

Flutter 3.50 generated `material_ui`; use its Material widgets consistently.
Preserve generated Android Gradle configuration unless a concrete error requires a change.

## Android Development and Testing

- Preferred development device: `MSGI_One_Pixel_4a_API_34`.
- Running emulator device ID: `emulator-5554`.
- Prefer the Android emulator for Flutter development, UI testing, hot reload and integration testing.
- Start the emulator when device testing is necessary and it is not already running.
- Do not require a physical Android phone for routine development.
- Use the existing local-only Supabase configuration for development tests unless a hosted test is explicitly requested.
- Avoid unnecessary authentication emails or modifications to hosted data.
- Report actual emulator test results separately from automated unit/widget tests.
- Reserve physical-device testing for final verification of real hardware behavior, performance and Android callbacks.
- Do not claim a device test passed unless it was executed successfully.
