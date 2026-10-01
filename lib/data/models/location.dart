import 'package:latlong2/latlong.dart';

enum DistanceUnit { km, miles }

class Country {
  const Country({
    required this.id,
    required this.name,
    required this.flag,
    required this.dialCode,
    required this.currencyCode,
    required this.currencySymbol,
    required this.distanceUnit,
    required this.areaUnits,
    required this.emergencyNumber,
  });

  final String id;
  final String name;
  final String flag;
  final String dialCode;
  final String currencyCode;
  final String currencySymbol;
  final DistanceUnit distanceUnit;
  final List<String> areaUnits;
  final String emergencyNumber;
}

class City {
  const City({
    required this.id,
    required this.countryId,
    required this.name,
    required this.center,
    this.minRadiusKm = 1,
    this.maxRadiusKm = 20,
    this.defaultRadiusKm = 3,
    this.enabled = true,
  });

  final String id;
  final String countryId;
  final String name;
  final LatLng center;
  final double minRadiusKm;
  final double maxRadiusKm;
  final double defaultRadiusKm;
  final bool enabled;
}

enum SavedPlaceKind { home, work, university, office, other }

class SavedPlace {
  const SavedPlace({required this.id, required this.kind, required this.label, required this.address, required this.point});

  final String id;
  final SavedPlaceKind kind;
  final String label;
  final String address;
  final LatLng point;
}

/// Result of an address search / reverse geocode.
class PlaceResult {
  const PlaceResult({required this.name, required this.address, required this.point});
  final String name;
  final String address;
  final LatLng point;
}
