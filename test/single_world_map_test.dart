import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:msgi_one/features/alumni_map/domain/map_repository.dart';
import 'package:msgi_one/features/alumni_map/presentation/single_world_map.dart';
import 'package:msgi_one/features/alumni_map/presentation/world_geography.dart';

MapCamera camera(
  Size size, {
  LatLng center = const LatLng(0, 0),
  double zoom = 0,
}) => MapCamera(
  crs: const SingleWorldMercator(),
  minZoom: 0,
  maxZoom: 8,
  center: center,
  zoom: zoom,
  rotation: 0,
  nonRotatedSize: size,
);

void expectInsideWorld(MapCamera camera) {
  final bounds = camera.visibleBounds;
  expect(bounds.west, greaterThanOrEqualTo(-180.000001));
  expect(bounds.east, lessThanOrEqualTo(180.000001));
  expect(bounds.south, greaterThanOrEqualTo(-mercatorLatitudeLimit - .000001));
  expect(bounds.north, lessThanOrEqualTo(mercatorLatitudeLimit + .000001));
}

void main() {
  test(
    'Single-world CRS disables both wrapping and replicated feature layers',
    () {
      const crs = SingleWorldMercator();
      expect(crs.wrapLng, isNull);
      expect(crs.wrapLat, isNull);
      expect(crs.infinite, false);
      expect(crs.replicatesWorldLongitude, false);
      for (final point in [
        const LatLng(0, 0),
        const LatLng(85, 179.9),
        const LatLng(-85, -179.9),
      ]) {
        expect(
          crs.latLngToOffset(point, 3),
          const Epsg3857().latLngToOffset(point, 3),
        );
      }
    },
  );

  for (final size in [
    const Size(320, 640),
    const Size(393, 700),
    const Size(840, 390),
    const Size(1440, 900),
    const Size(392.7272727, 535.6363636),
    const Size(785.4545454, 238.1818181),
  ]) {
    test('World contains viewport at minimum zoom and both edges: $size', () {
      const constraint = SingleWorldCameraConstraint();
      for (final point in [const LatLng(0, -540), const LatLng(0, 540)]) {
        final bounded = constraint.constrain(camera(size, center: point))!;
        expectInsideWorld(bounded);
        expect(
          bounded.zoom,
          greaterThanOrEqualTo(singleWorldMinimumZoom(size)),
        );
        expect(bounded.center.longitude.sign, point.longitude.sign);
        expect(constraint.constrain(bounded), same(bounded));
      }
    });
  }

  test(
    'Zoomed-in vertical movement remains available and polar edges stop',
    () {
      const constraint = SingleWorldCameraConstraint();
      final middle = constraint.constrain(
        camera(const Size(320, 640), center: const LatLng(30, 20), zoom: 4),
      )!;
      expect(middle.center, const LatLng(30, 20));
      expect(middle.zoom, 4);
      for (final lat in [-89.0, 89.0]) {
        expectInsideWorld(
          constraint.constrain(
            camera(const Size(320, 640), center: LatLng(lat, 20), zoom: 4),
          )!,
        );
      }
    },
  );

  test(
    'Resize and zoom-out retain a bounded camera without resetting longitude',
    () {
      const constraint = SingleWorldCameraConstraint();
      final first = constraint.constrain(
        camera(const Size(320, 640), center: const LatLng(0, 170), zoom: 3),
      )!;
      final rotated = constraint.constrain(
        first.withNonRotatedSize(const Size(950, 390)),
      )!;
      expectInsideWorld(rotated);
      expect(rotated.zoom, first.zoom);
      expect(rotated.center.longitude, greaterThan(0));
      expectInsideWorld(constraint.constrain(rotated.withPosition(zoom: 0))!);
    },
  );

  test(
    'Antimeridian cities stay at their actual edges, not averaged at Greenwich',
    () {
      const east = CityCluster(
        id: 'east',
        name: 'Synthetic east',
        country: 'XX',
        latitude: 10,
        longitude: 179.9,
        count: 1,
      );
      const west = CityCluster(
        id: 'west',
        name: 'Synthetic west',
        country: 'XX',
        latitude: 10,
        longitude: -179.9,
        count: 1,
      );
      final groups = groupCities([east, west], 1);
      expect(groups, hasLength(2));
      expect(
        groups.map((g) => g.center.longitude),
        containsAll([179.9, -179.9]),
      );
      expect(singleWorldLongitude(180), 180);
      expect(singleWorldLongitude(-180), -180);
      expect(singleWorldLongitude(540), 180);
      expect(singleWorldLongitude(-540), -180);
      expect(singleWorldLongitude(181), -179);
      expect(() => singleWorldLongitude(double.nan), throwsArgumentError);
    },
  );

  test('Malformed coordinates do not create an invalid marker/camera', () {
    final groups = groupCities([
      const CityCluster(
        id: 'bad',
        name: 'Synthetic invalid',
        country: 'XX',
        latitude: double.nan,
        longitude: 20,
        count: 1,
      ),
      const CityCluster(
        id: 'bad2',
        name: 'Synthetic invalid',
        country: 'XX',
        latitude: 95,
        longitude: 20,
        count: 1,
      ),
    ], 2);
    expect(groups, isEmpty);
  });
}
