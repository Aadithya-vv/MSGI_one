import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'auth_security_test.dart' as auth_tests;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:msgi_one/features/auth/domain/onboarding.dart';
import 'package:msgi_one/features/auth/application/auth_providers.dart';
import 'package:msgi_one/features/auth/domain/auth_repository.dart';
import 'package:msgi_one/features/profile/domain/profile_repository.dart';
import 'package:msgi_one/features/profile/data/profile_providers.dart';
import 'package:msgi_one/features/discovery/application/directory_controller.dart';
import 'package:msgi_one/core/routing/access_redirect.dart';
import 'package:msgi_one/core/routing/app_routes.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_profile_repository.dart';

OnboardingInput input({
  AccountKind kind = AccountKind.alumni,
  int year = 2024,
  bool map = false,
  bool visible = false,
  String? city,
}) => OnboardingInput(
  displayName: 'Synthetic graduate',
  kind: kind,
  institutionId: 'institution',
  departmentId: 'department',
  joiningYear: 2020,
  graduationYear: year,
  interests: ['Research'],
  skillIds: ['skill'],
  company: 'Synthetic company',
  professionalDomain: 'Engineering',
  degree: 'Synthetic qualification',
  biography: 'Professional biography',
  mentoring: true,
  cityId: city,
  mapOptIn: map,
  directoryVisible: visible,
);
void main() {
  test(
    'Student expected graduation and alumni completed graduation differ',
    () {
      expect(
        input(
          kind: AccountKind.student,
          year: 2028,
        ).validate(currentYear: 2026),
        isNull,
      );
      expect(input(year: 2028).validate(currentYear: 2026), isNotNull);
      expect(input().validate(currentYear: 2026), isNull);
    },
  );
  test(
    'Professional profile roundtrip preserves private preferences and fields',
    () {
      final original = input(map: true, visible: true, city: 'city');
      final restored = OnboardingInput.fromJson(original.toJson());
      expect(restored.toJson(), original.toJson());
      expect(restored.mentoring, isTrue);
      expect(restored.company, 'Synthetic company');
    },
  );
  test('Privacy requires both directory and city before map consent', () {
    expect(input(map: true).validate(), isNotNull);
    expect(input(map: true, visible: true).validate(), isNotNull);
    expect(input(map: true, visible: true, city: 'city').validate(), isNull);
  });
  test('Partial drafts preserve safe defaults without granting privileges', () {
    final draft = OnboardingInput.fromJson({
      'display_name': 'Partial',
      'verified': true,
      'role': 'administrator',
    });
    expect(draft.directoryVisible, isFalse);
    expect(draft.mapOptIn, isFalse);
    expect(draft.validate(), isNotNull);
    expect(draft.toJson().containsKey('role'), isFalse);
  });
  test('Pending own editing does not open directory or other profiles', () {
    const state = AccessState(AccessPhase.pending, userId: 'fixture');
    expect(accessRedirect(state, AppRoutes.profileEdit), isNull);
    expect(accessRedirect(state, AppRoutes.ownProfile), isNull);
    expect(accessRedirect(state, AppRoutes.discover), AppRoutes.pending);
    expect(accessRedirect(state, '/alumni/other'), AppRoutes.pending);
    expect(
      accessRedirect(
        const AccessState(AccessPhase.suspended),
        AppRoutes.profileEdit,
      ),
      AppRoutes.membershipStatus,
    );
  });
  test('Filters produce bounded server-side query parameters', () {
    final params = const DirectoryFilter(
      search: ' Ada ',
      institution: 'i',
      department: 'd',
      year: 2024,
      profession: 'company',
      skill: 's',
      city: 'c',
    ).params(after: 'last');
    expect(params['p_limit'], 21);
    expect(params['p_after'], 'last');
    expect(params['p_search'], 'Ada');
    expect(params['p_city'], 'c');
  });
  test(
    'Draft/profile save is resumable and clears draft only after success',
    () async {
      final repo = FakeProfileRepository();
      await repo.saveDraft({'display_name': 'Partial'});
      expect((await repo.draft())!['display_name'], 'Partial');
      repo.fail = true;
      await expectLater(repo.save(input()), throwsStateError);
      expect(repo.savedDraft, isNotNull);
      repo.fail = false;
      await repo.save(input());
      expect(await repo.draft(), isNull);
      expect((await repo.own())!.input.company, 'Synthetic company');
    },
  );
  test(
    'Directory pages with cursor, filters reset and failure retries',
    () async {
      final repo = FakeProfileRepository();
      final auth = FakeAuthRepository(session: const AuthSession('fixture'));
      final c = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(auth.dispose);
      c.read(authControllerProvider);
      await Future<void>.delayed(Duration.zero);
      final subscription = c.listen(directoryProvider, (_, _) {});
      addTearDown(subscription.close);
      var page = await c.read(directoryProvider.future);
      expect(page.people.length, 20);
      expect(page.hasMore, isTrue);
      final controller = c.read(directoryProvider.notifier);
      await controller.next();
      page = c.read(directoryProvider).requireValue;
      expect(page.people.length, 25);
      expect(page.hasMore, isFalse);
      expect(repo.lastAfter, 'id-019');
      repo.fail = true;
      await controller.search(const DirectoryFilter(search: 'Test'));
      expect(c.read(directoryProvider).hasError, isTrue);
      repo.fail = false;
      await controller.search(const DirectoryFilter(search: 'Test alumnus 24'));
      page = c.read(directoryProvider).requireValue;
      expect(page.people.single.name, 'Test alumnus 24');
      expect(repo.lastAfter, isNull);
    },
  );
  testWidgets(
    'Private draft resumes after a new application scope and save retries retain fields',
    (tester) async {
      final profiles = FakeProfileRepository()
        ..savedDraft = {
          'display_name': 'Saved draft name',
          'kind': 'alumni',
          'company': 'Saved company',
        };
      final auth = FakeAuthRepository(
        session: const AuthSession('fixture'),
        membership: MembershipState.incomplete,
      );
      await auth_tests.pumpAuth(tester, auth, profiles: profiles);
      expect(find.text('Saved draft name'), findsOneWidget);
      expect(find.text('Saved company'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display name'),
        'Changed draft',
      );
      final save = find.text('Save progress privately');
      await tester.ensureVisible(save);
      profiles.fail = true;
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.textContaining('Save failed'), findsOneWidget);
      profiles.fail = false;
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(profiles.savedDraft!['display_name'], 'Changed draft');
      final next = FakeAuthRepository(
        session: const AuthSession('fixture'),
        membership: MembershipState.incomplete,
      );
      await auth_tests.pumpAuth(tester, next, profiles: profiles);
      expect(find.text('Changed draft'), findsOneWidget);
    },
  );
  testWidgets(
    'Empty reference catalog blocks submission with helpful guidance',
    (tester) async {
      final auth = _EmptyCatalogAuth(
        session: const AuthSession('fixture'),
        membership: MembershipState.incomplete,
      );
      await auth_tests.pumpAuth(tester, auth);
      expect(find.text('Institutional catalog is not ready'), findsOneWidget);
      expect(find.text('Submit for institutional review'), findsNothing);
    },
  );
  testWidgets('Changing institution clears incompatible department', (
    tester,
  ) async {
    final profiles = FakeProfileRepository()
      ..savedDraft = {
        'display_name': 'Partial',
        'institution_id': 'institution',
        'department_id': 'department',
      };
    final auth = _TwoCatalogAuth(
      session: const AuthSession('fixture'),
      membership: MembershipState.incomplete,
    );
    await auth_tests.pumpAuth(tester, auth, profiles: profiles);
    final institution = find.byType(DropdownButtonFormField<String>).at(0);
    await tester.ensureVisible(institution);
    await tester.tap(institution);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second institution').last);
    await tester.pumpAndSettle();
    final department = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).at(1),
    );
    expect(department.initialValue, isNull);
    await tester.ensureVisible(find.text('Save progress privately'));
    await tester.tap(find.text('Save progress privately'));
    await tester.pumpAndSettle();
    expect(profiles.savedDraft!['institution_id'], 'second');
    expect(profiles.savedDraft!['department_id'], '');
  });
  testWidgets(
    'Unsaved progress survives membership-check routes and clears on logout',
    (tester) async {
      final auth = FakeAuthRepository(
        session: const AuthSession('fixture'),
        membership: MembershipState.incomplete,
      );
      await auth_tests.pumpAuth(tester, auth);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display name'),
        'Unsaved across refresh',
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TextFormField).first),
      );
      auth.membershipRequest = Completer<MembershipState>();
      final refresh = container.read(authControllerProvider.notifier).refresh();
      await tester.pump();
      auth.membershipRequest!.complete(MembershipState.incomplete);
      await refresh;
      await tester.pumpAndSettle();
      expect(find.text('Unsaved across refresh'), findsOneWidget);
      await container.read(authControllerProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(container.read(onboardingBufferProvider), isNull);
    },
  );
}

class _EmptyCatalogAuth extends FakeAuthRepository {
  _EmptyCatalogAuth({super.session, super.membership});
  @override
  Future<OnboardingOptions> loadOnboardingOptions() async =>
      const OnboardingOptions(
        institutions: [],
        departments: [],
        skills: [],
        cities: [],
      );
}

class _TwoCatalogAuth extends FakeAuthRepository {
  _TwoCatalogAuth({super.session, super.membership});
  @override
  Future<OnboardingOptions> loadOnboardingOptions() async {
    final original = await super.loadOnboardingOptions();
    return OnboardingOptions(
      institutions: [
        ...original.institutions,
        const CatalogEntry(id: 'second', name: 'Second institution'),
      ],
      departments: [
        ...original.departments,
        const CatalogEntry(
          id: 'second-department',
          name: 'Second department',
          institutionId: 'second',
        ),
      ],
      skills: original.skills,
      cities: original.cities,
    );
  }
}
