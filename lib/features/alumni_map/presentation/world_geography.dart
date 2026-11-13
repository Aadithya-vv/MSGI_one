import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/map_repository.dart';

final landPolygonsProvider = FutureProvider<List<Polygon>>((ref) async {
  final json = jsonDecode(
    await rootBundle.loadString('assets/maps/ne_110m_land.geojson'),
  ) as Map<String, dynamic>;
  final result = <Polygon>[];
  for (final feature in json['features'] as List) {
    final geometry = feature['geometry'];
    final coordinates = geometry['coordinates'] as List;
    final polygons = geometry['type'] == 'Polygon'
        ? [coordinates]
        : coordinates;
    for (final polygon in polygons) {
      final ring = polygon[0] as List;
      result.add(
        Polygon(
          points: ring
              .map(
                (c) => LatLng(
                  (c[1] as num).toDouble().clamp(-85, 85),
                  (c[0] as num).toDouble(),
                ),
              )
              .toList(),
          color: const Color(0xFFD9E4D9),
          borderColor: const Color(0xFF8AA2A2),
          borderStrokeWidth: 0.5,
        ),
      );
    }
  }
  return result;
});

class CityMarkerGroup {
  CityMarkerGroup(this.cities);
  final List<CityCluster> cities;
  int get count => cities.fold(0, (n, c) => n + c.count);
  LatLng get center => LatLng(
    cities.map((c) => c.latitude).reduce((a, b) => a + b) / cities.length,
    cities.map((c) => c.longitude).reduce((a, b) => a + b) / cities.length,
  );
}

List<CityMarkerGroup> groupCities(List<CityCluster> cities, double zoom) {
  final buckets = <String, List<CityCluster>>{};
  final scale = 256 * math.pow(2, zoom);
  for (final c in cities) {
    final sin = math.sin(c.latitude.clamp(-85, 85) * math.pi / 180);
    final x = (c.longitude + 180) / 360 * scale;
    final y = (0.5 - math.log((1 + sin) / (1 - sin)) / (4 * math.pi)) * scale;
    final key = '${(x / 64).floor()}:${(y / 64).floor()}';
    buckets.putIfAbsent(key, () => []).add(c);
  }
  return buckets.values.map(CityMarkerGroup.new).toList();
}
