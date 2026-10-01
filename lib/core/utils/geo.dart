import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../data/models/location.dart';

/// Geo helpers. The backend does the authoritative radius query with PostGIS
/// `ST_DWithin`; the app uses the same Haversine maths for instant feedback
/// while the seeker drags the radius slider.
abstract final class Geo {
  static const _earthRadiusM = 6371000.0;
  static const kmPerMile = 1.609344;

  static double distanceMeters(LatLng a, LatLng b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) + math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * _earthRadiusM * math.asin(math.sqrt(h));
  }

  static double distanceKm(LatLng a, LatLng b) => distanceMeters(a, b) / 1000;

  static bool withinRadius(LatLng center, LatLng point, double radiusKm) => distanceMeters(center, point) <= radiusKm * 1000;

  /// Rough urban ETA from straight-line distance, used until the routing API
  /// answers. Assumes ~1.3x detour factor and ~22 km/h average city speed.
  static Duration estimateEta(double straightKm) {
    final minutes = (straightKm * 1.3 / 22 * 60).clamp(1, 24 * 60).round();
    return Duration(minutes: minutes);
  }

  /// Point at [distanceKm] and [bearingDeg] from [from] (used to size the map
  /// camera around the radius circle).
  static LatLng offset(LatLng from, double distanceKm, double bearingDeg) {
    final d = distanceKm * 1000 / _earthRadiusM;
    final b = _rad(bearingDeg);
    final lat1 = _rad(from.latitude);
    final lng1 = _rad(from.longitude);
    final lat2 = math.asin(math.sin(lat1) * math.cos(d) + math.cos(lat1) * math.sin(d) * math.cos(b));
    final lng2 = lng1 + math.atan2(math.sin(b) * math.sin(d) * math.cos(lat1), math.cos(d) - math.sin(lat1) * math.sin(lat2));
    return LatLng(_deg(lat2), _deg(lng2));
  }

  static String formatDistance(double km, DistanceUnit unit) {
    if (unit == DistanceUnit.miles) {
      final mi = km / kmPerMile;
      return mi < 0.1 ? '${(mi * 5280).round()} ft' : '${mi.toStringAsFixed(1)} mi';
    }
    return km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  static String formatRadius(double km, DistanceUnit unit) {
    if (unit == DistanceUnit.miles) {
      final mi = km / kmPerMile;
      return '${mi.toStringAsFixed(mi < 10 ? 1 : 0)} mi';
    }
    return '${km.toStringAsFixed(km < 10 && km % 1 != 0 ? 1 : 0)} km';
  }

  static String formatEta(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  static double _rad(double deg) => deg * math.pi / 180;
  static double _deg(double rad) => rad * 180 / math.pi;
}
