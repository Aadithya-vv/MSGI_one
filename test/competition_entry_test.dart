import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msgi_one/features/demo/presentation/experience_root.dart';

import 'helpers/demo_test_support.dart';
import 'demo_experience_test.dart' show demoTap;

void main() {
  testWidgets(
    'Competition entry ignores auth callbacks and permits offline demo',
    (tester) async {
      final links = TestAuthEntryLinks(
        first: Uri.parse(
          'com.msgi.one.dev://auth-callback/?code=synthetic-invalid',
        ),
      );
      addTearDown(links.close);
      var opens = 0;
      await tester.pumpWidget(
        ExperienceRoot(
          competitionOnly: true,
          persistence: MemoryDemoPersistence(),
          links: links,
          openProduction: () async {
            opens++;
            throw StateError('Must not initialize backend');
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in to real community'), findsNothing);
      expect(find.text('Create an account'), findsNothing);
      expect(
        find.textContaining('Offline competition demonstration'),
        findsOneWidget,
      );
      await demoTap(tester, 'Explore Demo');
      await demoTap(tester, 'Student demo');
      links.controller.add(
        Uri.parse(
          'com.msgi.one.dev://auth-callback/#access_token=synthetic-invalid',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Welcome, Mira Rao'), findsOneWidget);
      expect(opens, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
