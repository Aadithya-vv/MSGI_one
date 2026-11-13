import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:msgi_one/app.dart';
import 'package:msgi_one/core/routing/app_router.dart';
import 'package:msgi_one/core/routing/app_routes.dart';
import 'package:msgi_one/features/auth/application/auth_providers.dart';
import 'package:msgi_one/features/auth/domain/auth_repository.dart';
import 'package:msgi_one/features/opportunities/data/career_providers.dart';
import 'package:msgi_one/features/opportunities/domain/career_repository.dart';
import 'package:msgi_one/features/profile/data/profile_providers.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_career_repository.dart';
import 'helpers/fake_mentor_repository.dart';
import 'helpers/fake_profile_repository.dart';

Future<void> pumpCareers(
  WidgetTester tester,
  FakeCareerRepository repo, {
  String path = AppRoutes.opportunities,
  MembershipState membership = MembershipState.verifiedAlumni,
  double? width,
  double scale = 1,
}) async {
  if (width != null) {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  final auth = FakeAuthRepository(
    session: const AuthSession('fixture-user'),
    membership: membership,
  );
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        careerRepositoryProvider.overrideWithValue(repo),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        catalogRepositoryProvider.overrideWithValue(FakeMentorCatalog()),
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

Future<void> pressCareer(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final f = find.text(text).first;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> fillCareer(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('career-title')),
    'Synthetic internship',
  );
  await tester.enterText(
    find.byKey(const Key('career-description')),
    'Synthetic development internship for safe testing.',
  );
}

void main() {
  test('Create request IDs are valid independent v4 UUIDs', () {
    final ids = List.generate(100, (_) => careerRequestId());
    expect(ids.toSet().length, 100);
    expect(
      ids.every(
        (id) => RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ).hasMatch(id),
      ),
      true,
    );
  });
  test('Application URL validation rejects dangerous schemes, credentials and private hosts', () {
    expect(
      safeCareerUrl('https://example.com/jobs?role=engineer')?.host,
      'example.com',
    );
    for (final value in [
      'javascript:alert(1)',
      'http://example.com',
      'https://user:secret@example.com',
      'https://127.0.0.1/jobs',
      'https://[::1]/jobs',
      'https://host.local/jobs',
      'https://host.test/jobs',
      'https://example.com:443/jobs',
      'https://example.com/%0aevil',
      'https://example.com\\evil',
      'https://example.com/a b',
      'https://',
    ]) {
      expect(
        safeCareerUrl(value),
        isNull,
        reason: 'Unsafe URL class must be denied',
      );
    }
  });
  testWidgets('Listing filters and cursor pagination remain server-backed', (
    tester,
  ) async {
    final repo = FakeCareerRepository();
    await pumpCareers(tester, repo);
    expect(find.text('SAMPLE PREVIEW'), findsNothing);
    await pressCareer(tester, 'Load more opportunities');
    expect(repo.lastAfter?.id, 'post-019');
    expect(find.text('Synthetic role 24'), findsOneWidget);
    await pressCareer(tester, 'Internships');
    expect(repo.lastFilters?['kind'], 'internship');
    await pressCareer(tester, 'My posts and drafts');
    expect(repo.lastFilters?['mine'], true);
    expect(repo.lastFilters?['status'], 'all');
    await pressCareer(tester, 'Skill overlap');
    expect(repo.lastFilters?['sort'], 'relevance');
  });
  testWidgets('Career empty, network failure and retry states', (tester) async {
    final repo = FakeCareerRepository()..fail = true;
    await pumpCareers(tester, repo);
    expect(find.textContaining('Career Bridge unavailable'), findsOneWidget);
    repo.fail = false;
    repo.rows = [];
    await pressCareer(tester, 'Retry careers');
    expect(find.text('No opportunities found'), findsOneWidget);
  });
  testWidgets('Required form fields and invalid URLs block submission', (
    tester,
  ) async {
    final repo = FakeCareerRepository();
    await pumpCareers(tester, repo, path: '/opportunities/new');
    await pressCareer(tester, 'Publish opportunity');
    expect(repo.saves, 0);
    expect(find.textContaining('Enter a title'), findsOneWidget);
    await fillCareer(tester);
    await tester.enterText(
      find.byKey(const Key('career-external_url')),
      'http://example.com',
    );
    await pressCareer(tester, 'Publish opportunity');
    expect(repo.saves, 0);
    expect(find.textContaining('Use a public HTTPS'), findsOneWidget);
  });
  testWidgets('A failed submission retains form and stable retry identity', (
    tester,
  ) async {
    final repo = FakeCareerRepository();
    await pumpCareers(tester, repo, path: '/opportunities/new');
    await fillCareer(tester);
    repo.fail = true;
    await pressCareer(tester, 'Save draft');
    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(find.text('Synthetic internship'), findsOneWidget);
    repo.fail = false;
    await pressCareer(tester, 'Save draft');
    expect(repo.saves, 1);
    expect(repo.rows.last.status, 'draft');
    expect(find.text('Opportunity details'), findsOneWidget);
    expect(find.text('Your post'), findsOneWidget);
  });
  testWidgets('Editing sends current version and preserves skill labels', (
    tester,
  ) async {
    final repo = FakeCareerRepository();
    await pumpCareers(tester, repo, path: '/opportunities/post-000/edit');
    expect(find.text('Synthetic circuit skill'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('career-title')),
      'Updated role',
    );
    await pressCareer(tester, 'Save changes');
    expect(repo.lastExpected, '2026-11-14T00:00:00.000000Z');
    expect(repo.rows.last.title, 'Updated role');
  });
  testWidgets(
    'Close and archive require confirmation and hide application action',
    (tester) async {
      final repo = FakeCareerRepository();
      await pumpCareers(tester, repo, path: '/opportunities/post-000');
      await pressCareer(tester, 'Close opportunity');
      expect(repo.lastAction, isNull);
      await pressCareer(tester, 'Confirm');
      expect(repo.lastAction, 'close');
      expect(find.text('Apply externally'), findsNothing);
      await pressCareer(tester, 'Archive opportunity');
      await pressCareer(tester, 'Confirm');
      expect(repo.lastAction, 'archive');
      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('Edit opportunity'), findsNothing);
    },
  );
  testWidgets(
    'Safe external links show destination confirmation before leaving',
    (tester) async {
      await pumpCareers(
        tester,
        FakeCareerRepository(),
        path: '/opportunities/post-000',
      );
      await pressCareer(tester, 'Apply externally');
      expect(find.textContaining('example.com'), findsOneWidget);
      await pressCareer(tester, 'Stay here');
      expect(find.text('Opportunity details'), findsOneWidget);
    },
  );
  testWidgets('Author profile navigation exposes only available alumni', (
    tester,
  ) async {
    final repo = FakeCareerRepository();
    repo.rows[0] = CareerPost({...repo.rows[0].data, 'author_id': 'id-000'});
    await pumpCareers(tester, repo, path: '/opportunities/post-000');
    await pressCareer(tester, 'View author profile');
    expect(find.text('Alumni profile'), findsOneWidget);
  });
  testWidgets('Reports validate details then use the moderation repository', (
    tester,
  ) async {
    final repo = FakeCareerRepository();
    repo.rows[0] = CareerPost({...repo.rows[0].data, 'author_id': 'id-000'});
    await pumpCareers(tester, repo, path: '/opportunities/post-000');
    await pressCareer(tester, 'Report opportunity');
    await pressCareer(tester, 'Send report');
    expect(repo.reports, 0);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Report details'),
      'Explicitly synthetic moderation details.',
    );
    await pressCareer(tester, 'Send report');
    expect(repo.reports, 1);
  });
  testWidgets('Missing posts do not fabricate content', (tester) async {
    await pumpCareers(
      tester,
      FakeCareerRepository(),
      path: '/opportunities/missing',
    );
    expect(find.text('Post no longer available'), findsOneWidget);
  });
  testWidgets(
    'Student capability hides publishing and direct editor refuses access',
    (tester) async {
      final repo = FakeCareerRepository()..allowed = false;
      await pumpCareers(
        tester,
        repo,
        path: '/opportunities/new',
        membership: MembershipState.verifiedStudent,
      );
      expect(find.text('Publish opportunity'), findsNothing);
      expect(
        find.textContaining('Publishing requires verified alumni'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Editor fits a narrow phone with enlarged text and collaboration scope',
    (tester) async {
      final repo = FakeCareerRepository();
      repo.rows[0] = CareerPost({
        ...repo.rows[0].data,
        'kind': 'collaboration',
        'audience': 'department',
        'referral': false,
      });
      await pumpCareers(
        tester,
        repo,
        path: '/opportunities/post-000/edit',
        width: 320,
        scale: 2,
      );
      await tester.ensureVisible(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Pending users cannot reach Career Bridge', (tester) async {
    await pumpCareers(
      tester,
      FakeCareerRepository(),
      membership: MembershipState.pending,
    );
    expect(find.text('Career opportunities'), findsNothing);
  });
}
