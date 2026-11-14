import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:msgi_one/features/auth/domain/onboarding.dart';
import 'package:msgi_one/features/auth/domain/auth_repository.dart';
import 'package:msgi_one/features/auth/data/supabase_auth_repository.dart';
import 'package:msgi_one/features/auth/application/auth_providers.dart';
import 'package:msgi_one/features/profile/data/profile_providers.dart';
import 'package:msgi_one/features/catalog/domain/academic_catalog.dart';
import 'package:msgi_one/core/routing/app_routes.dart';
import 'package:msgi_one/core/routing/access_redirect.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_security_test.dart' as harness;
import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_profile_repository.dart';

import 'package:msgi_one/features/profile/domain/profile_repository.dart';

OnboardingInput input(AccountKind kind) => OnboardingInput(
  displayName: 'Synthetic member',
  kind: kind,
  institutionId: 'institution',
  departmentId: '',
  programmeId: kind == AccountKind.staff ? null : 'programme',
  affiliation: kind == AccountKind.staff ? 'Academic support' : '',
  joiningYear: kind == AccountKind.student ? 2024 : 0,
  graduationYear: kind == AccountKind.staff
      ? 0
      : kind == AccountKind.student
      ? 2028
      : 2020,
  designation: 'Engineer',
  interests: ['Engineering'],
  skillIds: kind == AccountKind.staff ? [] : ['skill'],
);

class MsecAuth extends FakeAuthRepository {
  MsecAuth({AccountKind kind = AccountKind.student})
    : suggested = kind,
      super(
        session: const AuthSession('fixture'),
        membership: MembershipState.incomplete,
      );
  final AccountKind suggested;
  @override
  Future<OnboardingOptions> loadOnboardingOptions() async => OnboardingOptions(
    institutions: const [
      CatalogEntry(
        id: 'institution',
        name: MsecCatalog.name,
        catalogKey: 'msec',
      ),
    ],
    departments: const [
      CatalogEntry(
        id: 'department',
        name: 'Science and Humanities',
        institutionId: 'institution',
      ),
    ],
    programmes: [
      for (final p in MsecCatalog.catalog.programmes)
        CatalogEntry(
          id: p.id,
          name: p.name,
          institutionId: 'institution',
          level: p.level.name,
        ),
    ],
    skills: const [CatalogEntry(id: 'skill', name: 'Synthetic skill')],
    cities: const [],
    suggestedKind: suggested,
  );
}

class AccountHintAuth extends FakeAuthRepository {
  AccountHintAuth()
    : super(
        session: const AuthSession('first'),
        membership: MembershipState.incomplete,
      );
  @override
  Future<OnboardingOptions> loadOnboardingOptions() async => OnboardingOptions(
    institutions: const [],
    departments: const [],
    skills: const [],
    cities: const [],
    suggestedKind: session?.userId == 'first'
        ? AccountKind.staff
        : AccountKind.alumni,
  );
}

class SavingAuth extends FakeAuthRepository {
  SavingAuth(this.profiles)
    : super(
        session: const AuthSession('fixture'),
        membership: MembershipState.incomplete,
      );
  final FakeProfileRepository profiles;
  @override
  Future<void> submitOnboarding(OnboardingInput value) async {
    await profiles.save(value);
    await super.submitOnboarding(value);
  }
}

