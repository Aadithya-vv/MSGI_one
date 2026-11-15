import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/admin_acceptance_fixture.dart';

void main() {
  testWidgets(
    'Server context denial renders no candidates and never loads the queue',
    (tester) async {
      final repo = AdminAcceptanceRepository()..authorized = false;
      final auth = adminAcceptanceAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(adminAcceptanceApp(repo, auth));
      await tester.pumpAndSettle();
      expect(repo.memberCalls, 0);
      expect(
        find.textContaining('[SYNTHETIC] Reviewer acceptance'),
        findsNothing,
      );
      expect(find.text('PRIVATE DATABASE DETAIL'), findsNothing);
    },
  );
  testWidgets(
    'Membership pagination and declared-type filter use bounded repository queries',
    (tester) async {
      final repo = AdminAcceptanceRepository();
      final auth = adminAcceptanceAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(adminAcceptanceApp(repo, auth));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Next page'));
      await tester.tap(find.text('Next page'));
      await tester.pumpAndSettle();
      expect(repo.lastOffset, 30);
      await tester.ensureVisible(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Declared account type',
        ),
      );
      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Declared account type',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('staff').last);
      await tester.pumpAndSettle();
      expect(repo.lastKind, 'staff');
      expect(repo.lastOffset, 0);
    },
  );
  testWidgets(
    'Report decision requires reason and deliberate evidence confirmation',
    (tester) async {
      final repo = AdminAcceptanceRepository();
      final auth = adminAcceptanceAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(adminAcceptanceApp(repo, auth));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Review moderation decision'));
      await tester.tap(find.text('Review moderation decision'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm moderation'));
      await tester.pumpAndSettle();
      expect(repo.moderated, false);
      await tester.enterText(
        find.widgetWithText(TextField, 'Private moderation reason'),
        'Synthetic policy decision',
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirm moderation'));
      await tester.tap(find.text('Confirm moderation'));
      await tester.pumpAndSettle();
      expect(repo.moderated, true);
      expect(find.text('No matching reports'), findsOneWidget);
    },
  );
  testWidgets(
    'Administrator controls fit small screen at enlarged text and expose safe history',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = AdminAcceptanceRepository();
      final auth = adminAcceptanceAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: adminAcceptanceApp(repo, auth),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Private review history').first);
      await tester.tap(find.text('Private review history').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('evidence_unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
