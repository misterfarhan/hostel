import 'package:latlong2/latlong.dart';

import 'enums.dart';

class NearbyPlace {
  const NearbyPlace({required this.name, required this.category, required this.distanceKm});
  final String name;
  final String category;
  final double distanceKm;

  Map<String, dynamic> toJson() => {'name': name, 'category': category, 'distance_km': distanceKm};
  factory NearbyPlace.fromJson(Map<String, dynamic> j) =>
      NearbyPlace(name: j['name'] as String, category: j['category'] as String, distanceKm: (j['distance_km'] as num).toDouble());
}

/// Something that costs extra on top of the base price (e.g. meals, AC bill).
class PriceExtra {
  const PriceExtra({required this.name, required this.price});
  final String name;
  final double price;

  Map<String, dynamic> toJson() => {'name': name, 'price': price};
  factory PriceExtra.fromJson(Map<String, dynamic> j) => PriceExtra(name: j['name'] as String, price: (j['price'] as num).toDouble());
}

class Property {
  const Property({
    required this.id,
    required this.ownerId,
    required this.typeId,
    required this.purpose,
    required this.title,
    required this.description,
    required this.countryId,
    required this.cityId,
    required this.area,
    required this.address,
    required this.point,
    required this.price,
    required this.pricePeriod,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.negotiable = false,
    this.deposit = 0,
    this.advanceMonths = 0,
    this.agreementMonths = 0,
    this.availableFrom,
    this.totalUnits = 0,
    this.availableUnits = 0,
    this.genderRule = GenderRule.any,
    this.details = const {},
    this.included = const [],
    this.extras = const [],
    this.photos = const [],
    this.videoUrl,
    this.rules = '',
    this.nearby = const [],
    this.preferredContact = 'Chat',
    this.bestTimeToCall = '',
    this.rejectionReason,
    this.isVerified = false,
    this.isFeatured = false,
    this.averageRating = 0,
    this.reviewCount = 0,
    this.viewsCount = 0,
    this.favouritesCount = 0,
    this.visitsCount = 0,
    this.inquiriesCount = 0,
    this.expiresAt,
    this.lastConfirmedAt,
  });

  final String id;
  final String ownerId;
  final String typeId;
  final ListingPurpose purpose;
  final String title;
  final String description;
  final String countryId;
  final String cityId;
  final String area;
  final String address;
  final LatLng point;
  final double price;
  final PricePeriod pricePeriod;
  final String currency;
  final bool negotiable;
  final double deposit;
  final int advanceMonths;
  final int agreementMonths;
  final DateTime? availableFrom;
  final int totalUnits;
  final int availableUnits;
  final GenderRule genderRule;

  /// Type-specific values keyed by [PropertyField.key].
  final Map<String, dynamic> details;
  final List<String> included;
  final List<PriceExtra> extras;
  final List<String> photos;
  final String? videoUrl;
  final String rules;
  final List<NearbyPlace> nearby;
  final String preferredContact;
  final String bestTimeToCall;
  final ListingStatus status;
  final String? rejectionReason;
  final bool isVerified;
  final bool isFeatured;
  final double averageRating;
  final int reviewCount;
  final int viewsCount;
  final int favouritesCount;
  final int visitsCount;
  final int inquiriesCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final DateTime? lastConfirmedAt;

  String? get mainPhoto => photos.isEmpty ? null : photos.first;

  Property copyWith({
    String? typeId,
    ListingPurpose? purpose,
    String? title,
    String? description,
    String? countryId,
    String? cityId,
    String? area,
    String? address,
    LatLng? point,
    double? price,
    PricePeriod? pricePeriod,
    String? currency,
    bool? negotiable,
    double? deposit,
    int? advanceMonths,
    int? agreementMonths,
    DateTime? availableFrom,
    int? totalUnits,
    int? availableUnits,
    GenderRule? genderRule,
    Map<String, dynamic>? details,
    List<String>? included,
    List<PriceExtra>? extras,
    List<String>? photos,
    String? videoUrl,
    String? rules,
    List<NearbyPlace>? nearby,
    String? preferredContact,
    String? bestTimeToCall,
    ListingStatus? status,
    String? rejectionReason,
    bool? isVerified,
    bool? isFeatured,
    double? averageRating,
    int? reviewCount,
    int? viewsCount,
    int? favouritesCount,
    int? visitsCount,
    int? inquiriesCount,
    DateTime? updatedAt,
    DateTime? expiresAt,
    DateTime? lastConfirmedAt,
  }) {
    return Property(
      id: id,
      ownerId: ownerId,
      createdAt: createdAt,
      typeId: typeId ?? this.typeId,
      purpose: purpose ?? this.purpose,
      title: title ?? this.title,
      description: description ?? this.description,
      countryId: countryId ?? this.countryId,
      cityId: cityId ?? this.cityId,
      area: area ?? this.area,
      address: address ?? this.address,
      point: point ?? this.point,
      price: price ?? this.price,
      pricePeriod: pricePeriod ?? this.pricePeriod,
      currency: currency ?? this.currency,
      negotiable: negotiable ?? this.negotiable,
      deposit: deposit ?? this.deposit,
      advanceMonths: advanceMonths ?? this.advanceMonths,
      agreementMonths: agreementMonths ?? this.agreementMonths,
      availableFrom: availableFrom ?? this.availableFrom,
      totalUnits: totalUnits ?? this.totalUnits,
      availableUnits: availableUnits ?? this.availableUnits,
      genderRule: genderRule ?? this.genderRule,
      details: details ?? this.details,
      included: included ?? this.included,
      extras: extras ?? this.extras,
      photos: photos ?? this.photos,
      videoUrl: videoUrl ?? this.videoUrl,
      rules: rules ?? this.rules,
      nearby: nearby ?? this.nearby,
      preferredContact: preferredContact ?? this.preferredContact,
      bestTimeToCall: bestTimeToCall ?? this.bestTimeToCall,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      isVerified: isVerified ?? this.isVerified,
      isFeatured: isFeatured ?? this.isFeatured,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      viewsCount: viewsCount ?? this.viewsCount,
      favouritesCount: favouritesCount ?? this.favouritesCount,
      visitsCount: visitsCount ?? this.visitsCount,
      inquiriesCount: inquiriesCount ?? this.inquiriesCount,
      updatedAt: updatedAt ?? DateTime.now(),
      expiresAt: expiresAt ?? this.expiresAt,
      lastConfirmedAt: lastConfirmedAt ?? this.lastConfirmedAt,
    );
  }

