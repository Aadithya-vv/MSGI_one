import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:msgi_one/main.dart' as app;
import 'package:msgi_one/core/config/backend_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Local map and professional connection acceptance', (
    tester,
  ) async {
    final config = BackendConfig.fromEnvironment();
    if (config.url != 'http://127.0.0.1:55321' ||
        !const bool.fromEnvironment('LOCAL_AUTH_TESTING')) {
      throw StateError('Isolated local build required');
    }
    final file = File(
      '/data/user/0/com.msgi.nexus.msgi_nexus/files/task05-network-fixture.json',
    );
    final fixture =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (!RegExp(r'^task05-viewer-\d+@example.test$')
        .hasMatch(fixture['email'] as String)) {
      throw StateError('Synthetic local account required');
    }
    await app.startProduction();
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
    await tap(find.text('Map'));
    await ready(find.byType(FlutterMap));
    final city = fixture['cityName'] as String;
    final peer = fixture['peerName'] as String;
    await tester.enterText(
      find.widgetWithText(TextField, 'City or country'),
      city.split(' ').last,
    );
    await tap(find.byTooltip('Filters'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Professional domain'),
      'Research',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tap(find.text('Filter map'));
    await ready(find.byTooltip(city));
    expect(find.byType(TileLayer), findsNothing);
    await tap(find.byTooltip('Zoom in'));
    await tap(find.byTooltip('Zoom out'));
    await tap(find.byTooltip('World view'));
    await tester.drag(find.byType(FlutterMap), const Offset(45, 20));
    await tester.pumpAndSettle();
    await tap(find.byTooltip('World view'));
    await tap(find.byTooltip(city));
    await ready(find.text(peer));
    await tap(find.text(peer));
    await ready(find.text('Alumni profile'));
    await tap(find.text('Accept'));
    await ready(find.text('Connected'));
    await tap(find.byTooltip('Back'));
    await tap(find.text('Network'));
    await ready(find.text(peer));
    await tap(find.text('Remove connection'));
    await tap(find.text('Remove'));
    await ready(find.text('No connections yet'));

    await tap(find.text('Map'));
    // Route recreation can clear filters, so apply this fixture's location again.
    await ready(find.widgetWithText(TextField, 'City or country'));
    await tester.enterText(
      find.widgetWithText(TextField, 'City or country'),
      city.split(' ').last,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tap(find.text('Filter map'));
    await ready(find.byTooltip(city));
    await tap(find.byTooltip(city));
    await ready(find.text(peer));
    await tap(find.text(peer));
    await tap(find.text('Connect'));
    await ready(find.text('Request sent'));
    await tap(find.byTooltip('Back'));
    await tap(find.text('Network'));
    await tap(find.text('Outgoing'));
    await tap(find.text('Cancel request'));
    await ready(find.text('No outgoing requests yet'));
    expect(tester.takeException(), isNull);
    await file.delete();
  });
}
