import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:msgi_one/app.dart';
import 'package:msgi_one/core/routing/app_router.dart';
import 'package:msgi_one/core/routing/app_routes.dart';
import 'package:msgi_one/features/auth/application/auth_providers.dart';
import 'package:msgi_one/features/auth/domain/auth_repository.dart';
import 'package:msgi_one/features/administration/domain/administration_repository.dart';
import 'package:msgi_one/features/administration/data/administration_providers.dart';

import 'helpers/fake_auth_repository.dart';

class _Reviews extends AdministrationRepository {
  @override
  Future<Map<String, dynamic>> context() async => {
    'pending': people.length,
    'reports': 0,
    'requests': 0,
  };
  bool fail = false;
  int calls = 0;
  MembershipReview? saved;
  List<MembershipCandidate> people = [
    const MembershipCandidate(
      id: 'candidate',
      name: 'Synthetic pending member',
      claimedKind: 'alumni',
      institutionId: 'institution',
      departmentId: 'department',
      joiningYear: 2020,
      graduationYear: 2024,
    ),
  ];
  @override
  Future<List<MembershipCandidate>> pending({int limit = 30}) async {
    calls++;
    if (fail) throw StateError('Denied or offline');
    return people;
  }

  @override
  Future<void> review(MembershipReview input) async {
    saved = input;
    people = [];
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Reviews reviews, {
  MembershipState membership = MembershipState.verifiedStudent,
}) async {
  final auth = FakeAuthRepository(
    session: const AuthSession('reviewer'),
    membership: membership,
  );
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        administrationRepositoryProvider.overrideWithValue(reviews),
        initialLocationProvider.overrideWithValue(AppRoutes.administration),
      ],
      child: const OneApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Review requires independent evidence type and bounded audit reason',
    () {
      expect(
        const MembershipReview(
          userId: 'same',
          decision: ReviewDecision.verified,
          reason: 'Reviewed',
          verifiedKind: 'alumni',
        ).validate('same'),
        isNotNull,
      );
      expect(
        const MembershipReview(
          userId: 'other',
          decision: ReviewDecision.verified,
          reason: 'Reviewed',
        ).validate('reviewer'),
        isNotNull,
      );
      expect(
        const MembershipReview(
          userId: 'other',
          decision: ReviewDecision.rejected,
          reason: ' ',
        ).validate('reviewer'),
        isNotNull,
      );
      expect(
        const MembershipReview(
          userId: 'other',
          decision: ReviewDecision.suspended,
          reason: 'Reviewed',
          verifiedKind: 'alumni',
        ).validate('reviewer'),
        isNotNull,
      );
      expect(
        const MembershipReview(
          userId: 'other',
          decision: ReviewDecision.verified,
          reason: 'Reviewed independently',
          verifiedKind: 'student',
        ).validate('reviewer'),
        isNull,
      );
    },
  );
  testWidgets(
    'Admin queue error is safe and retry reloads pending submissions',
    (tester) async {
      final repo = _Reviews()..fail = true;
      await _pump(tester, repo);
      expect(
        find.textContaining('Administrator access is required'),
        findsOneWidget,
      );
      expect(find.text('Denied or offline'), findsNothing);
      repo.fail = false;
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic pending member'), findsOneWidget);
    },
  );
  testWidgets(
    'Review needs type, audit reason and evidence confirmation before save',
    (tester) async {
      final repo = _Reviews();
      await _pump(tester, repo);
      await tester.ensureVisible(find.text('Review evidence and decide'));
      await tester.tap(find.text('Review evidence and decide'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm review'));
      await tester.pumpAndSettle();
      expect(repo.saved, isNull);
      await tester.enterText(
        find.widgetWithText(TextField, 'Private audit reason'),
        'Synthetic independent review',
      );
      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Verified account type',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alumni').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirm review'));
      await tester.tap(find.text('Confirm review'));
      await tester.pumpAndSettle();
      expect(repo.saved, isNull);
      expect(
        find.text('Confirm independent evidence review first.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirm review'));
      await tester.tap(find.text('Confirm review'));
      await tester.pumpAndSettle();
      expect(repo.saved!.verifiedKind, 'alumni');
      expect(repo.saved!.reason, 'Synthetic independent review');
      expect(find.text('No pending reviews'), findsOneWidget);
    },
  );
  for (final membership in [
    MembershipState.pending,
    MembershipState.rejected,
    MembershipState.suspended,
  ]) {
    testWidgets('$membership cannot enter administrator workflow', (
      tester,
    ) async {
      final repo = _Reviews();
      await _pump(tester, repo, membership: membership);
      expect(repo.calls, 0);
      expect(find.text('Review pending memberships'), findsNothing);
    });
  }
}
