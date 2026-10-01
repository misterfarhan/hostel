import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stayfinder/core/utils/geo.dart';
import 'package:stayfinder/core/utils/property_facts.dart';
import 'package:stayfinder/data/config/app_config.dart';
import 'package:stayfinder/data/mock/mock_backend.dart';
import 'package:stayfinder/data/models/models.dart';
import 'package:stayfinder/data/search_matcher.dart';

void main() {
  final config = AppConfig.defaults;
  const lahore = LatLng(31.5204, 74.3587);

  Property property({
    String id = 'x',
    String typeId = 'boys_hostel',
    LatLng point = lahore,
    ListingStatus status = ListingStatus.live,
    double price = 10000,
    int available = 3,
    Map<String, dynamic> details = const {'kitchen': 'Common kitchen'},
  }) => Property(
    id: id,
    ownerId: 'o',
    typeId: typeId,
    purpose: ListingPurpose.perSeat,
    title: 'Test',
    description: '',
    countryId: 'pk',
    cityId: 'lhr',
    area: 'A',
    address: 'B',
    point: point,
    price: price,
    pricePeriod: PricePeriod.perSeatMonth,
    currency: 'PKR',
    status: status,
    totalUnits: 10,
    availableUnits: available,
    details: details,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  SearchQuery query({double radiusKm = 3, Set<String> types = const {'boys_hostel'}, SearchFilters filters = const SearchFilters()}) =>
      SearchQuery(typeIds: types, countryId: 'pk', cityId: 'lhr', center: lahore, radiusKm: radiusKm, filters: filters);

  group('Geo', () {
    test('haversine distance Lahore → Islamabad is about 270 km', () {
      expect(Geo.distanceKm(lahore, const LatLng(33.6844, 73.0479)), closeTo(270, 10));
    });

    test('offset point lies exactly at the requested distance', () {
      final p = Geo.offset(lahore, 5, 45);
      expect(Geo.distanceKm(lahore, p), closeTo(5, 0.01));
    });

    test('distance formatting follows the country unit', () {
      expect(Geo.formatDistance(0.45, DistanceUnit.km), '450 m');
      expect(Geo.formatDistance(3.2, DistanceUnit.km), '3.2 km');
      expect(Geo.formatDistance(1.609344, DistanceUnit.miles), '1.0 mi');
    });
  });

  group('SearchMatcher', () {
    test('only LIVE listings inside the radius match', () {
      final inside = property(point: Geo.offset(lahore, 2.9, 90));
      final outside = property(point: Geo.offset(lahore, 3.1, 90));
      final paused = property(point: lahore, status: ListingStatus.paused);
      expect(SearchMatcher.matches(inside, query()), isTrue);
      expect(SearchMatcher.matches(outside, query()), isFalse);
      expect(SearchMatcher.matches(paused, query()), isFalse);
    });

    test('FULL hostels are hidden unless the admin shows them with a badge', () {
      final full = property(status: ListingStatus.full, available: 0);
      expect(SearchMatcher.matches(full, query()), isFalse);
      expect(SearchMatcher.matches(full, query(), showFull: true), isTrue);
    });

    test('type, budget and seat filters apply', () {
      final p = property(price: 12000, available: 2);
      expect(SearchMatcher.matches(p, query(types: {'flat'})), isFalse);
      expect(SearchMatcher.matches(p, query(filters: const SearchFilters(maxBudget: 10000))), isFalse);
      expect(SearchMatcher.matches(p, query(filters: const SearchFilters(minSeats: 3))), isFalse);
      expect(SearchMatcher.matches(p, query(filters: const SearchFilters(minSeats: 2, maxBudget: 15000))), isTrue);
    });

    test('sorting by lowest price', () {
      final list = [property(id: 'a', price: 3), property(id: 'b', price: 1), property(id: 'c', price: 2)];
      expect(SearchMatcher.sort(list, SortOption.lowestPrice, query()).map((p) => p.id), ['b', 'c', 'a']);
    });
  });

  group('PropertyFacts', () {
    test('hostel key facts show seats and kitchen', () {
      final facts = PropertyFacts.keyFacts(property(available: 4), config.type('boys_hostel'));
      expect(facts, ['4 seats left', 'Common kitchen']);
    });

    test('single seat is singular, zero is Full', () {
      expect(PropertyFacts.keyFacts(property(available: 1), config.type('boys_hostel')).first, '1 seat left');
      expect(PropertyFacts.keyFacts(property(available: 0), config.type('boys_hostel')).first, 'Full');
    });

    test('required fields are reported as missing', () {
      final missing = PropertyFacts.missingRequired({'total_rooms': 5}, config.type('boys_hostel')).map((f) => f.key);
      expect(missing, containsAll(['room_types', 'kitchen', 'bathroom']));
      expect(missing, isNot(contains('total_rooms')));
    });
  });

  group('MockBackend', () {
    late MockBackend backend;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      backend = MockBackend(config, await SharedPreferences.getInstance());
    });

    test('search returns only live listings within the radius', () async {
      final q = query(radiusKm: 10);
      final results = await backend.search(q);
      expect(results, isNotEmpty);
      for (final p in results) {
        expect(p.status, ListingStatus.live);
        expect(p.typeId, 'boys_hostel');
        expect(Geo.distanceKm(lahore, p.point), lessThanOrEqualTo(10));
      }
    });

    test('hostel becomes FULL at zero seats and live again when seats return', () async {
      final hostel = (await backend.search(query(radiusKm: 25))).first;
      await backend.updateAvailability(hostel.id, 0);
      var p = await backend.watchProperty(hostel.id).first;
      expect(p!.status, ListingStatus.full);
      await backend.updateAvailability(hostel.id, 2);
      p = await backend.watchProperty(hostel.id).first;
      expect(p!.status, ListingStatus.live);
    });

    test('OTP login rejects a wrong code', () async {
      await backend.requestOtp('+923001234567');
      expect(() => backend.verifyOtp('+923001234567', '000000'), throwsA(isA<Exception>()));
      final user = await backend.verifyOtp('+923001234567', MockBackend.demoOtp);
      expect(user.isProfileComplete, isFalse);
    });
  });
}
