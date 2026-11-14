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

  testWidgets('Local personalized mentor and connection acceptance', (
    tester,
  ) async {
    final config = BackendConfig.fromEnvironment();
    if (config.url != 'http://127.0.0.1:55321' ||
        !const bool.fromEnvironment('LOCAL_AUTH_TESTING')) {
      throw StateError('Isolated local build required');
    }
    final file = File(
      '/data/user/0/com.msgi.nexus.msgi_nexus/files/task06-mentor-fixture.json',
    );
    final fixture =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (!RegExp(r'^task06-student-\d+@example.test$')
        .hasMatch(fixture['email'] as String)) {
      throw StateError('Synthetic local account required');
    }
    await app.startProduction();
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
    await tap(find.text('Find a mentor'));
    await ready(find.text('Mentor recommendations'));
    final domain = fixture['domain'] as String;
    final peer = fixture['peerName'] as String;
    Future<void> filter() async {
      await ready(find.widgetWithText(TextField, 'Filter mentor domain'));
      await tester.ensureVisible(
        find.widgetWithText(TextField, 'Filter mentor domain'),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Filter mentor domain'),
        domain,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tap(find.text('Refine recommendations'));
      await tap(find.text('Refresh recommendations'));
      await ready(find.text(peer));
    }

    await filter();
    expect(find.text('100 / 100 relevance'), findsOneWidget);
    expect(find.text('Works in your target domain: $domain'), findsOneWidget);
    await tap(find.text('Personalize your goals'));
    await ready(find.widgetWithText(TextFormField, 'Mentorship objectives'));
    await tester.ensureVisible(
      find.widgetWithText(TextFormField, 'Mentorship objectives'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mentorship objectives'),
      'Career planning, Portfolio feedback',
    );
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Mentorship objectives'),
          )
          .controller!
          .text,
      'Career planning, Portfolio feedback',
    );
    await tap(find.text('Skills to learn'));
    await ready(find.widgetWithText(TextField, 'Search Skills to learn'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Search Skills to learn'),
      'Mentor skill ${domain.split(' ').last}',
    );
    await tester.pump(const Duration(seconds: 1));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Mentorship objectives'),
          )
          .controller!
          .text,
      'Career planning, Portfolio feedback',
    );
    await tap(find.text('Save goals'));
    await ready(find.text('Mentor recommendations'));
    await tap(find.text('Personalize your goals'));
    final objectives = find.widgetWithText(
      TextFormField,
      'Mentorship objectives',
    );
    await ready(objectives);
    expect(
      tester
          .widget<TextFormField>(objectives)
          .controller!
          .text
          .split(',')
          .map((s) => s.trim()),
      unorderedEquals(['Career planning', 'Portfolio feedback']),
    );
    await tap(find.byTooltip('Back'));
    await ready(find.text('Mentor recommendations'));
    await filter();
    await tap(find.text('View mentor profile'));
    await ready(find.text('Alumni profile'));
    await tap(find.text('Connect'));
    await ready(find.text('Request sent'));
    await tap(find.byTooltip('Back'));
    await tap(find.text('Home'));
    await tap(find.text('Find a mentor'));
    await ready(find.text('Mentor recommendations'));
    await filter();
    await ready(find.text('Relationship: pending'));
    await tap(find.text('Cancel request'));
    await ready(find.text('Previous connection closed'));
    expect(tester.takeException(), isNull);
    await file.delete();
  });
}
