import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:msgi_one/app.dart';
import 'package:msgi_one/core/routing/app_router.dart';
import 'package:msgi_one/core/routing/app_routes.dart';
import 'package:msgi_one/features/auth/application/auth_providers.dart';
import 'package:msgi_one/features/auth/domain/auth_repository.dart';
import 'package:msgi_one/features/mentorship/data/mentor_providers.dart';
import 'package:msgi_one/features/mentorship/domain/mentor_repository.dart';
import 'package:msgi_one/features/connections/data/connections_providers.dart';
import 'package:msgi_one/features/profile/data/profile_providers.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_mentor_repository.dart';
import 'helpers/fake_network_repositories.dart';
import 'helpers/fake_profile_repository.dart';

Future<void> pumpMentors(
  WidgetTester tester,
  FakeMentorRepository repo, {
  MembershipState membership = MembershipState.verifiedStudent,
}) async {
  final auth = FakeAuthRepository(
    session: const AuthSession('student'),
    membership: membership,
  );
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        mentorRepositoryProvider.overrideWithValue(repo),
        connectionsRepositoryProvider.overrideWithValue(
          FakeConnectionsRepository(),
        ),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        catalogRepositoryProvider.overrideWithValue(FakeMentorCatalog()),
        initialLocationProvider.overrideWithValue(AppRoutes.mentors),
      ],
      child: const OneApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String text) async {
  final target = find.text(text).first;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  test('Preference serialization excludes labels and foreign identity', () {
    final goals = MentorGoals.fromJson({
      'career_interests': ['Research'],
      'target_domains': ['Embedded'],
      'existing_skill_ids': ['skill'],
      'learning_skill_ids': [],
      'objectives': ['Career planning'],
      'skill_names': {'skill': 'Circuits'},
      'user_id': 'forged',
    });
    expect(
      goals.toJson().keys,
      unorderedEquals([
        'career_interests',
        'target_domains',
        'existing_skill_ids',
        'learning_skill_ids',
        'objectives',
      ]),
    );
    expect(goals.skillNames['skill'], 'Circuits');
  });
  test(
    'Reasons use only returned evidence and never invent shared interests',
    () {
      final m = FakeMentorRepository().people.first;
      expect(m.reasons, contains('Relevant skills: Circuit design'));
      expect(
        m.reasons.any((s) => s.contains('Shared career interests')),
        false,
      );
      expect(m.reasons, contains('Open to mentorship'));
    },
  );
  testWidgets(
    'Mentors show explanations, limited evidence and real connection controls',
    (tester) async {
      await pumpMentors(tester, FakeMentorRepository());
      expect(find.text('Mentor recommendations'), findsOneWidget);
      expect(find.text('SAMPLE PREVIEW'), findsNothing);
      expect(
        find.text('Limited evidence: 2 of 3 personal signals'),
        findsWidgets,
      );
      expect(
        find.text('Works in your target domain: Embedded Systems'),
        findsWidgets,
      );
      await press(tester, 'View mentor profile');
      expect(find.text('Alumni profile'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
    },
  );
  testWidgets('Server filters and cursor pagination are passed explicitly', (
    tester,
  ) async {
    final repo = FakeMentorRepository();
    await pumpMentors(tester, repo);
    await press(tester, 'Load more mentors');
    expect(repo.lastAfter, 'id-019');
    expect(find.text('Synthetic mentor 24'), findsOneWidget);
    await press(tester, 'Refine recommendations');
    await tester.ensureVisible(find.text('Filter mentor domain'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Filter mentor domain'),
      'Embedded',
    );
    await press(tester, 'Refresh recommendations');
    expect(repo.lastDomain, 'Embedded');
    expect(repo.lastAfter, isNull);
    await press(tester, 'Skill alignment');
    expect(repo.lastSort, 'skills');
    await press(tester, 'Only new connections');
    expect(repo.lastUnconnected, true);
  });
  testWidgets(
    'Network error retries and empty states do not fabricate mentors',
    (tester) async {
      final repo = FakeMentorRepository()..fail = true;
      await pumpMentors(tester, repo);
      expect(
        find.textContaining('Recommendations unavailable'),
        findsOneWidget,
      );
      repo.fail = false;
      repo.people = [];
      await press(tester, 'Retry recommendations');
      expect(find.text('No eligible mentors yet'), findsOneWidget);
    },
  );
  testWidgets('Goals persist and saving errors retain edits for retry', (
    tester,
  ) async {
    final repo = FakeMentorRepository();
    await pumpMentors(tester, repo);
    await press(tester, 'Personalize your goals');
    final field = find.widgetWithText(
      TextFormField,
      'Target professional domains',
    );
    await tester.enterText(field, 'Robotics');
    repo.fail = true;
    await press(tester, 'Save goals');
    expect(find.textContaining('Goals could not be saved'), findsOneWidget);
    expect(find.text('Robotics'), findsOneWidget);
    repo.fail = false;
    await press(tester, 'Save goals');
    expect(repo.value.domains, ['Robotics']);
    expect(find.text('Mentor recommendations'), findsOneWidget);
  });
  testWidgets('Invalid preference lists prevent save', (tester) async {
    final repo = FakeMentorRepository();
    await pumpMentors(tester, repo);
    await press(tester, 'Personalize your goals');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Career interests'),
      List.generate(11, (i) => 'Item $i').join(','),
    );
    await press(tester, 'Save goals');
    expect(find.textContaining('Use up to 10 entries'), findsOneWidget);
  });
  testWidgets('Preference load failure cannot overwrite saved values', (
    tester,
  ) async {
    final repo = FakeMentorRepository();
    await pumpMentors(tester, repo);
    repo.fail = true;
    await press(tester, 'Personalize your goals');
    expect(find.text('Save goals'), findsNothing);
    expect(find.text('Retry preferences'), findsOneWidget);
    repo.fail = false;
    await press(tester, 'Retry preferences');
    expect(find.text('Embedded Systems'), findsOneWidget);
  });
  testWidgets('Hide removes a mentor and Undo restores eligibility', (
    tester,
  ) async {
    final repo = FakeMentorRepository();
    await pumpMentors(tester, repo);
    await press(tester, 'Hide this mentor');
    expect(repo.hidden, contains('id-000'));
    expect(find.text('Synthetic mentor 0'), findsNothing);
    await press(tester, 'Undo');
    expect(repo.hidden, isEmpty);
    expect(find.text('Synthetic mentor 0'), findsOneWidget);
  });
  testWidgets(
    'Skill catalog search and selection persist without duplicate search labels',
    (tester) async {
      final repo = FakeMentorRepository();
      await pumpMentors(tester, repo);
      await press(tester, 'Personalize your goals');
      final objectives = find.widgetWithText(
        TextFormField,
        'Mentorship objectives',
      );
      await tester.ensureVisible(objectives);
      await tester.enterText(objectives, 'Career planning, Portfolio feedback');
      await tester.pumpAndSettle();
      await press(tester, 'Skills to learn');
      expect(
        find.widgetWithText(TextField, 'Search Skills to learn'),
        findsOneWidget,
      );
      expect(find.textContaining('Search Search'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search Skills to learn'),
        'circuit',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await press(tester, 'Synthetic circuit skill');
      await press(tester, 'Save goals');
      expect(repo.value.learning, ['skill-a']);
      expect(repo.value.objectives, ['Career planning', 'Portfolio feedback']);
    },
  );
  testWidgets('Unverified users never reach mentor recommendations', (
    tester,
  ) async {
    await pumpMentors(
      tester,
      FakeMentorRepository(),
      membership: MembershipState.pending,
    );
    expect(find.text('Mentor recommendations'), findsNothing);
  });
}
