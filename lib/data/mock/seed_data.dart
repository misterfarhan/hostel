import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../models/models.dart';

/// Deterministic demo data so every install shows the same realistic map.
class SeedData {
  SeedData(this.config) {
    _generate();
  }

  final AppConfig config;
  final _rnd = Random(42);
  final owners = <AppUser>[];
  final seekers = <AppUser>[];
  final properties = <Property>[];
  final reviews = <Review>[];

  static const _img = 'https://images.unsplash.com/photo-';
  static const _q = '?w=1000&q=70&auto=format&fit=crop';

  static const _photos = {
    'hostel': [
      '1555854877-bab0e564b8d5',
      '1505693416388-ac5ce068fe85',
      '1540518614846-7eded433c457',
      '1631049307264-da0ec9d70304',
      '1582268611958-ebfd161ef9cf',
      '1522708323590-d24dbb6b0267',
    ],
    'flat': [
      '1502672260266-1c1ef2d93688',
      '1560448204-e02f11c3d0e2',
      '1586023492125-27b2c045efd7',
      '1493809842364-78817add7ffb',
      '1560185007-cde436f6a4d0',
      '1484154218962-a197022b5858',
      '1556909114-f6e7ad7d3136',
    ],
    'house': [
      '1564013799919-ab600027ffc6',
      '1568605114967-8130f3a36994',
      '1570129477492-45c003edd2be',
      '1600585154340-be6161a56a0c',
      '1600596542815-ffad4c1539a9',
      '1523217582562-09d0def993a6',
    ],
    'shop': ['1441986300917-64674bd600d8', '1604719312566-8912e9227c6a', '1472224371017-08207f84aaae', '1604014237800-1c9102c219da'],
    'office': ['1497366216548-37526070297c', '1497366811353-6870744d04b2', '1521737604893-d14cc237f11d', '1524758631624-e2822e304c36'],
    'land': ['1500382017468-9049fed747ef', '1416331108676-a22ccb276e35', '1500382017468-9049fed747ef'],
  };

  static const _areas = <String, List<(String, double, double, String)>>{
    // (area, lat, lng, nearest landmark)
    'lhr': [
      ('New Campus', 31.4981, 74.3001, 'University of the Punjab'),
      ('Johar Town', 31.4697, 74.2728, 'Emporium Mall'),
      ('Gulberg III', 31.5102, 74.3441, 'Liberty Market'),
      ('Model Town', 31.4834, 74.3260, 'Model Town Park'),
      ('DHA Phase 5', 31.4640, 74.4090, 'LUMS'),
      ('Anarkali', 31.5689, 74.3106, 'Anarkali Bazaar'),
      ('Garden Town', 31.5037, 74.3220, 'Kalma Chowk'),
      ('Township', 31.4497, 74.3093, 'UMT'),
      ('Bahria Town', 31.3695, 74.1856, 'Grand Jamia Mosque'),
    ],
    'isb': [
      ('G-9 Markaz', 33.6938, 73.0290, 'Karachi Company'),
      ('F-7 Markaz', 33.7206, 73.0564, 'Jinnah Super'),
      ('I-8 Markaz', 33.6680, 73.0770, 'Shifa Hospital'),
      ('H-12', 33.6425, 72.9926, 'NUST'),
      ('Blue Area', 33.7100, 73.0600, 'Centaurus Mall'),
      ('E-11', 33.6960, 72.9780, 'Margalla Road'),
    ],
    'khi': [
      ('Gulshan-e-Iqbal', 24.9180, 67.0971, 'NIPA Chowrangi'),
      ('Clifton', 24.8138, 67.0300, 'Dolmen Mall Clifton'),
      ('Saddar', 24.8560, 67.0290, 'Empress Market'),
      ('North Nazimabad', 24.9430, 67.0380, 'Hyderi Market'),
      ('University Road', 24.9280, 67.1160, 'University of Karachi'),
      ('DHA Phase 6', 24.7950, 67.0600, 'Bukhari Commercial'),
    ],
    'dxb': [
      ('Dubai Marina', 25.0805, 55.1403, 'Marina Walk'),
      ('Business Bay', 25.1860, 55.2640, 'Bay Avenue'),
      ('Deira', 25.2697, 55.3095, 'Al Rigga Metro'),
      ('Al Barsha', 25.1130, 55.2000, 'Mall of the Emirates'),
      ('Dubai Silicon Oasis', 25.1180, 55.3830, 'RIT Dubai'),
    ],
    'lon': [
      ('Bloomsbury', 51.5246, -0.1340, 'UCL'),
      ('Camden', 51.5390, -0.1426, 'Camden Market'),
      ('Shoreditch', 51.5260, -0.0780, 'Old Street'),
      ('Canary Wharf', 51.5054, -0.0235, 'Canary Wharf Station'),
      ('Stratford', 51.5413, -0.0030, 'Westfield Stratford'),
    ],
  };