void main() {
  testWidgets(
    'Real programme selector fits a long official label at 200 percent text',
    (tester) async {
      final auth = MsecAuth();
      addTearDown(auth.dispose);
      final programme = MsecCatalog.catalog.programme(
        'msec-ug-cse-cybersecurity',
      )!;
      final value = OnboardingInput.fromJson({
        ...input(AccountKind.student).toJson(),
        'programme_id': programme.id,
        'degree': programme.name,
      });
      final profiles = FakeProfileRepository()
        ..profile = MemberProfile(
          value,
          institution: MsecCatalog.name,
          department: '',
          skills: const ['Synthetic skill'],
        );
      await harness.pumpAuth(tester, auth, profiles: profiles, scale: 2);
      final picker = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Degree programme',
      );
      await tester.ensureVisible(picker);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Expired callback gives safe actionable guidance and retains closed routes',
    () async {
      final auth = FakeAuthRepository();
      final container = await harness.start(auth);
      container.read(authControllerProvider.notifier).authLinkFailed();
      final state = container.read(authControllerProvider);
      expect(state.phase, AccessPhase.error);
      expect(state.notice, contains('invalid, expired or already used'));
      expect(accessRedirect(state, AppRoutes.discover), AppRoutes.authError);
    },
  );
  test('Successful onboarding invalidates a cached absent profile before membership navigation', () async {
    final profiles = FakeProfileRepository();
    final auth = SavingAuth(profiles);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await auth.dispose();
    });
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(await container.read(ownProfileProvider.future), isNull);
    await container
        .read(authControllerProvider.notifier)
        .submitOnboarding(input(AccountKind.student));
    expect(container.read(authControllerProvider).phase, AccessPhase.pending);
    expect(
      (await container.read(ownProfileProvider.future))!.input.programmeId,
      'programme',
    );
    expect(container.read(onboardingBufferProvider), isNull);
  });
  test('Account-type hints reload on identity change rather than leaking the last account choice', () async {
    final auth = AccountHintAuth();
    final container = await harness.start(auth);
    expect(
      (await container.read(onboardingOptionsProvider.future)).suggestedKind,
      AccountKind.staff,
    );
    auth.emit(const AuthSession('second'));
    await Future<void>.delayed(Duration.zero);
    expect(
      (await container.read(onboardingOptionsProvider.future)).suggestedKind,
      AccountKind.alumni,
    );
  });
  testWidgets(
    'Signup preserves Staff claim and throttles immediate confirmation resend',
    (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      await harness.pumpAuth(tester, auth, path: AppRoutes.signup);
      await tester.tap(find.byKey(const Key('signup-account-kind')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Faculty / Staff').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'synthetic@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'Synthetic-Password-Only',
      );
      await tester.enterText(
        find.byKey(const Key('auth-confirm')),
        'Synthetic-Password-Only',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Create account'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();
      expect(auth.signupKind, AccountKind.staff);
      await tester.ensureVisible(find.text('Resend confirmation email'));
      await tester.tap(find.text('Resend confirmation email'));
      await tester.pumpAndSettle();
      expect(auth.resendCalls, 0);
      expect(
        find.textContaining('Please wait at least a minute'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Submitting a draft dismisses its notice before pending-profile actions',
    (tester) async {
      final auth = MsecAuth();
      addTearDown(auth.dispose);
      final profiles = FakeProfileRepository()
        ..profile = MemberProfile(
          input(AccountKind.student),
          institution: MsecCatalog.name,
          department: '',
          skills: const ['Synthetic skill'],
        );
      await harness.pumpAuth(tester, auth, profiles: profiles);
      await tester.ensureVisible(find.text('Save progress privately'));
      await tester.tap(find.text('Save progress privately'));
      await tester.pumpAndSettle();
      expect(
        find.text('Progress saved privately to your account.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Submit for institutional review'));
      await tester.tap(find.text('Submit for institutional review'));
      await tester.pumpAndSettle();
      expect(find.text('Verification pending'), findsOneWidget);
      expect(
        find.text('Progress saved privately to your account.'),
        findsNothing,
      );
    },
  );
  for (final kind in AccountKind.values) {
    test('$kind input roundtrip and private defaults', () {
      final value = input(kind);
      expect(value.validate(currentYear: 2026), isNull);
      expect(OnboardingInput.fromJson(value.toJson()).toJson(), value.toJson());
      expect(value.directoryVisible, isFalse);
      expect(value.mapOptIn, isFalse);
      expect(value.toJson().containsKey('verified_kind'), isFalse);
    });
  }
  test('Staff cannot submit a programme or infer institutional authority from metadata', () {
    final value = OnboardingInput.fromJson({
      ...input(AccountKind.staff).toJson(),
      'programme_id': 'programme',
      'role': 'administrator',
      'verified': true,
    });
    expect(value.validate(), isNotNull);
    expect(value.toJson().containsKey('role'), isFalse);
    expect(
      SupabaseAuthRepository.parseMembership({
        'status': 'pending',
        'profile_complete': true,
        'verified_kind': 'staff',
      }),
      MembershipState.pending,
    );
  });
  test(
    'Staff verification is a server state with ordinary member route access',
    () {
      expect(
        SupabaseAuthRepository.parseMembership({
          'status': 'verified',
          'profile_complete': true,
          'verified_kind': 'staff',
        }),
        MembershipState.verifiedStaff,
      );
      expect(
        accessRedirect(
          const AccessState(AccessPhase.verifiedStaff),
          AppRoutes.discover,
        ),
        isNull,
      );
      expect(
        accessRedirect(
          const AccessState(AccessPhase.pending),
          AppRoutes.discover,
        ),
        AppRoutes.pending,
      );
    },
  );
  test('Official SQL seed exactly preserves the existing thirteen programme labels', () {
    final seed = File('supabase/catalogs/msec.sql').readAsStringSync();
    for (final p in MsecCatalog.catalog.programmes) {
      expect(seed, contains(p.name));
      expect(seed, contains(p.id));
    }
    expect(RegExp("'undergraduate'\\)").allMatches(seed).length, 9);
    expect(RegExp("'postgraduate'\\)").allMatches(seed).length, 4);
    expect(seed, contains("current_setting('msgi.catalog_approved'"));
  });
  testWidgets(
    'Student selects a canonical programme without a department claim',
    (tester) async {
      final auth = MsecAuth();
      addTearDown(auth.dispose);
      await harness.pumpAuth(tester, auth);
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Institution'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(MsecCatalog.name).last);
      await tester.pumpAndSettle();
      final picker = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Degree programme',
      );
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('B.E. Civil Engineering').last);
      await tester.pumpAndSettle();
      expect(find.text('Academic department (optional)'), findsOneWidget);
      final container = ProviderScope.containerOf(tester.element(picker));
      final buffered = container.read(onboardingBufferProvider)!;
      expect(buffered.programmeId, 'msec-ug-civil');
      expect(buffered.departmentId, isEmpty);
    },
  );
  testWidgets(
    'Staff onboarding omits student years and does not claim administrator status',
    (tester) async {
      final auth = MsecAuth(kind: AccountKind.staff);
      addTearDown(auth.dispose);
      await harness.pumpAuth(tester, auth, scale: 2);
      expect(find.text('Faculty / Staff'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Joining year'), findsNothing);
      expect(
        find.widgetWithText(
          TextFormField,
          'Graduation year (actual or expected)',
        ),
        findsNothing,
      );
      expect(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Degree programme',
        ),
        findsNothing,
      );
      expect(find.text('Review memberships'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Alumni keeps programme selection independent of optional joining year',
    (tester) async {
      final auth = MsecAuth(kind: AccountKind.alumni);
      addTearDown(auth.dispose);
      await harness.pumpAuth(tester, auth);
      expect(find.text('Alumni'), findsOneWidget);
      expect(input(AccountKind.alumni).joiningYear, 0);
      expect(input(AccountKind.alumni).validate(), isNull);
    },
  );
  for (final action in ['signup', 'resend', 'recovery']) {
    test(
      '$action maps HTTP 429 safely without exposing server text',
      () => HttpOverrides.runWithHttpOverrides(() async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        Map<String, dynamic>? payload;
        String? path;
        server.listen((request) async {
          path = request.uri.path;
          payload = jsonDecode(
            await utf8.decoder.bind(request).join(),
          ) as Map<String, dynamic>;
          request.response.statusCode = 429;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'code': 'over_email_send_rate_limit',
              'msg': 'private diagnostic value',
            }),
          );
          await request.response.close();
        });
        final client = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          'synthetic-public-key',
          authOptions: AuthClientOptions(
            autoRefreshToken: false,
            pkceAsyncStorage: _MemoryStorage(),
          ),
        );
        addTearDown(client.dispose);
        addTearDown(() => server.close(force: true));
        final repository = SupabaseAuthRepository(client);
        await expectLater(
          switch (action) {
            'signup' => repository.signUp(
              'fixture@example.test',
              'synthetic-password',
              kind: AccountKind.staff,
            ),
            'resend' => repository.resendConfirmation('fixture@example.test'),
            _ => repository.requestPasswordReset('fixture@example.test'),
          },
          throwsA(
            isA<AuthFailure>().having(
              (error) => error.message,
              'safe rate-limit message',
              contains('Too many requests'),
            ),
          ),
        );
        expect(path, '/auth/v1/${action == 'recovery' ? 'recover' : action}');
        if (action == 'signup') {
          expect(payload!['data'], {'account_kind': 'staff'});
        }
      }, _LocalHttp()),
    );
  }
}

class _LocalHttp extends HttpOverrides {}

class _MemoryStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}
