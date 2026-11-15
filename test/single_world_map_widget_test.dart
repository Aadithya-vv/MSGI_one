import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:msgi_one/features/alumni_map/data/map_providers.dart';
import 'package:msgi_one/features/alumni_map/presentation/alumni_map_screen.dart';
import 'package:msgi_one/features/alumni_map/presentation/single_world_map.dart';
import 'package:msgi_one/features/alumni_map/presentation/world_geography.dart';

import 'helpers/fake_network_repositories.dart';
import 'single_world_map_test.dart' show expectInsideWorld;

void main() {
  testWidgets(
    'Actual map stops at horizontal edges, zooms and survives resize',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 780);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alumniMapRepositoryProvider.overrideWithValue(
              FakeAlumniMapRepository(),
            ),
            landPolygonsProvider.overrideWith(
              (_) async => [
                Polygon(
                  points: const [
                    LatLng(-10, -10),
                    LatLng(-10, 10),
                    LatLng(10, 10),
                    LatLng(10, -10),
                  ],
                  color: Colors.green,
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AlumniMapScreen(enableNetworkTiles: false)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      final controller = map.mapController!;
      expect(map.options.crs, isA<SingleWorldMercator>());
      expect(
        tester
            .widget<PolygonLayer>(find.byType(PolygonLayer))
            .drawInSingleWorld,
        true,
      );
      expectInsideWorld(controller.camera);
      controller.move(const LatLng(0, 500), 3);
      await tester.pumpAndSettle();
      expectInsideWorld(controller.camera);
      expect(controller.camera.center.longitude, greaterThan(0));
      await tester.drag(find.byType(FlutterMap), const Offset(-2000, 0));
      await tester.pumpAndSettle();
      expectInsideWorld(controller.camera);
      await tester.tap(find.byTooltip('Zoom out'));
      await tester.pumpAndSettle();
      expectInsideWorld(controller.camera);
      tester.view.physicalSize = const Size(950, 390);
      await tester.pumpAndSettle();
      expectInsideWorld(controller.camera);
      controller.move(const LatLng(0, -500), 0);
      await tester.pumpAndSettle();
      expectInsideWorld(controller.camera);
      expect(controller.camera.center.longitude, lessThan(0));
      expect(tester.takeException(), isNull);
    },
  );
}
