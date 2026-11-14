import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:msgi_one/features/demo/presentation/experience_root.dart';
import 'package:msgi_one/features/demo/data/demo_persistence.dart';
import 'package:msgi_one/core/config/production_session.dart';
import 'package:msgi_one/core/config/backend_config.dart';
import 'package:msgi_one/core/config/auth_entry_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScriptedLocalLinks implements AuthEntryLinks {
  ScriptedLocalLinks({this.first});
  final Uri? first;
  final source = StreamController<Uri>.broadcast();
  @override
  Future<Uri?> initial() async => first;
  @override
  Stream<Uri> get events => source.stream;
}

class ObservedProductionSession extends ProductionSession {
  ObservedProductionSession(this.delegate)
    : super(
        delegate.config,
        client: delegate.client,
        error: delegate.error,
        started: delegate.started,
        initializing: delegate.initializing,
      );
  final ProductionSession delegate;
  final stopped = Completer<void>();
  @override
  Future<void> close() async {
    try {
      await delegate.close();
    } finally {
      if (!stopped.isCompleted) stopped.complete();
    }
  }
}

Future<dynamic> localMailJson(String suffix) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:55324$suffix'),
    );
    final response = await request.close();
    return jsonDecode(await utf8.decoder.bind(response).join());
  } finally {
    client.close(force: true);
  }
}

Future<Uri> localRecoveryCallback(String email) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    final box = await localMailJson('/api/v1/messages') as Map;
    for (final m in box['messages'] as List) {
      if (!(m['To'] as List).any((t) => t['Address'] == email)) continue;
      final message = await localMailJson('/api/v1/message/${m['ID']}') as Map;
      for (final match in RegExp(
        'href="([^"]+)"',
      ).allMatches(message['HTML'] as String)) {
        final link = Uri.tryParse(match[1]!.replaceAll('&amp;', '&'));
        if (link == null ||
            link.host != '127.0.0.1' ||
            link.port != 55321 ||
            link.path != '/auth/v1/verify' ||
            link.queryParameters['type'] != 'recovery') {
          continue;
        }
        final client = HttpClient();
        try {
          final request = await client.getUrl(link);
          request.followRedirects = false;
          final response = await request.close();
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>();
          if (location == null) {
            throw StateError('Local recovery redirect missing');
          }
          final uri = Uri.parse(location);
          if (!isProductionAuthEntry(uri)) {
            throw StateError('Unexpected local callback');
          }
          return uri;
        } finally {
          client.close(force: true);
        }
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw StateError('Local recovery email unavailable');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Real local login, demo isolation, session restoration and cold recovery handoff',
    (tester) async {
      if (BackendConfig.fromEnvironment().url != 'http://127.0.0.1:55321' ||
          !const bool.fromEnvironment('LOCAL_AUTH_TESTING')) {
        throw StateError('Isolated local backend required');
      }
      final file = File(
            '/data/user/0/com.msgi.nexus.msgi_nexus/files/task08-auth-fixture.json',
          ),
          fixture = jsonDecode(await file.readAsString()) as Map;
      if (!RegExp(r'^task07-writer-\d+@example.test$')
          .hasMatch(fixture['email'] as String)) {
        throw StateError('Synthetic local account required');
      }
      await SharedPreferencesAsync().remove(PreferencesDemoPersistence.key);
      var openings = 0;
      ObservedProductionSession? latest;
      Future<ProductionSession> open() async {
        openings++;
        return latest = ObservedProductionSession(
          await ProductionSession.fromGateway(),
        );
      }

      final links = ScriptedLocalLinks();
      addTearDown(links.source.close);
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      Future<void> ready(Finder f) async {
        for (var i = 0; i < 150; i++) {
          await tester.pump(const Duration(milliseconds: 150));
          if (f.evaluate().isNotEmpty) return;
        }
        throw StateError('Expected local auth control unavailable');
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

      await tester.pumpWidget(
        ExperienceRoot(links: links, openProduction: open),
      );
      await tap(find.text('Explore Demo'));
      await tap(find.text('Student demo'));
      await ready(find.text('Welcome, Mira Rao (Demo)'));
      expect(openings, 0);
      await tap(find.byTooltip('Demo controls'));
      await tap(find.text('Exit demo'));
      await tap(find.text('Sign in to real community'));
      await ready(find.byKey(const Key('auth-email')));
      expect(openings, 1);
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        fixture['email'] as String,
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        fixture['password'] as String,
      );
      await tap(find.widgetWithText(FilledButton, 'Log in'));
      await ready(find.text('Welcome to your\nMSGI community.'));
      await tap(find.text('Profile'));
      await tap(find.text('Back to welcome'));
      await tap(find.text('Explore Demo'));
      await tap(find.text('Alumni demo'));
      await ready(find.text('Welcome, Arjun Iyer (Demo)'));
      await latest!.stopped.future;
      expect(openings, 1);
      await tap(find.byTooltip('Demo controls'));
      await tap(find.text('Exit demo'));
      await tap(find.text('Sign in to real community'));
      await ready(find.text('Welcome to your\nMSGI community.'));
      expect(openings, 2);
      expect(find.byKey(const Key('auth-password')), findsNothing);
      await tap(find.text('Profile'));
      await tap(find.text('Log out'));
      await ready(find.byKey(const Key('auth-email')));
      await tap(find.text('Forgot password?'));
      await ready(find.text('Send recovery instructions'));
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        fixture['email'] as String,
      );
      await tap(find.text('Send recovery instructions'));
      await ready(find.textContaining('If an account exists'));
      final callback = await localRecoveryCallback(fixture['email'] as String);
      final previous = latest!;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await previous.stopped.future;
      final coldLinks = ScriptedLocalLinks(first: callback);
      addTearDown(coldLinks.source.close);
      await tester.pumpWidget(
        ExperienceRoot(links: coldLinks, openProduction: open),
      );
      await ready(find.text('Choose a new password'));
      final random = Random.secure(),
          newPassword = base64UrlEncode(
            List.generate(24, (_) => random.nextInt(256)),
          );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        newPassword,
      );
      await tester.enterText(
        find.byKey(const Key('auth-confirm')),
        newPassword,
      );
      await tap(find.text('Update password'));
      await ready(find.text('Welcome to your\nMSGI community.'));
      expect(openings, 3);
      await tap(find.text('Profile'));
      await tap(find.text('Log out'));
      await ready(find.byKey(const Key('auth-email')));
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        fixture['email'] as String,
      );
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        newPassword,
      );
      await tap(find.widgetWithText(FilledButton, 'Log in'));
      await ready(find.text('Welcome to your\nMSGI community.'));
      expect(tester.takeException(), isNull);
      await file.delete();
      final last = latest!;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await last.stopped.future;
    },
  );
}
