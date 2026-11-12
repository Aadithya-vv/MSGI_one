import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:msgi_one/app.dart';
import 'package:msgi_one/core/routing/app_router.dart';
import 'package:msgi_one/core/routing/app_routes.dart';

Future<void> pumpRoute(
  WidgetTester tester,
  String path, {
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = createAppRouter(initialLocation: path);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appRouterProvider.overrideWithValue(router)],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: const OneApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(router.dispose);
}

void main() {
  testWidgets('current branding appears on startup and the application shell', (
    tester,
  ) async {
    await pumpRoute(tester, AppRoutes.startup);
    expect(find.text('MSGI One'), findsOneWidget);
    expect(find.text('One Community. Infinite Connections.'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'MSGI One',
    );
    await pumpRoute(tester, AppRoutes.home);
    expect(find.text('MSGI One'), findsOneWidget);
  });

  const screens = {
    AppRoutes.startup: 'Get started',
    AppRoutes.welcome: 'Your next chapter\nstarts with a connection.',
    AppRoutes.login: 'Welcome back',
    AppRoutes.signup: 'Join MSGI One',
    AppRoutes.home: 'Welcome to your\nMSGI community.',
    AppRoutes.discover: 'Discover alumni',
    AppRoutes.map: 'Global alumni map',
    AppRoutes.network: 'My network',
    AppRoutes.profile: 'Your profile',
    AppRoutes.mentors: 'Mentor recommendations',
    AppRoutes.opportunities: 'Career opportunities',
  };

  for (final screen in screens.entries) {
    testWidgets('route ${screen.key} is reachable', (tester) async {
      await pumpRoute(tester, screen.key);
      expect(find.text(screen.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('startup reaches welcome and explicitly opens sample dashboard', (
    tester,
  ) async {
    await pumpRoute(tester, AppRoutes.startup);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Explore sample dashboard'));
    await tester.tap(find.text('Explore sample dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('SAMPLE PREVIEW'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('bottom navigation reaches all five destinations', (
    tester,
  ) async {
    await pumpRoute(tester, AppRoutes.home);
    for (final destination in const {
      'Discover': 'Discover alumni',
      'Map': 'Global alumni map',
      'Network': 'My network',
      'Profile': 'Your profile',
      'Home': 'Welcome to your\nMSGI community.',
    }.entries) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(destination.key),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(destination.value), findsOneWidget);
    }
  });

  testWidgets('search filters samples and shows a useful empty state', (
    tester,
  ) async {
    await pumpRoute(tester, AppRoutes.discover);
    await tester.enterText(find.byKey(const Key('alumni-search')), 'pUnE');
    await tester.pumpAndSettle();
    expect(find.text('Sample alumna B'), findsOneWidget);
    expect(find.text('Sample alumnus A'), findsNothing);
    await tester.enterText(find.byKey(const Key('alumni-search')), 'no-match');
    await tester.pumpAndSettle();
    expect(find.text('No sample matches'), findsOneWidget);
  });

  testWidgets('home mentor and opportunity cards navigate', (tester) async {
    for (final destination in const {
      'Find a mentor': 'Mentor recommendations',
      'Career opportunities': 'Career opportunities',
    }.entries) {
      await pumpRoute(tester, AppRoutes.home);
      await tester.ensureVisible(find.text(destination.key));
      await tester.tap(find.text(destination.key));
      await tester.pumpAndSettle();
      expect(find.text(destination.value), findsOneWidget);
    }
  });

  testWidgets('auth previews collect no credentials', (tester) async {
    await pumpRoute(tester, AppRoutes.login);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.enabled, isFalse);
    }
    expect(
      find.textContaining('No credentials are collected or sent.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('View signup preview'));
    await tester.tap(find.text('View signup preview'));
    await tester.pumpAndSettle();
    expect(find.text('Join MSGI One'), findsOneWidget);
  });

  testWidgets('unknown routes show a recoverable safe error', (tester) async {
    await pumpRoute(tester, '/missing-page');
    expect(find.text('This page could not be found.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsOneWidget);
  });

  for (final width in [320.0, 390.0, 840.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('all screens fit width $width at text scale $scale', (
        tester,
      ) async {
        for (final route in screens.keys) {
          await pumpRoute(tester, route, width: width, scale: scale);
          expect(
            MediaQuery.textScalerOf(tester.element(find.byType(Scaffold).first))
                .scale(10),
            scale * 10,
          );
          // Unhandled rendering exceptions fail the test with full diagnostics.
        }
      });
    }
  }
}
