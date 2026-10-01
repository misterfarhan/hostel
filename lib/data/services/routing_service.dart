import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/utils/geo.dart';

class RouteInfo {
  const RouteInfo({required this.points, required this.distanceKm, required this.duration, required this.isEstimate});

  final List<LatLng> points;
  final double distanceKm;
  final Duration duration;

  /// True when the routing API was unreachable and we fell back to a
  /// straight line with an estimated ETA.
  final bool isEstimate;
}

/// Road routing via OSRM. The public demo server is fine for development;
/// use Google Directions, Mapbox Directions or a self-hosted OSRM in
/// production.
class RoutingService {
  RoutingService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<RouteInfo> route(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = body['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final r = routes.first as Map<String, dynamic>;
          final coords = (r['geometry']['coordinates'] as List).map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
          return RouteInfo(
            points: coords,
            distanceKm: (r['distance'] as num).toDouble() / 1000,
            duration: Duration(seconds: (r['duration'] as num).round()),
            isEstimate: false,
          );
        }
      }
    } catch (_) {
      // Fall through to the straight-line estimate.
    }
    final km = Geo.distanceKm(from, to);
    return RouteInfo(points: [from, to], distanceKm: km, duration: Geo.estimateEta(km), isEstimate: true);
  }
}
