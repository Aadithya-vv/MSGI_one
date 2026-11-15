import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Web Mercator's finite, single projected world. Neither feature layers nor
/// optional tiles may wrap. Uses only flutter_map's public CRS interface.
class SingleWorldMercator extends Crs {
  const SingleWorldMercator() : super(code: 'EPSG:3857', infinite: false);

  static const _mercator = Epsg3857();

  @override
  Projection get projection => _mercator.projection;

  @override
  (double, double) transform(double x, double y, double scale) =>
      _mercator.transform(x, y, scale);

  @override
  (double, double) untransform(double x, double y, double scale) =>
      _mercator.untransform(x, y, scale);

  @override
  (double, double) latLngToXY(LatLng latlng, double scale) =>
      _mercator.latLngToXY(latlng, scale);

  @override
  LatLng offsetToLatLng(Offset point, double zoom) =>
      _mercator.offsetToLatLng(point, zoom);

  @override
  Rect? getProjectedBounds(double zoom) => _mercator.getProjectedBounds(zoom);
}

const mercatorLatitudeLimit = 85.0511287798066;
final singleWorldBounds = LatLngBounds(
  const LatLng(-mercatorLatitudeLimit, -180),
  const LatLng(mercatorLatitudeLimit, 180),
);

double singleWorldMinimumZoom(Size viewport) => math.max(
  0,
  math.log((math.max(1, math.max(viewport.width, viewport.height)) + 2) / 256) /
          math.ln2 +
      .00001,
);

/// Keeps viewport edges inside the world, not just its center. Raises the zoom
/// floor only when required to fit a resized viewport; preserves zoom otherwise.
class SingleWorldCameraConstraint extends CameraConstraint {
  const SingleWorldCameraConstraint();

  @override
  MapCamera? constrain(MapCamera camera) {
    if (camera.nonRotatedSize.width <= 0 || camera.nonRotatedSize.height <= 0) {
      return camera;
    }
    final minimum = singleWorldMinimumZoom(camera.nonRotatedSize);
    final maximum = camera.maxZoom;
    if (maximum != null && minimum > maximum) return null;
    final candidate = camera.zoom < minimum
        ? camera.withPosition(zoom: minimum)
        : camera;
    // flutter_map 8.3 floors the projected center when calculating visible
    // bounds. Fractional Android logical sizes therefore need a one-pixel
    // interior margin, not just a floating-point geographic clamp.
    final pixels = candidate.crs.getProjectedBounds(candidate.zoom)!.deflate(1);
    final interior = LatLngBounds(
      candidate.unprojectAtZoom(pixels.bottomLeft),
      candidate.unprojectAtZoom(pixels.topRight),
    );
    final bounded = CameraConstraint.contain(bounds: interior)
        .constrain(candidate);
    if (bounded != null && bounded.zoom == camera.zoom) {
      final before = camera.projectAtZoom(camera.center);
      final after = bounded.projectAtZoom(bounded.center);
      // Projection round trips can differ by subpixel noise at an edge.
      // Preserve identity there to avoid repeated correction and jitter.
      if ((after - before).distance < .0000001) return camera;
    }
    return bounded;
  }
}

/// Preserve in-range values, including each visible side of the antimeridian.
/// Out-of-range finite longitudes map to their equivalent geographical location.
double singleWorldLongitude(double longitude) {
  if (!longitude.isFinite) throw ArgumentError('Longitude must be finite');
  if (longitude >= -180 && longitude <= 180) return longitude;
  final value = ((longitude + 180) % 360 + 360) % 360 - 180;
  return value == -180 && longitude > 0 ? 180 : value;
}
