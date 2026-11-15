// Native UI acceptance with clearly synthetic test-only repositories. API security
// is exercised separately by tool/test_local_administration.cjs against local Auth.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import '../test/helpers/admin_acceptance_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Synthetic administrator native navigation and deliberate moderation',
    (tester) async {
      final repo = AdminAcceptanceRepository();
      final auth = adminAcceptanceAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(adminAcceptanceApp(repo, auth));
      await tester.pumpAndSettle();
      expect(find.text('Institutional administration'), findsOneWidget);
      await tester.ensureVisible(find.text('Review evidence and decide').first);
      await tester.tap(find.text('Review evidence and decide').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.reviewCalls, 0);
      await tester.ensureVisible(find.text('Reports'));
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Review moderation decision'));
      await tester.tap(find.text('Review moderation decision'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Private moderation reason'),
        '[SYNTHETIC] Native reviewer decision',
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirm moderation'));
      await tester.tap(find.text('Confirm moderation'));
      await tester.pumpAndSettle();
      expect(repo.moderated, true);
      await tester.ensureVisible(find.text('Operations help'));
      await tester.tap(find.text('Operations help'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Only explicitly authorized'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