  static const _cityCount = {'lhr': 70, 'isb': 40, 'khi': 35, 'dxb': 28, 'lon': 22};

  /// Base monthly price in PKR, scaled per country below.
  static const _priceRange = {
    'boys_hostel': (9000, 22000),
    'girls_hostel': (11000, 26000),
    'flat': (35000, 180000),
    'house': (40000, 250000),
    'shop': (25000, 300000),
    'office': (45000, 400000),
    'land': (3500000, 90000000),
    'other': (2500, 9000),
  };

  static const _countryFactor = {'pk': 1.0, 'ae': 0.03, 'gb': 0.0045};

  static const _ownerNames = [
    'Muhammad Usman',
    'Ayesha Siddiqui',
    'Bilal Ahmed',
    'Nadia Hussain',
    'Omar Farooq',
    'Zainab Malik',
    'Khalid Mehmood',
    'Sana Javed',
    'Hassan Raza',
    'Fatima Noor',
  ];

  static const _reviewers = ['Ali Raza', 'Hamza Tariq', 'Sara Khan', 'Ahmed Ali', 'Mariam Iqbal', 'Daniyal Shah', 'Hira Aslam', 'Usama Qureshi'];

  static const _comments = [
    'Exactly as shown in the photos. Owner was very cooperative.',
    'Clean place and safe area. The price is fair for what you get.',
    'Good location, close to the market and transport.',
    'Visited yesterday. A bit smaller than expected but well maintained.',
    'Owner replied quickly and showed everything honestly.',
    'Great value for money. Would recommend to students.',
    'Neighbourhood is quiet. Water pressure could be better.',
  ];

  T _pick<T>(List<T> items) => items[_rnd.nextInt(items.length)];

  List<T> _some<T>(List<T> items, {int min = 1}) {
    final copy = [...items]..shuffle(_rnd);
    return copy.take(min + _rnd.nextInt(max(1, items.length - min + 1))).toList();
  }

  int _between(int a, int b) => a + _rnd.nextInt(b - a + 1);

  double _round(double v) {
    if (v >= 1000000) return (v / 100000).round() * 100000.0;
    if (v >= 10000) return (v / 500).round() * 500.0;
    if (v >= 1000) return (v / 50).round() * 50.0;
    return (v / 5).round() * 5.0;
  }

