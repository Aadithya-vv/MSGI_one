import 'dart:io';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:msgi_one/features/demo/presentation/experience_root.dart';
import 'package:msgi_one/features/demo/data/demo_persistence.dart';
import 'package:msgi_one/features/alumni_map/presentation/single_world_map.dart';

import 'demo_experience_test.dart' as journeys;

void main() {
  journeys.main();
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Single-world map edges, zoom, markers and honest branding offline',
    (tester) async {
      final prefs = SharedPreferencesAsync();
      final original = await prefs.getString(PreferencesDemoPersistence.key);
      await prefs.remove(journeys.AcceptancePersistence.key);
      final oldHttp = HttpOverrides.current, http = journeys.OfflineDemoHttp();
      HttpOverrides.global = http;
      addTearDown(() async {
        HttpOverrides.global = oldHttp;
        expect(await prefs.getString(PreferencesDemoPersistence.key), original);
        await prefs.remove(journeys.AcceptancePersistence.key);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      runApp(ExperienceRoot(persistence: journeys.AcceptancePersistence()));
      Future<void> ready(Finder finder) async {
        for (var i = 0; i < 100; i++) {
          await tester.pump(const Duration(milliseconds: 150));
          if (finder.evaluate().isNotEmpty) return;
        }
        throw StateError('Expected local demo control unavailable');
      }

      Future<void> tap(Finder finder) async {
        await ready(finder);
        await tester.ensureVisible(finder.first);
        await tester.pumpAndSettle();
        await tester.tap(finder.first);
        await tester.pumpAndSettle();
      }

      await ready(find.text('Explore Demo'));
      expect(find.textContaining('Meenakshi Sundararajan'), findsOneWidget);
      expect(find.textContaining('placeholder'), findsNothing);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('task12b_welcome');
      await tap(find.text('Explore Demo'));
      await tap(find.text('Student demo'));
      await tap(find.text('Map'));
      await ready(find.byType(FlutterMap));
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      void bounded() {
        final bounds = controller.camera.visibleBounds;
        expect(bounds.west, greaterThanOrEqualTo(-180.000001));
        expect(bounds.east, lessThanOrEqualTo(180.000001));
        expect(
          bounds.north,
          lessThanOrEqualTo(mercatorLatitudeLimit + .000001),
        );
        expect(
          bounds.south,
          greaterThanOrEqualTo(-mercatorLatitudeLimit - .000001),
        );
        expect(controller.camera.crs.replicatesWorldLongitude, false);
        expect(controller.camera.crs.wrapLng, isNull);
      }

      for (final edge in [-1000.0, 1000.0]) {
        controller.move(LatLng(0, edge), 0);
        await tester.pumpAndSettle();
        bounded();
        await tester.fling(
          find.byType(FlutterMap),
          Offset(edge.sign * 2500, 0),
          2500,
        );
        await tester.pumpAndSettle();
        bounded();
        await binding.takeScreenshot(
          edge < 0 ? 'task12b_west_edge' : 'task12b_east_edge',
        );
      }
      final oldZoom = controller.camera.zoom;
      await tap(find.byTooltip('Zoom in'));
      bounded();
      expect(controller.camera.zoom, greaterThan(oldZoom));
      controller.move(const LatLng(30, 0), 4);
      await tester.pumpAndSettle();
      bounded();
      expect(controller.camera.center.latitude, closeTo(30, .00001));
      controller.move(const LatLng(51.5, -.12), 4);
      await tester.pumpAndSettle();
      await tap(find.byTooltip('London'));
      await ready(find.text('London alumni'));
      await binding.takeScreenshot('task12b_city_interaction');
      expect(http.attempts, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
