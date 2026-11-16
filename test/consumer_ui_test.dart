import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:msgi_one/core/widgets/one_widgets.dart';
import 'package:msgi_one/core/widgets/app_logo.dart';
import 'package:msgi_one/core/widgets/consumer_widgets.dart';
import 'package:msgi_one/features/demo/domain/demo_store.dart';
import 'package:msgi_one/features/demo/presentation/demo_experience.dart';
import 'package:msgi_one/core/theme/app_theme.dart';

void main() {
  test('Version-one demo copy upgrades without erasing presenter changes or relationships', () {
    final old = DemoStore()..switchRole(DemoRole.alumni);
    addTearDown(old.dispose);
    old.profiles['demo-alumni-08']!['display_name'] = 'Alumni 08 (Demo)';
    old.profiles['demo-alumni-08']!['company'] = 'Sample Organization 08';
    old.profiles['demo-alumni-01']!['display_name'] = 'Presenter custom name';
    old.connections['demo-link-01']!['status'] = 'accepted';
    old.posts['demo-post-01']!['title'] = 'Presenter custom opening';
    final snapshot = old.snapshot()..['version'] = 1;
    final upgraded = DemoStore.restore(snapshot);
    addTearDown(upgraded.dispose);
    expect(upgraded.person['display_name'], 'Presenter custom name');
    expect(upgraded.profiles['demo-alumni-08']!['display_name'], 'Anika Bose');
    expect(
      upgraded.profiles['demo-alumni-08']!['company'],
      contains('Fictional'),
    );
    expect(upgraded.connections['demo-link-01']!['status'], 'accepted');
    expect(
      upgraded.posts['demo-post-01']!['title'],
      'Presenter custom opening',
    );
    expect(upgraded.role, DemoRole.alumni);
    expect(upgraded.active, true);
    expect(upgraded.snapshot()['version'], DemoStore.version);
  });

  testWidgets(
    'Feed builds rows lazily while retaining scroll access to the end',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PageBody(
              itemCount: 100,
              itemBuilder: (_, i) =>
                  SizedBox(height: 100, child: Text('Lazy row $i')),
              children: const [Text('Community')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lazy row 0'), findsOneWidget);
      expect(find.text('Lazy row 99'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Lazy row 99'),
        600,
        maxScrolls: 30,
      );
      expect(find.text('Lazy row 99'), findsOneWidget);
    },
  );

  testWidgets(
    'Map fills the viewport below search and exposes a draggable accessible city list',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = DemoStore()..switchRole(DemoRole.student);
      addTearDown(store.dispose);
      await tester.pumpWidget(DemoExperience(store: store, onExit: () {}));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      final mapRect = tester.getRect(find.byType(FlutterMap));
      final searchRect = tester.getRect(find.byType(CompactSearch));
      expect(mapRect.width, 390);
      expect(mapRect.height, greaterThan(844 * .55));
      expect(mapRect.top, greaterThanOrEqualTo(searchRect.bottom));
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(find.byTooltip('World view'), findsOneWidget);
      expect(find.byType(TileLayer), findsNothing);
      await tester.tap(find.byTooltip('Expand city list'));
      await tester.pumpAndSettle();
      expect(find.text('London, GB'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Demo header adapts when system text size changes at runtime', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = DemoStore()..switchRole(DemoRole.student);
    addTearDown(store.dispose);
    await tester.pumpWidget(DemoExperience(store: store, onExit: () {}));
    await tester.pumpAndSettle();
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();
    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Demo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Demo discovery query and results survive a bottom-tab round trip',
    (tester) async {
      final store = DemoStore()..switchRole(DemoRole.student);
      addTearDown(store.dispose);
      await tester.pumpWidget(DemoExperience(store: store, onExit: () {}));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('alumni-search')), 'Anika');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      expect(find.text('Anika'), findsOneWidget);
      expect(find.text('Anika Bose'), findsOneWidget);
      expect(find.text('1 alumni loaded'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
