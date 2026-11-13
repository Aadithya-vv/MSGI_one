import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:msgi_one/main.dart' as app;
import 'package:msgi_one/core/config/backend_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Local Career Bridge lifecycle and moderation acceptance', (
    tester,
  ) async {
    final config = BackendConfig.fromEnvironment();
    if (config.url != 'http://127.0.0.1:55321' ||
        !const bool.fromEnvironment('LOCAL_AUTH_TESTING')) {
      throw StateError('Isolated local build required');
    }
    final file = File(
      '/data/user/0/com.msgi.nexus.msgi_nexus/files/task07-career-fixture.json',
    );
    final fixture =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (!RegExp(r'^task07-writer-\d+@example.test$')
        .hasMatch(fixture['email'] as String)) {
      throw StateError('Synthetic local account required');
    }
    await app.main();
    // Avoid real Android IME overwriting tester-injected text. The SDK documents
    // this integration_test input race; only input transport is simulated.
    // Authentication, repositories, storage and RPCs remain real local services.
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    // The session is real local GoTrue authentication, with no repository fakes.
    await Supabase.instance.client.auth.signInWithPassword(
      email: fixture['email'] as String,
      password: fixture['password'] as String,
    );

    Future<void> ready(Finder finder) async {
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 150));
        if (finder.evaluate().isNotEmpty) return;
      }
      throw StateError('Expected local acceptance control unavailable');
    }

    Future<void> tap(Finder finder) async {
      await ready(finder);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(finder.first);
      await tester.pumpAndSettle();
      await tester.tap(finder.first);
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.pumpAndSettle();
    if (find.text('Get started').evaluate().isNotEmpty) {
      await tap(find.text('Get started'));
    }
    if (find.text('Log in').evaluate().isNotEmpty) {
      await tap(find.text('Log in'));
    }
    await ready(find.text('Map'));
    Future<void> homeCareers() async {
      await tap(find.text('Home'));
      await tap(find.text('Career opportunities'));
      await ready(find.text('CAREER BRIDGE'));
    }

    Future<void> search(String value) async {
      final field = find.widgetWithText(TextField, 'Search opportunities');
      await ready(field);
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, value);
      await tester.pumpAndSettle();
      await tap(find.text('Search Career Bridge'));
    }

    Future<void> enter(String key, String value) async {
      final field = find.byKey(Key('career-$key'));
      await ready(field);
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, value);
      await tester.pumpAndSettle();
    }

    await homeCareers();
    await search(fixture['externalTitle'] as String);
    await tap(find.text('View opportunity'));
    await ready(find.text('Opportunity details'));
    await tap(find.text('Apply externally'));
    await ready(find.textContaining('example.com'));
    await tap(find.text('Stay here'));
    await tap(find.text('Report opportunity'));
    await ready(find.widgetWithText(TextFormField, 'Report details'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Report details'),
      'Synthetic emulator report, not a real allegation.',
    );
    await tap(find.text('Send report'));
    await ready(find.text('Report sent to moderation.'));
    await tap(find.text('View author profile'));
    await ready(find.text('Alumni profile'));
    await tap(find.byTooltip('Back'));
    await homeCareers();
    await tap(find.text('Create opportunity'));
    await ready(find.text('Publish opportunity'));
    final keyword = 'CareerUI ${(fixture['domain'] as String).split(' ').last}';
    final title = '[SYNTHETIC LOCAL] $keyword';
    await enter('title', title);
    await enter(
      'description',
      'Synthetic internship for local emulator acceptance.',
    );
    await enter('organization', 'Synthetic development organization');
    await enter('professional_domain', fixture['domain'] as String);
    await tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Opportunity type'),
    );
    await tap(find.text('Internship').last);
    await tap(find.text('Remote available'));
    await tap(find.text('Referral available'));
    await tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Who can see this?'),
    );
    await tap(find.text('My institution').last);
    final skills = find.widgetWithText(TextField, 'Search required skills');
    await tester.ensureVisible(skills);
    await tester.pumpAndSettle();
    await tester.enterText(skills, fixture['skillName'] as String);
    await tester.pump(const Duration(seconds: 1));
    await tap(find.widgetWithText(ActionChip, fixture['skillName'] as String));
    await tap(find.text('Save draft'));
    await ready(find.text('Opportunity details'));
    expect(find.text('draft'), findsOneWidget);
    expect(find.text('Apply externally'), findsNothing);
    await tap(find.text('Edit opportunity'));
    await ready(find.text('Publish opportunity'));
    await enter('title', 'Updated $title');
    await tap(find.text('Publish opportunity'));
    await ready(find.text('published'));
    await tap(find.byTooltip('Back'));
    await search(keyword);
    await tap(find.text('Internships'));
    await ready(find.text('Updated $title'));
    expect(find.text(fixture['externalTitle'] as String), findsNothing);
    await tap(find.text('View opportunity'));
    await tap(find.text('Close opportunity'));
    await tap(find.text('Confirm'));
    await ready(find.text('closed'));
    await tap(find.text('Archive opportunity'));
    await tap(find.text('Confirm'));
    await ready(find.text('Archived'));
    expect(find.text('Edit opportunity'), findsNothing);
    await tap(find.byTooltip('Back'));
    await tap(find.text('My posts and drafts'));
    await search(keyword);
    await ready(find.text('Updated $title'));
    expect(tester.takeException(), isNull);
    await file.delete();
  });
}
