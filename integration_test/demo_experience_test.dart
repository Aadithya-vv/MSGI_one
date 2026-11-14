import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:msgi_one/main.dart' as app;
import 'package:msgi_one/features/demo/domain/demo_store.dart';
import 'package:msgi_one/features/demo/data/demo_persistence.dart';
import 'package:msgi_one/features/demo/presentation/demo_experience.dart';

class OfflineDemoHttp extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Presentation demo must stay offline');
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Offline Student Alumni Staff journeys and demo restoration', (
    tester,
  ) async {
    final prefs = SharedPreferencesAsync();
    // Only the demo namespace and this synthetic sentinel are touched.
    await prefs.remove(PreferencesDemoPersistence.key);
    await prefs.setString(
      'msgi_one.task08.test_sentinel',
      'keep-independent-data',
    );
    final oldHttp = HttpOverrides.current, http = OfflineDemoHttp();
    HttpOverrides.global = http;
    addTearDown(() => HttpOverrides.global = oldHttp);
    await app.main();
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    Future<void> ready(Finder f) async {
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 150));
        if (f.evaluate().isNotEmpty) return;
      }
      throw StateError('Expected demo journey control unavailable');
    }

    Future<void> tap(Finder f) async {
      await ready(f);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(f.first);
      await tester.pumpAndSettle();
      await tester.tap(f.first);
      await tester.pumpAndSettle();
    }

    Future<void> role(String label) async {
      await tap(find.byType(DropdownButton<DemoRole>));
      await tap(find.text(label).last);
    }

    await tap(find.text('Explore Demo'));
    await tap(find.text('Student demo'));
    await ready(find.text('Welcome, Mira Rao (Demo)'));
    expect(find.text('Demo'), findsOneWidget);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01_student_home');
    await tap(find.text('Discover alumni'));
    await tester.enterText(find.byKey(const Key('alumni-search')), 'Alumni 08');
    await tap(find.text('Search alumni'));
    await tap(find.text('Alumni 08 (Demo)'));
    await ready(find.text('FICTIONAL DEMONSTRATION PROFILE'));
    expect(find.text('VERIFIED ALUMNI'), findsNothing);
    await tap(find.text('Connect'));
    await ready(find.text('Request sent'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02_sample_alumni_profile');
    await tap(find.byTooltip('Back'));
    await tap(find.text('Home'));
    await tap(find.text('Find a mentor'));
    await ready(find.text('100 / 100 relevance'));
    await tester.ensureVisible(find.text('100 / 100 relevance').first);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('03_mentor_recommendations');
    await tap(find.text('Home'));
    await tap(find.text('Career Bridge'));
    await tap(find.text('Internships'));
    await ready(find.textContaining('internship'));
    await tap(find.text('View opportunity'));
    await ready(find.text('Opportunity details'));
    expect(find.text('Apply externally'), findsNothing);
    await tap(find.byTooltip('Back'));
    await tap(find.text('Map'));
    await ready(find.byTooltip('London'));
    await tap(find.byTooltip('London'));
    await ready(find.textContaining('London alumni'));
    await binding.takeScreenshot('04_offline_map');

    await role('Alumni');
    await ready(find.text('Welcome, Arjun Iyer (Demo)'));
    await tap(find.text('Network'));
    await tap(find.text('Incoming'));
    await tap(find.text('Accept'));
    await tap(find.text('Connected'));
    await ready(find.text('Mira Rao (Demo)'));
    await binding.takeScreenshot('05_alumni_connections');
    await tap(find.text('Profile'));
    await tap(find.text('Demo mentoring availability'));
    final mentoring = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Demo mentoring availability'),
    );
    expect(mentoring.value, false);
    await tap(find.text('Home'));
    await tap(find.text('Career Bridge'));
    await tap(find.text('Create opportunity'));
    await ready(find.byKey(const Key('career-title')));
    await tester.enterText(
      find.byKey(const Key('career-title')),
      'Demo competition collaboration',
    );
    await tester.enterText(
      find.byKey(const Key('career-description')),
      'A simulated student-alumni project, not a real opening.',
    );
    final company = find.byKey(const Key('career-organization'));
    await tester.ensureVisible(company);
    await tester.pumpAndSettle();
    await tester.enterText(company, 'Sample Demonstration Group');
    await tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Opportunity type'),
    );
    await tap(find.text('Project collaboration').last);
    final external = tester.widget<TextFormField>(
      find.byKey(const Key('career-external_url')),
    );
    expect(external.enabled, false);
    await tap(find.text('Publish opportunity'));
    await ready(find.text('Opportunity details'));
    await ready(find.text('Demo competition collaboration'));
    await binding.takeScreenshot('06_simulated_opportunity');

    await role('Staff / Faculty');
    await ready(find.text('Welcome, Kavya Sen (Demo)'));
    await tap(find.text('Students and faculty'));
    await tap(find.text('student'));
    await tap(find.text('View sample profile'));
    await ready(find.text('Sample student profile'));
    expect(find.text('Review memberships'), findsNothing);
    await tap(find.byTooltip('Back'));
    await tap(find.text('Home'));
    await tap(find.text('Students and faculty'));
    await binding.takeScreenshot('07_staff_community');
    await tap(find.text('Home'));
    await tap(find.text('Find a mentor'));
    await ready(find.text('Mentor recommendations'));
    await tap(find.text('Home'));
    await tap(find.text('Career Bridge'));
    expect(find.text('Create opportunity'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    // Recreate the app tree: role and graph changes come from device storage.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await app.main();
    await ready(find.text('Welcome, Kavya Sen (Demo)'));
    expect(find.byType(DemoExperience), findsOneWidget);
    await tap(find.byTooltip('Demo controls'));
    await tap(find.text('Reset demo'));
    await tap(find.text('Reset demo'));
    await ready(find.text('Welcome, Mira Rao (Demo)'));
    expect(
      await prefs.getString('msgi_one.task08.test_sentinel'),
      'keep-independent-data',
    );
    await prefs.remove('msgi_one.task08.test_sentinel');
    expect(http.attempts, 0);
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot('08_reset_student_home');
  });
}
