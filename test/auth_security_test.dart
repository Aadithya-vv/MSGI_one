import 'package:msgi_one/features/profile/data/profile_providers.dart';

import 'helpers/fake_profile_repository.dart';

import 'package:msgi_one/features/profile/domain/profile_repository.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:msgi_one/app.dart';
import 'package:msgi_one/core/config/backend_config.dart';
import 'package:msgi_one/core/routing/access_redirect.dart';
import 'package:msgi_one/core/routing/app_routes.dart';
import 'package:msgi_one/core/routing/app_router.dart';
import 'package:msgi_one/features/auth/application/auth_providers.dart';
import 'package:msgi_one/features/auth/data/supabase_auth_repository.dart';
import 'package:msgi_one/features/auth/domain/auth_repository.dart';
import 'package:msgi_one/features/auth/domain/onboarding.dart';

import 'helpers/fake_auth_repository.dart';

Future<ProviderContainer> start(FakeAuthRepository repository) async {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(() async {
    container.dispose();
    await repository.dispose();
  });
  container.read(authControllerProvider);
  await Future<void>.delayed(Duration.zero);
  return container;
}

Future<void> pumpAuth(
  WidgetTester tester,
  FakeAuthRepository repository, {
  String path = AppRoutes.home,
  double scale = 1,
  ProfileRepository? profiles,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(repository.dispose);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        profileRepositoryProvider.overrideWithValue(
          profiles ?? FakeProfileRepository(),
        ),
        initialLocationProvider.overrideWithValue(path),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: const OneApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('configuration defaults closed and rejects non-public keys or malformed URLs', () {
    expect(const BackendConfig().problem, isNotNull);
    expect(
      const BackendConfig(
        url: 'http://example.invalid',
        publishableKey: 'not-a-key',
      ).problem,
      isNotNull,
    );
    expect(
      const BackendConfig(
        url: 'https://example.invalid',
        publishableKey: 'not-a-publishable-key',
      ).problem,
      contains('publishable'),
    );
    // Reserved origin and synthetic marker; validator only, never a live client.
    expect(
      const BackendConfig(
        url: 'https://example.invalid',
        publishableKey: 'sb_publishable_TEST_ONLY_NOT_A_LIVE_KEY',
      ).problem,
      isNull,
    );
    expect(
      const BackendConfig(
        url: 'https://user@example.invalid',
        publishableKey: 'unused',
      ).problem,
      isNotNull,
    );
  });
  test('membership parser fails closed on invalid verification data', () {
    expect(
      () => SupabaseAuthRepository.parseMembership({
        'status': 'verified',
        'profile_complete': true,
      }),
      throwsA(isA<AuthFailure>()),
    );
    expect(
      () => SupabaseAuthRepository.parseMembership({
        'status': 'unknown',
        'profile_complete': true,
      }),
      throwsA(isA<AuthFailure>()),
    );
    expect(
      SupabaseAuthRepository.parseMembership({
        'status': null,
        'profile_complete': false,
      }),
      MembershipState.incomplete,
    );
  });
  for (final phase in AccessPhase.values.where(
    (p) => p != AccessPhase.verifiedAlumni && p != AccessPhase.verifiedStudent,
  )) {
    test('$phase blocks every protected route without redirect loops', () {
      for (final path in [
        AppRoutes.home,
        AppRoutes.discover,
        AppRoutes.map,
        AppRoutes.network,
        AppRoutes.profile,
        AppRoutes.mentors,
        AppRoutes.opportunities,
      ]) {
        expect(accessRedirect(AccessState(phase), path), isNotNull);
      }
      final destination = accessRedirect(AccessState(phase), AppRoutes.home)!;
      expect(accessRedirect(AccessState(phase), destination), isNull);
    });
  }
  test('verified student and alumni may enter community routes', () {
    for (final phase in [
      AccessPhase.verifiedStudent,
      AccessPhase.verifiedAlumni,
    ]) {
      expect(accessRedirect(AccessState(phase), AppRoutes.discover), isNull);
    }
  });
  for (final membership in MembershipState.values) {
    test(
      'restoration loads $membership separately from authentication',
      () async {
        final container = await start(
          FakeAuthRepository(
            session: const AuthSession('fixture'),
            membership: membership,
          ),
        );
        expect(
          container.read(authControllerProvider).phase.name,
          membership.name,
        );
      },
    );
  }
  test('membership refresh failure removes cached verified access', () async {
    final repository = FakeAuthRepository(
      session: const AuthSession('fixture'),
    );
    final container = await start(repository);
    expect(container.read(authControllerProvider).isVerified, isTrue);
    repository.failMembership = true;
    await container.read(authControllerProvider.notifier).refresh();
    expect(container.read(authControllerProvider).phase, AccessPhase.error);
  });
  test('late membership response cannot undo sign-out', () async {
    final repository = FakeAuthRepository(
      session: const AuthSession('fixture'),
    );
    repository.membershipRequest = Completer<MembershipState>();
    final container = await start(repository);
    repository.emit(null);
    repository.membershipRequest!.complete(MembershipState.verifiedAlumni);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authControllerProvider).phase, AccessPhase.signedOut);
  });
  test(
    'late restoration cannot overwrite a newer signed-in identity',
    () async {
      final repository = FakeAuthRepository();
      repository.restorationRequest = Completer<AuthSession?>();
      final container = await start(repository);
      repository.emit(const AuthSession('new-identity'));
      repository.restorationRequest!.complete(null);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authControllerProvider).userId, 'new-identity');
      expect(container.read(authControllerProvider).isVerified, isTrue);
    },
  );
  test(
    'restoration failures do not grant signed-in or verified access',
    () async {
      final repository = FakeAuthRepository(
        session: const AuthSession('fixture'),
      );
      repository.failRestore = true;
      final container = await start(repository);
      expect(container.read(authControllerProvider).phase, AccessPhase.error);
    },
  );
  test('session stream errors are handled and fail closed', () async {
    final repository = FakeAuthRepository(
      session: const AuthSession('fixture'),
    );
    final container = await start(repository);
    repository.events.addError(const AuthFailure());
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authControllerProvider).phase, AccessPhase.error);
  });
  test('requested recovery after logout accepts only recovery and reloads membership', () async {
    final repository = FakeAuthRepository(
      session: const AuthSession('fixture'),
      membership: MembershipState.pending,
    );
    final container = await start(repository);
    final controller = container.read(authControllerProvider.notifier);
    await controller.signOut();
    repository.emit(const AuthSession('fixture', passwordRecovery: true));
    expect(container.read(authControllerProvider).phase, AccessPhase.signedOut);
    await controller.requestPasswordReset('fixture@example.invalid');
    repository.emit(const AuthSession('fixture'));
    expect(container.read(authControllerProvider).phase, AccessPhase.signedOut);
    repository.emit(const AuthSession('fixture', passwordRecovery: true));
    expect(
      container.read(authControllerProvider).phase,
      AccessPhase.passwordRecovery,
    );
    await controller.updatePassword('test-only-new-password');
    expect(container.read(authControllerProvider).phase, AccessPhase.pending);
    expect(repository.passwordUpdates, 1);
  });
  test('failed logout is not undone by stale refresh events', () async {
    final repository = FakeAuthRepository(
      session: const AuthSession('fixture'),
    );
    final container = await start(repository);
    repository.failLogout = true;
    await container.read(authControllerProvider.notifier).signOut();
    repository.emit(const AuthSession('fixture'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authControllerProvider).phase, AccessPhase.error);
    repository.failLogout = false;
    await container.read(authControllerProvider.notifier).signOut();
    expect(container.read(authControllerProvider).phase, AccessPhase.signedOut);
  });
  test(
    'onboarding validates account type, batch and independent privacy consent',
    () {
      OnboardingInput input({
        AccountKind kind = AccountKind.student,
        int graduation = 2028,
        bool visible = false,
        bool map = false,
        String? city,
      }) => OnboardingInput(
        displayName: 'Fixture Student',
        kind: kind,
        institutionId: 'institution',
        departmentId: 'department',
        joiningYear: 2024,
        graduationYear: graduation,
        interests: const ['Technology'],
        skillIds: const ['skill'],
        directoryVisible: visible,
        mapOptIn: map,
        cityId: city,
      );
      expect(input().validate(currentYear: 2026), isNull);
      expect(
        input(kind: AccountKind.alumni).validate(currentYear: 2026),
        isNotNull,
      );
      expect(
        input(map: true, city: 'city').validate(currentYear: 2026),
        isNotNull,
      );
      expect(
        input(map: true, visible: true).validate(currentYear: 2026),
        isNotNull,
      );
      expect(
        input(
          map: true,
          visible: true,
          city: 'city',
        ).validate(currentYear: 2026),
        isNull,
      );
      expect(input().toRpc().keys, isNot(contains('role')));
      expect(input().toRpc().keys, isNot(contains('verification_status')));
    },
  );
  testWidgets('missing configuration displays setup without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backendConfigProvider.overrideWithValue(const BackendConfig()),
        ],
        child: const OneApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Development setup required'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'session and membership changes update navigation including suspension',
    (tester) async {
      final repository = FakeAuthRepository();
      await pumpAuth(tester, repository);
      expect(find.text('Welcome back'), findsOneWidget);
      repository.emit(const AuthSession('fixture'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      repository.membership = MembershipState.suspended;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NavigationBar)),
      );
      await container.read(authControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(find.text('Membership suspended'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
    },
  );
  for (final membership in [
    MembershipState.incomplete,
    MembershipState.pending,
    MembershipState.rejected,
    MembershipState.suspended,
  ]) {
    testWidgets('$membership account screen supports large text', (
      tester,
    ) async {
      await pumpAuth(
        tester,
        FakeAuthRepository(
          session: const AuthSession('fixture'),
          membership: membership,
        ),
        scale: 2,
      );
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'pending approval refresh opens community only after verification',
    (tester) async {
      final repository = FakeAuthRepository(
        session: const AuthSession('fixture'),
        membership: MembershipState.pending,
      );
      await pumpAuth(tester, repository);
      expect(find.text('Verification pending'), findsOneWidget);
      repository.membership = MembershipState.verifiedStudent;
      await tester.tap(find.text('Refresh membership status'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );
  testWidgets('signup validates confirmation and requests email confirmation', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await pumpAuth(tester, repository, path: AppRoutes.signup);
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'fixture@example.invalid',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'test-only-password',
    );
    await tester.enterText(
      find.byKey(const Key('auth-confirm')),
      'different-test-password',
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(repository.signUpCalls, 0);
    expect(find.text('Passwords must match.'), findsOneWidget);
    expect(
      find.text('Check the highlighted fields before continuing.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('auth-confirm')),
      'test-only-password',
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(repository.signUpCalls, 1);
    expect(find.textContaining('Check your inbox'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
  testWidgets('recovery request uses a generic anti-enumeration response', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await pumpAuth(tester, repository, path: AppRoutes.recover);
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'fixture@example.invalid',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Send recovery instructions'),
    );
    await tester.pumpAndSettle();
    expect(repository.recoveryCalls, 1);
    expect(find.textContaining('If an account exists'), findsOneWidget);
  });
  testWidgets('onboarding submits structured data and remains pending', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      session: const AuthSession('fixture'),
      membership: MembershipState.incomplete,
    );
    await pumpAuth(tester, repository);
    Future<void> enter(String label, String value) async {
      final field = find.widgetWithText(TextFormField, label);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
      await tester.pumpAndSettle();
    }

    await enter('Display name', 'Test Student');
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<String>).at(0),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test institution').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<String>).at(1),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test department').last);
    await tester.pumpAndSettle();
    await enter('Joining year', '2024');
    await enter('Graduation year (actual or expected)', '2028');
    await enter('Career interests (comma separated)', 'Technology, Research');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final skillChip = find.widgetWithText(FilterChip, 'Test skill');
    await tester.ensureVisible(skillChip);
    await tester.pumpAndSettle();
    await tester.tap(skillChip);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(skillChip).selected, isTrue);
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Submit for institutional review'),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Submit for institutional review'),
    );
    await tester.pumpAndSettle();
    expect(repository.submitted, isNotNull);
    expect(repository.submitted!.directoryVisible, isFalse);
    expect(repository.submitted!.mapOptIn, isFalse);
    expect(find.text('Verification pending'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
  testWidgets('recovery session resets password without bypassing membership', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      session: const AuthSession('fixture', passwordRecovery: true),
      membership: MembershipState.pending,
    );
    await pumpAuth(tester, repository);
    expect(find.text('Choose a new password'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'test-only-password',
    );
    await tester.enterText(
      find.byKey(const Key('auth-confirm')),
      'test-only-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Update password'));
    await tester.pumpAndSettle();
    expect(repository.passwordUpdates, 1);
    expect(find.text('Verification pending'), findsOneWidget);
  });
}
