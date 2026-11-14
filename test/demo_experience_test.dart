import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:msgi_one/features/demo/presentation/experience_root.dart';
import 'package:msgi_one/features/demo/presentation/demo_experience.dart';
import 'package:msgi_one/features/demo/domain/demo_store.dart';
import 'package:msgi_one/core/config/production_session.dart';
import 'package:msgi_one/core/config/backend_config.dart';
import 'package:msgi_one/core/config/auth_entry_links.dart';

import 'helpers/demo_test_support.dart';

Future<void> demoTap(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final f = find.text(text).first;
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> chooseRole(WidgetTester tester, String role) async {
  await tester.tap(find.byType(DropdownButton<DemoRole>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(role).last);
  await tester.pumpAndSettle();
}

Future<MemoryDemoPersistence> enterDemo(
  WidgetTester tester, {
  MemoryDemoPersistence? storage,
  String role = 'Student demo',
}) async {
  final p = storage ?? MemoryDemoPersistence(), links = TestAuthEntryLinks();
  addTearDown(links.close);
  await tester.pumpWidget(
    ExperienceRoot(
      key: UniqueKey(),
      persistence: p,
      links: links,
      openProduction: () async =>
          throw StateError('Demo must never initialize production'),
    ),
  );
  await tester.pumpAndSettle();
  await demoTap(tester, 'Explore Demo');
  await demoTap(tester, role);
  return p;
}

class RecordingProduction extends ProductionSession {
  RecordingProduction() : super(BackendConfig.fromEnvironment());
  int callbacks = 0, closed = 0;
  bool rejectCallback = false;
  @override
  Future<void> handleAuthEntry(Uri uri) async {
    callbacks++;
    if (rejectCallback) throw StateError('Synthetic expired link');
  }

  @override
  Future<void> close() async {
    closed++;
  }
}

void main() {
  testWidgets(
    'Cold auth callbacks are handed off once without restoring a demo role as authorization',
    (tester) async {
      final s = DemoStore()..switchRole(DemoRole.staff),
          p = MemoryDemoPersistence(),
          session = RecordingProduction();
      p.value = s.snapshot();
      final links = TestAuthEntryLinks(
        first: Uri.parse(
          'com.msgi.one.dev://auth-callback/?code=synthetic-cold-code',
        ),
      );
      addTearDown(links.close);
      addTearDown(s.dispose);
      await tester.pumpWidget(
        ExperienceRoot(
          persistence: p,
          links: links,
          openProduction: () async => session,
        ),
      );
      await tester.pumpAndSettle();
      expect(session.callbacks, 1);
      expect(find.text('Development setup required'), findsOneWidget);
      expect(find.text('Demo'), findsNothing);
    },
  );
  testWidgets('Invalid real callback validation closes protected UI', (
    tester,
  ) async {
    final session = RecordingProduction()..rejectCallback = true,
        links = TestAuthEntryLinks(
          first: Uri.parse(
            'com.msgi.one.dev://auth-callback/?code=synthetic-expired-code',
          ),
        );
    addTearDown(links.close);
    await tester.pumpWidget(
      ExperienceRoot(
        persistence: MemoryDemoPersistence(),
        links: links,
        openProduction: () async => session,
      ),
    );
    await tester.pumpAndSettle();
    expect(session.callbacks, 1);
    expect(find.text('Access check unavailable'), findsOneWidget);
  });
  testWidgets(
    'Fictional profile edits persist without invented verification labels',
    (tester) async {
      final p = await enterDemo(tester, role: 'Alumni demo');
      await demoTap(tester, 'Profile');
      await demoTap(tester, 'Edit demo profile');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Demo display name'),
        'Fictional Presenter',
      );
      await demoTap(tester, 'Save demo profile');
      expect(find.text('Fictional Presenter (Demo)'), findsOneWidget);
      expect(
        (p.value?['profiles'] as Map)['demo-alumni-01']['display_name'],
        'Fictional Presenter (Demo)',
      );
      expect(find.text('VERIFIED ALUMNI'), findsNothing);
    },
  );
  testWidgets(
    'Demo role controls and home fit a narrow phone with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = DemoStore()..switchRole(DemoRole.staff);
      addTearDown(s.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: DemoExperience(store: s, onExit: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Demo'), findsOneWidget);
      // Let the test binding report full layout diagnostics.
    },
  );
  test(
    'Only the exact Android auth callback can enter real authentication',
    () {
      expect(
        isProductionAuthEntry(
          Uri.parse('com.msgi.one.dev://auth-callback/?code=synthetic'),
        ),
        true,
      );
      for (final s in [
        'https://example.com/auth-callback',
        'com.other.app://auth-callback/',
        'com.msgi.one.dev://auth-callback.evil/',
        'com.msgi.one.dev://auth-callback/admin',
      ]) {
        expect(isProductionAuthEntry(Uri.parse(s)), false);
      }
    },
  );
  testWidgets(
    'Demo entry needs no account, backend configuration or authentication',
    (tester) async {
      final p = await enterDemo(tester);
      expect(find.text('Demo'), findsOneWidget);
      expect(find.text('Welcome, Mira Rao (Demo)'), findsOneWidget);
      expect(find.text('Log in'), findsNothing);
      expect(find.text('VERIFIED ALUMNI'), findsNothing);
      expect(p.value?['active'], true);
    },
  );
  testWidgets(
    'Student journey discovers mentors, requests connections and sees offline map',
    (tester) async {
      await enterDemo(tester);
      await demoTap(tester, 'Discover alumni');
      await tester.enterText(
        find.byKey(const Key('alumni-search')),
        'Alumni 08',
      );
      await demoTap(tester, 'Search alumni');
      await demoTap(tester, 'Alumni 08 (Demo)');
      expect(find.text('FICTIONAL DEMONSTRATION PROFILE'), findsOneWidget);
      await demoTap(tester, 'Connect');
      expect(find.text('Request sent'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await demoTap(tester, 'Home');
      await demoTap(tester, 'Find a mentor');
      expect(find.text('Mentor recommendations'), findsOneWidget);
      expect(find.text('100 / 100 relevance'), findsWidgets);
      await demoTap(tester, 'Home');
      await demoTap(tester, 'Career Bridge');
      await demoTap(tester, 'Internships');
      expect(find.textContaining('internship'), findsWidgets);
      await demoTap(tester, 'Map');
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TileLayer), findsNothing);
      final marker = find.byTooltip('London');
      await tester.ensureVisible(marker);
      await tester.tap(marker);
      await tester.pumpAndSettle();
      expect(find.textContaining('London alumni'), findsOneWidget);
    },
  );
  testWidgets(
    'Role switching preserves simulated requests without administrator actions',
    (tester) async {
      final p = await enterDemo(tester);
      await chooseRole(tester, 'Alumni');
      expect(find.text('Welcome, Arjun Iyer (Demo)'), findsOneWidget);
      await demoTap(tester, 'Network');
      await demoTap(tester, 'Incoming');
      await demoTap(tester, 'Accept');
      expect(
        (p.value?['connections'] as Map)['demo-link-01']['status'],
        'accepted',
      );
      await demoTap(tester, 'Profile');
      expect(find.text('Demo mentoring availability'), findsOneWidget);
      await demoTap(tester, 'Demo mentoring availability');
      expect(
        (p.value?['profiles'] as Map)['demo-alumni-01']['mentoring'],
        false,
      );
      await chooseRole(tester, 'Staff / Faculty');
      await demoTap(tester, 'Students and faculty');
      await demoTap(tester, 'student');
      await demoTap(tester, 'View sample profile');
      expect(find.text('Sample student profile'), findsOneWidget);
      expect(find.text('Review memberships'), findsNothing);
    },
  );
  testWidgets(
    'Demo career creation is functional and shared across perspectives',
    (tester) async {
      final p = await enterDemo(tester, role: 'Alumni demo');
      await demoTap(tester, 'Career Bridge');
      await demoTap(tester, 'Create opportunity');
      await tester.enterText(
        find.byKey(const Key('career-title')),
        'Fictional competition internship',
      );
      await tester.enterText(
        find.byKey(const Key('career-description')),
        'A simulated learning project, not a real vacancy.',
      );
      await demoTap(tester, 'Publish opportunity');
      expect(find.text('Opportunity details'), findsOneWidget);
      expect((p.value?['posts'] as Map).length, 13);
      await chooseRole(tester, 'Student');
      await demoTap(tester, 'Career Bridge');
      await tester.enterText(
        find.widgetWithText(TextField, 'Search opportunities'),
        'Fictional competition',
      );
      await demoTap(tester, 'Search Career Bridge');
      expect(find.text('Fictional competition internship'), findsOneWidget);
    },
  );
  testWidgets('Demo reset restores fixtures and leaves the entry usable', (
    tester,
  ) async {
    final p = await enterDemo(tester, role: 'Alumni demo');
    await demoTap(tester, 'Profile');
    await demoTap(tester, 'Demo mentoring availability');
    await tester.tap(find.byTooltip('Demo controls'));
    await tester.pumpAndSettle();
    await demoTap(tester, 'Reset demo');
    await demoTap(tester, 'Reset demo');
    expect(find.text('Welcome, Mira Rao (Demo)'), findsOneWidget);
    expect((p.value?['profiles'] as Map)['demo-alumni-01']['mentoring'], true);
    expect((p.value?['posts'] as Map).length, 12);
  });
  testWidgets(
    'Demo session restores the selected role and simulated mutations',
    (tester) async {
      final p = await enterDemo(tester, role: 'Alumni demo');
      await demoTap(tester, 'Profile');
      await demoTap(tester, 'Demo mentoring availability');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final links = TestAuthEntryLinks();
      addTearDown(links.close);
      await tester.pumpWidget(
        ExperienceRoot(
          persistence: p,
          links: links,
          openProduction: () async => throw StateError('No backend'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome, Arjun Iyer (Demo)'), findsOneWidget);
      await demoTap(tester, 'Profile');
      final toggle = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Demo mentoring availability'),
      );
      expect(toggle.value, false);
    },
  );
  testWidgets('Demo works with all Dart HTTP creation prohibited', (
    tester,
  ) async {
    final old = HttpOverrides.current, http = RejectDemoHttp();
    HttpOverrides.global = http;
    addTearDown(() => HttpOverrides.global = old);
    await enterDemo(tester);
    await demoTap(tester, 'Find a mentor');
    await demoTap(tester, 'Home');
    await demoTap(tester, 'Career Bridge');
    await demoTap(tester, 'Map');
    expect(http.requests, 0);
  });
  testWidgets(
    'Only an explicit real-community choice initializes the real backend',
    (tester) async {
      final links = TestAuthEntryLinks(),
          p = MemoryDemoPersistence(),
          session = RecordingProduction();
      addTearDown(links.close);
      var calls = 0;
      await tester.pumpWidget(
        ExperienceRoot(
          persistence: p,
          links: links,
          openProduction: () async {
            calls++;
            return session;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      await demoTap(tester, 'Sign in to real community');
      expect(calls, 1);
      expect(find.text('Development setup required'), findsOneWidget);
      await demoTap(tester, 'Explore Demo');
      await demoTap(tester, 'Staff / Faculty demo');
      expect(session.closed, 1);
      expect(calls, 1);
      expect(find.text('Demo'), findsOneWidget);
    },
  );
  testWidgets(
    'Explicit auth callbacks leave demo and reach real callback handling',
    (tester) async {
      final links = TestAuthEntryLinks(),
          p = MemoryDemoPersistence(),
          session = RecordingProduction();
      addTearDown(links.close);
      var calls = 0;
      await tester.pumpWidget(
        ExperienceRoot(
          persistence: p,
          links: links,
          openProduction: () async {
            calls++;
            expect(find.byType(DemoExperience), findsNothing);
            return session;
          },
        ),
      );
      await tester.pumpAndSettle();
      await demoTap(tester, 'Explore Demo');
      await demoTap(tester, 'Student demo');
      links.controller.add(Uri.parse('https://unrelated.example/demo'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      links.controller.add(
        Uri.parse('com.msgi.one.dev://auth-callback/?code=synthetic-test-code'),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(session.callbacks, 1);
      expect(find.text('Demo'), findsNothing);
    },
  );
  testWidgets('Unavailable local storage does not prevent a memory-only demo', (
    tester,
  ) async {
    final p = MemoryDemoPersistence()..fail = true;
    await enterDemo(tester, storage: p);
    expect(find.textContaining('This session stays in memory'), findsOneWidget);
    expect(find.text('Welcome, Mira Rao (Demo)'), findsOneWidget);
  });
}
