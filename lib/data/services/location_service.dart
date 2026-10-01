import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/location.dart';

enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

class LocationService {
  Future<LocationAccess> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceDisabled;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always || LocationPermission.whileInUse => LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.denied,
    };
  }

  /// Current GPS position, or null when permission is denied or GPS fails.
  Future<LatLng?> current() async {
    try {
      if (await ensurePermission() != LocationAccess.granted) return null;
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      return pos == null ? null : LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Battery-friendly stream used during "Go There".
  Stream<LatLng> track() =>
      Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10))
          .map((p) => LatLng(p.latitude, p.longitude));

  Future<void> openSettings() => Geolocator.openAppSettings();
}

/// Address search using OpenStreetMap Nominatim. Swap for Google Places or
/// Mapbox Geocoding in production (Nominatim's public server has strict usage
/// limits: max 1 request/second, identifiable User-Agent).
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const _headers = {'User-Agent': 'StayFinder/1.0 (com.stayfinder.stayfinder)'};

  Future<List<PlaceResult>> search(String query, {LatLng? near, String? countryCode}) async {
    if (query.trim().length < 3) return const [];
    final params = {
      'q': query,
      'format': 'jsonv2',
      'limit': '8',
      'countrycodes': ?countryCode,
      if (near != null) 'viewbox': '${near.longitude - 0.4},${near.latitude + 0.4},${near.longitude + 0.4},${near.latitude - 0.4}',
    };
    try {
      final res = await _client.get(Uri.https('nominatim.openstreetmap.org', '/search', params), headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];
      final list = jsonDecode(res.body) as List;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        final display = m['display_name'] as String;
        return PlaceResult(
          name: (m['name'] as String?)?.isNotEmpty == true ? m['name'] as String : display.split(',').first,
          address: display,
          point: LatLng(double.parse(m['lat'] as String), double.parse(m['lon'] as String)),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String?> reverse(LatLng point) async {
    try {
      final res = await _client
          .get(
            Uri.https('nominatim.openstreetmap.org', '/reverse', {'lat': '${point.latitude}', 'lon': '${point.longitude}', 'format': 'jsonv2', 'zoom': '17'}),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      return (jsonDecode(res.body) as Map<String, dynamic>)['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }
}