  void _generate() {
    final now = DateTime.now();
    for (var i = 0; i < _ownerNames.length; i++) {
      final name = _ownerNames[i];
      owners.add(
        AppUser(
          id: 'owner_$i',
          phone: '+92300${1000000 + i * 7919}',
          name: name,
          ownerStatus: OwnerStatus.approved,
          rating: 3.9 + _rnd.nextDouble(),
          ratingCount: _between(3, 120),
          responseMinutes: _pick([5, 12, 30, 55, 90, 240]),
          badges: [OwnerBadge.verifiedOwner, if (i.isEven) OwnerBadge.fastResponder, if (i % 3 == 0) OwnerBadge.topRated],
          joinedAt: now.subtract(Duration(days: _between(60, 900))),
        ),
      );
    }
    for (var i = 0; i < _reviewers.length; i++) {
      seekers.add(AppUser(id: 'seeker_$i', phone: '+92311${2000000 + i * 131}', name: _reviewers[i], countryId: 'pk', cityId: 'lhr'));
    }

    var n = 0;
    for (final entry in _cityCount.entries) {
      final city = config.city(entry.key);
      final country = config.country(city.countryId);
      final areas = _areas[city.id]!;
      for (var k = 0; k < entry.value; k++) {
        final type = _pickType();
        final area = _pick(areas);
        final point = LatLng(area.$2 + (_rnd.nextDouble() - 0.5) * 0.028, area.$3 + (_rnd.nextDouble() - 0.5) * 0.028);
        properties.add(_buildProperty('p${n++}', type, city, country, area, point, now));
      }
    }

    for (final p in properties) {
      final count = p.reviewCount;
      for (var r = 0; r < min(count, 4); r++) {
        final author = _pick(seekers);
        final cats = {for (final k in Review.categoryLabels.keys) k: (3 + _rnd.nextInt(3)).toDouble()};
        reviews.add(
          Review(
            id: 'r_${p.id}_$r',
            propertyId: p.id,
            authorId: author.id,
            authorName: author.name,
            overall: (cats.values.reduce((a, b) => a + b) / cats.length).roundToDouble(),
            categories: cats,
            comment: _pick(_comments),
            createdAt: now.subtract(Duration(days: _between(2, 200))),
            ownerReply: _rnd.nextInt(4) == 0 ? 'Thank you for visiting! You are always welcome.' : null,
          ),
        );
      }
    }
  }

  PropertyType _pickType() {
    const weights = {'boys_hostel': 18, 'girls_hostel': 13, 'flat': 20, 'house': 14, 'shop': 11, 'office': 9, 'land': 9, 'other': 6};
    final total = weights.values.reduce((a, b) => a + b);
    var roll = _rnd.nextInt(total);
    for (final e in weights.entries) {
      if (roll < e.value) return config.type(e.key);
      roll -= e.value;
    }
    return config.type('flat');
  }