  /// Matches the backend `Property` structure from the spec (section 18).
  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_id': ownerId,
    'property_type_id': typeId,
    'purpose': purpose.name,
    'title': title,
    'description': description,
    'country_id': countryId,
    'city_id': cityId,
    'area': area,
    'address': address,
    'latitude': point.latitude,
    'longitude': point.longitude,
    'price': price,
    'price_period': pricePeriod.name,
    'currency': currency,
    'negotiable': negotiable,
    'deposit': deposit,
    'advance': advanceMonths,
    'agreement_months': agreementMonths,
    'total_units': totalUnits,
    'available_units': availableUnits,
    'available_from': availableFrom?.toIso8601String(),
    'gender_rule': genderRule.name,
    'details': details,
    'included': included,
    'extras': extras.map((e) => e.toJson()).toList(),
    'photos': photos,
    'video_url': videoUrl,
    'rules': rules,
    'nearby': nearby.map((e) => e.toJson()).toList(),
    'preferred_contact': preferredContact,
    'best_time_to_call': bestTimeToCall,
    'status': status.name,
    'rejection_reason': rejectionReason,
    'is_verified': isVerified,
    'is_featured': isFeatured,
    'average_rating': averageRating,
    'review_count': reviewCount,
    'views_count': viewsCount,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
  };

  factory Property.fromJson(Map<String, dynamic> j) => Property(
    id: j['id'] as String,
    ownerId: j['owner_id'] as String,
    typeId: j['property_type_id'] as String,
    purpose: ListingPurpose.values.byName(j['purpose'] as String),
    title: j['title'] as String,
    description: j['description'] as String? ?? '',
    countryId: j['country_id'] as String,
    cityId: j['city_id'] as String,
    area: j['area'] as String? ?? '',
    address: j['address'] as String? ?? '',
    point: LatLng((j['latitude'] as num).toDouble(), (j['longitude'] as num).toDouble()),
    price: (j['price'] as num).toDouble(),
    pricePeriod: PricePeriod.values.byName(j['price_period'] as String),
    currency: j['currency'] as String,
    negotiable: j['negotiable'] as bool? ?? false,
    deposit: (j['deposit'] as num?)?.toDouble() ?? 0,
    advanceMonths: j['advance'] as int? ?? 0,
    agreementMonths: j['agreement_months'] as int? ?? 0,
    totalUnits: j['total_units'] as int? ?? 0,
    availableUnits: j['available_units'] as int? ?? 0,
    availableFrom: DateTime.tryParse(j['available_from'] as String? ?? ''),
    genderRule: GenderRule.values.byName(j['gender_rule'] as String? ?? 'any'),
    details: (j['details'] as Map?)?.cast<String, dynamic>() ?? const {},
    included: (j['included'] as List?)?.cast<String>() ?? const [],
    extras: (j['extras'] as List? ?? const []).map((e) => PriceExtra.fromJson((e as Map).cast<String, dynamic>())).toList(),
    photos: (j['photos'] as List?)?.cast<String>() ?? const [],
    videoUrl: j['video_url'] as String?,
    rules: j['rules'] as String? ?? '',
    nearby: (j['nearby'] as List? ?? const []).map((e) => NearbyPlace.fromJson((e as Map).cast<String, dynamic>())).toList(),
    preferredContact: j['preferred_contact'] as String? ?? 'Chat',
    bestTimeToCall: j['best_time_to_call'] as String? ?? '',
    status: ListingStatus.values.byName(j['status'] as String),
    rejectionReason: j['rejection_reason'] as String?,
    isVerified: j['is_verified'] as bool? ?? false,
    isFeatured: j['is_featured'] as bool? ?? false,
    averageRating: (j['average_rating'] as num?)?.toDouble() ?? 0,
    reviewCount: j['review_count'] as int? ?? 0,
    viewsCount: j['views_count'] as int? ?? 0,
    createdAt: DateTime.parse(j['created_at'] as String),
    updatedAt: DateTime.parse(j['updated_at'] as String),
    expiresAt: DateTime.tryParse(j['expires_at'] as String? ?? ''),
  );
}