  Property _buildProperty(String id, PropertyType type, City city, Country country, (String, double, double, String) area, LatLng point, DateTime now) {
    final (lo, hi) = _priceRange[type.id]!;
    final factor = _countryFactor[country.id] ?? 1;
    var price = _round((lo + _rnd.nextDouble() * (hi - lo)) * factor);
    final details = <String, dynamic>{};
    var title = '';
    var description = '';
    var purpose = type.purposes.first;
    var totalUnits = 0;
    var availableUnits = 0;
    var gender = type.forcedGender ?? GenderRule.any;
    var included = <String>[];
    var extras = <PriceExtra>[];
    var rules = '';
    final photoKey = switch (type.id) {
      'boys_hostel' || 'girls_hostel' || 'other' => 'hostel',
      final t => t,
    };
    final areaUnit = country.areaUnits.first;

    switch (type.id) {
      case 'boys_hostel' || 'girls_hostel':
        final girls = type.id == 'girls_hostel';
        final names = girls
            ? ['Fatima', 'Rose', 'Ayesha', 'Safe Nest', 'Nightingale', 'Iris', 'Pearl']
            : ['Scholars', 'Crescent', 'Al-Noor', 'Iqbal', 'Comfort Stay', 'Green View', 'Capital'];
        title = '${_pick(names)} ${girls ? 'Girls' : 'Boys'} Hostel';
        final rooms = _between(8, 40);
        totalUnits = rooms * _between(2, 3);
        availableUnits = _rnd.nextInt(7) == 0 ? 0 : _between(1, min(12, totalUnits));
        details.addAll({
          'total_rooms': rooms,
          'room_types': _some(['Single', 'Double', 'Triple', 'Four-seater'], min: 2),
          'price_per_room': _round(price * 2.6),
          'meals': _some(['Breakfast', 'Lunch', 'Dinner']),
          'meals_price': _pick([0, 4000, 6000]) * factor,
          'kitchen': _pick(['Attached to room', 'Common kitchen', 'Common kitchen', 'No kitchen']),
          'fridge_allowed': _rnd.nextBool(),
          'cooking_allowed': _rnd.nextBool(),
          'bathroom': _pick(['Attached bathroom', 'Common bathroom']),
          'hot_water': true,
          'furniture': _some(['Bed', 'Mattress', 'Cupboard', 'Study table', 'Chair', 'Fan', 'AC', 'Heater', 'Curtains'], min: 4),
          'entry_timing': girls ? '6:00 AM – 9:00 PM' : '6:00 AM – 11:30 PM',
          'visitor_policy': girls ? 'Lobby only' : _pick(['Lobby only', 'Allowed with permission']),
          'smoking': 'Not allowed',
          'min_stay_months': _pick([1, 3, 6]),
          'notice_days': _pick([15, 30]),
          'safety': girls
              ? ['CCTV', 'Security guard', 'Biometric / gate entry', 'ID check at gate', 'Women-only floor']
              : _some(['CCTV', 'Security guard', 'Biometric / gate entry', 'Fire safety']),
          'warden_name': girls ? _pick(['Mrs. Shazia', 'Mrs. Rubina', 'Ms. Kiran']) : 'Mr. ${_pick(['Aslam', 'Tariq', 'Javed'])}',
          'floors': _between(2, 5),
          'facilities': _some(['Lift', 'Parking', 'Laundry area', 'Prayer area', 'Common lounge', 'Study room']),
          'age_group': _pick(['Students', 'Working professionals', 'Anyone']),
        });
        included = _some(type.includedOptions, min: 3);
        if (!included.contains('Electricity')) extras = [PriceExtra(name: 'AC electricity', price: _round(3000 * factor))];
        description =
            'Well-managed ${girls ? 'girls' : 'boys'} hostel in ${area.$1}, walking distance from ${area.$4}. '
            'Clean rooms, ${details['kitchen'].toString().toLowerCase()}, reliable Wi-Fi and 24/7 ${girls ? 'female warden and ' : ''}security.';
        rules = 'No smoking inside rooms. Guests allowed in the lobby only. Rent due by the 5th of each month.';
      case 'flat':
        final beds = _between(1, 4);
        purpose = _rnd.nextInt(5) == 0 ? ListingPurpose.sale : ListingPurpose.rent;
        if (purpose == ListingPurpose.sale) price = _round(price * 150);
        final furnishing = _pick(['Furnished', 'Semi-furnished', 'Unfurnished']);
        title = '$furnishing $beds-Bed Apartment';
        details.addAll({
          'bedrooms': beds,
          'bathrooms': max(1, beds - _rnd.nextInt(2)),
          'kitchen_type': _pick(['Open kitchen', 'Closed kitchen']),
          'drawing_room': _rnd.nextBool(),
          'size': _between(5, 22) * 100,
          'size_unit': 'sq ft',
          'floor': _between(1, 12),
          'total_floors': _between(12, 20),
          'lift': true,
          'building_age': _between(1, 15),
          'furnishing': furnishing,
          'tenant_type': _pick(['Family only', 'Bachelor allowed', 'Anyone']),
          'pets': _rnd.nextInt(4) == 0,
          'maintenance': _round(price * 0.05),
          'features': _some(['Parking', 'Generator', 'Security', 'Balcony', 'Gym', 'Swimming pool'], min: 2),
        });
        included = _some(type.includedOptions);
        description = 'Bright $beds-bedroom apartment in ${area.$1} close to ${area.$4}. Secure building with lift, parking and backup power.';
        rules = 'Two months advance and one month security. Minimum one-year agreement.';
      case 'house':
        final portion = _pick(['Whole house', 'Upper portion', 'Lower portion', 'Single room']);
        final beds = portion == 'Single room' ? 1 : _between(2, 6);
        if (portion == 'Single room') price = _round(price * 0.25);
        purpose = portion == 'Whole house' && _rnd.nextInt(3) == 0 ? ListingPurpose.sale : ListingPurpose.rent;
        if (purpose == ListingPurpose.sale) price = _round(price * 200);
        final plot = _pick([5, 7, 10, 12, 20]);
        title = portion == 'Whole house' ? '$plot ${areaUnit == 'marla' ? 'Marla ' : ''}House' : portion;
        details.addAll({
          'portion': portion,
          'plot_size': areaUnit == 'marla' ? plot : plot * 250,
          'plot_unit': areaUnit == 'marla' ? 'marla' : 'sq ft',
          'covered_area': plot * 225,
          'floors': portion == 'Whole house' ? 2 : 1,
          'bedrooms': beds,
          'bathrooms': max(1, beds - 1),
          'kitchens': portion == 'Whole house' ? 2 : 1,
          'separate_gate': portion != 'Single room',
          'separate_meters': _rnd.nextBool(),
          'furnishing': _pick(['Furnished', 'Semi-furnished', 'Unfurnished']),
          'tenant_type': _pick(['Family only', 'Bachelor allowed']),
          'features': _some(['Lounge', 'Drawing room', 'Garage', 'Garden', 'Roof access']),
        });
        description = '$portion in a peaceful street of ${area.$1}, near ${area.$4}. Good water supply and separate entrance.';
        rules = 'Families preferred. Utility bills paid by tenant.';
      case 'shop':
        final kind = _pick(['Market shop', 'Plaza shop', 'Kiosk']);
        final corner = _rnd.nextInt(4) == 0;
        purpose = _pick(type.purposes);
        if (purpose == ListingPurpose.sale) price = _round(price * 120);
        title = corner ? 'Corner Shop on Main Road' : '${_pick(['Ground', 'First'])} Floor $kind';
        details.addAll({
          'shop_kind': kind,
          'size': kind == 'Kiosk' ? _between(40, 80) : _between(120, 900),
          'size_unit': 'sq ft',
          'floor': _pick(['Ground', 'Ground', 'First', 'Basement']),
          'frontage': _between(8, 30),
          'road_type': corner ? 'Main road' : _pick(['Main road', 'Market', 'Inside street']),
          'corner': corner,
          'pagri': _rnd.nextBool() ? _round(price * 10) : 0,
          'lease_years': _pick([1, 2, 3, 5]),
          'allowed_business': _pick(['Any retail', 'Clothing, shoes, cosmetics', 'Pharmacy or clinic', 'Food & bakery']),
          'features': _some(['Electricity meter', 'Shutter', 'Washroom', 'Parking', 'Storage'], min: 2),
        });
        description = '$kind with ${details['frontage']} ft frontage in busy ${area.$1}, high foot traffic near ${area.$4}.';
      case 'office':
        final kind = _pick(['Office', 'Office', 'Co-working desk', 'Warehouse', 'Showroom']);
        if (kind == 'Co-working desk') price = _round(price * 0.2);
        title = kind == 'Co-working desk' ? 'Co-working Desks' : 'Furnished $kind Space';
        details.addAll({
          'office_kind': kind,
          'size': kind == 'Co-working desk' ? 60 : _between(4, 40) * 100,
          'size_unit': 'sq ft',
          'floor': _pick(['Ground', 'First', 'Second', 'Third or above']),
          'desks': kind == 'Warehouse' ? 0 : _between(4, 40),
          'meeting_rooms': _between(0, 3),
          'lease_years': _pick([1, 2, 3]),
          'features': _some(type.fields.last.options, min: 3),
        });
        included = _some(type.includedOptions);
        description = 'Professional ${kind.toLowerCase()} in ${area.$1} with backup power and fast internet. Close to ${area.$4}.';
      case 'land':
        final landType = _pick(['Residential', 'Residential', 'Commercial', 'Agricultural', 'Industrial']);
        final useMarla = areaUnit == 'marla';
        final size = landType == 'Agricultural' ? _between(2, 25) : (useMarla ? _pick([5, 8, 10, 20]) : _between(20, 120) * 100);
        final unit = landType == 'Agricultural' ? 'acre' : (useMarla ? (size >= 20 ? 'kanal' : 'marla') : 'sq ft');
        final displaySize = unit == 'kanal' ? size ~/ 20 : size;
        purpose = _rnd.nextInt(5) == 0 ? ListingPurpose.lease : ListingPurpose.sale;
        if (purpose == ListingPurpose.lease) price = _round(price * 0.01);
        title = '$displaySize ${unit[0].toUpperCase()}${unit.substring(1)} $landType Plot';
        details.addAll({
          'land_type': landType,
          'size': displaySize,
          'size_unit': unit,
          'price_per_unit': _round(price / displaySize),
          'road_width': _pick([20, 30, 40, 60, 80]),
          'corner': _rnd.nextInt(4) == 0,
          'boundary_wall': _rnd.nextBool(),
          'utilities': _some(['Gas', 'Electricity', 'Water', 'Sewerage']),
          'possession': _pick(['Ready', 'Under development']),
          'scheme_name': '${area.$1} ${_pick(['Housing Scheme', 'Society', 'Enclave'])}',
          'document_type': _pick(['Registry', 'Fard', 'Allotment letter', 'Title deed']),
        });
        description = '$landType plot in ${area.$1}. ${details['road_width']} ft road, clear documents, ideal for investment.';
      default:
        final kind = _pick(['PG', 'Short-term stay', 'Guest room', 'Serviced apartment']);
        title = kind == 'PG' ? 'Paying Guest Room' : kind;
        details.addAll({'stay_kind': kind, 'rooms': _between(1, 6), 'features': _some(type.fields.last.options)});
        included = _some(type.includedOptions);
        description = 'Comfortable $kind near ${area.$4}, ${area.$1}. Daily cleaning and Wi-Fi included.';
    }

    final photos = [
      ...List.generate(4, (i) {
        final list = _photos[photoKey]!;
        return '$_img${list[(id.hashCode + i) % list.length]}$_q';
      }).toSet(),
    ];

    var status = ListingStatus.live;
    if (type.usesUnits && availableUnits == 0) status = ListingStatus.full;
    if (_rnd.nextInt(25) == 0) status = ListingStatus.paused;

    final reviewCount = _rnd.nextInt(3) == 0 ? 0 : _between(1, 30);
    final created = now.subtract(Duration(days: _between(0, 120), hours: _between(0, 23)));
    final owner = owners[_rnd.nextInt(owners.length)];

    return Property(
      id: id,
      ownerId: owner.id,
      typeId: type.id,
      purpose: purpose,
      title: title,
      description: description,
      countryId: country.id,
      cityId: city.id,
      area: area.$1,
      address: 'Street ${_between(1, 40)}, ${area.$1}, ${city.name}',
      point: point,
      price: price,
      pricePeriod: purpose == ListingPurpose.sale || type.id == 'land' && purpose != ListingPurpose.lease
          ? PricePeriod.oneTime
          : (purpose == ListingPurpose.lease ? PricePeriod.perMonth : type.defaultPeriod),
      currency: country.currencyCode,
      negotiable: _rnd.nextInt(3) != 0,
      deposit: purpose == ListingPurpose.sale ? 0 : _round(price * _pick([1, 1, 2])),
      advanceMonths: purpose == ListingPurpose.sale ? 0 : _pick([0, 1, 2]),
      agreementMonths: purpose == ListingPurpose.sale ? 0 : _pick([6, 11, 12]),
      availableFrom: now.add(Duration(days: _pick([0, 0, 3, 7, 15, 30]))),
      totalUnits: totalUnits,
      availableUnits: availableUnits,
      genderRule: gender,
      details: details,
      included: included,
      extras: extras,
      photos: photos,
      rules: rules,
      nearby: [
        NearbyPlace(name: area.$4, category: 'Landmark', distanceKm: 0.2 + _rnd.nextDouble() * 1.5),
        NearbyPlace(name: '${area.$1} Market', category: 'Market', distanceKm: 0.1 + _rnd.nextDouble()),
        NearbyPlace(name: 'Bus stop', category: 'Transport', distanceKm: 0.1 + _rnd.nextDouble() * 0.6),
        NearbyPlace(name: 'General Hospital', category: 'Hospital', distanceKm: 0.8 + _rnd.nextDouble() * 3),
      ],
      preferredContact: 'Chat',

      status: status,
      isVerified: _rnd.nextInt(5) < 3,
      isFeatured: _rnd.nextInt(8) == 0,
      averageRating: reviewCount == 0 ? 0 : double.parse((3.6 + _rnd.nextDouble() * 1.4).toStringAsFixed(1)),
      reviewCount: reviewCount,
      viewsCount: _between(20, 2500),
      favouritesCount: _between(0, 180),
      visitsCount: _between(0, 60),
      inquiriesCount: _between(0, 40),
      createdAt: created,
      updatedAt: created,
      expiresAt: created.add(const Duration(days: 90)),
      lastConfirmedAt: created,
    );
  }
}
