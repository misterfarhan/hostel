import 'package:latlong2/latlong.dart';

import 'enums.dart';

/// Search request as sent to the backend (spec section 18).
class SearchQuery {
  const SearchQuery({
    required this.typeIds,
    required this.countryId,
    required this.cityId,
    required this.center,
    required this.radiusKm,
    this.centerLabel = 'Current location',
    this.filters = const SearchFilters(),
  });

  final Set<String> typeIds;
  final String countryId;
  final String cityId;
  final LatLng center;
  final double radiusKm;
  final String centerLabel;
  final SearchFilters filters;

  SearchQuery copyWith({
    Set<String>? typeIds,
    String? countryId,
    String? cityId,
    LatLng? center,
    double? radiusKm,
    String? centerLabel,
    SearchFilters? filters,
  }) => SearchQuery(
    typeIds: typeIds ?? this.typeIds,
    countryId: countryId ?? this.countryId,
    cityId: cityId ?? this.cityId,
    center: center ?? this.center,
    radiusKm: radiusKm ?? this.radiusKm,
    centerLabel: centerLabel ?? this.centerLabel,
    filters: filters ?? this.filters,
  );

  Map<String, dynamic> toJson() => {
    'property_type': typeIds.toList(),
    'country_id': countryId,
    'city_id': cityId,
    'center_latitude': center.latitude,
    'center_longitude': center.longitude,
    'radius_meters': (radiusKm * 1000).round(),
    'filters': filters.toJson(),
  };
}

class SearchFilters {
  const SearchFilters({
    this.minBudget,
    this.maxBudget,
    this.purpose,
    this.minSeats,
    this.furnished,
    this.kitchen,
    this.genderRule,
    this.availableBy,
    this.verifiedOnly = false,
    this.facilities = const {},
  });

  final double? minBudget;
  final double? maxBudget;
  final ListingPurpose? purpose;
  final int? minSeats;
  final String? furnished;
  final String? kitchen;
  final GenderRule? genderRule;
  final DateTime? availableBy;
  final bool verifiedOnly;
  final Set<String> facilities;

  int get activeCount => [
    minBudget != null || maxBudget != null,
    purpose != null,
    minSeats != null,
    furnished != null,
    kitchen != null,
    genderRule != null,
    availableBy != null,
    verifiedOnly,
    facilities.isNotEmpty,
  ].where((e) => e).length;

  Map<String, dynamic> toJson() => {
    if (minBudget != null) 'min_budget': minBudget,
    if (maxBudget != null) 'max_budget': maxBudget,
    if (purpose != null) 'purpose': purpose!.name,
    if (minSeats != null) 'min_seats': minSeats,
    if (furnished != null) 'furnished': furnished,
    if (kitchen != null) 'kitchen': kitchen,
    if (genderRule != null) 'gender_rule': genderRule!.name,
    if (availableBy != null) 'available_by': availableBy!.toIso8601String(),
    if (verifiedOnly) 'verified_only': true,
    if (facilities.isNotEmpty) 'facilities': facilities.toList(),
  };
}

class SavedSearch {
  const SavedSearch({required this.id, required this.name, required this.query, required this.createdAt, this.alertsEnabled = true, this.newMatches = 0});

  final String id;
  final String name;
  final SearchQuery query;
  final DateTime createdAt;
  final bool alertsEnabled;
  final int newMatches;

  SavedSearch copyWith({bool? alertsEnabled, int? newMatches}) => SavedSearch(
    id: id,
    name: name,
    query: query,
    createdAt: createdAt,
    alertsEnabled: alertsEnabled ?? this.alertsEnabled,
    newMatches: newMatches ?? this.newMatches,
  );
}

class VisitRequest {
  const VisitRequest({
    required this.id,
    required this.propertyId,
    required this.seekerId,
    required this.ownerId,
    required this.preferredTime,
    required this.status,
    required this.createdAt,
    this.message = '',
    this.proposedTime,
    this.visitCode,
    this.outcome,
    this.reviewed = false,
  });

  final String id;
  final String propertyId;
  final String seekerId;
  final String ownerId;
  final DateTime preferredTime;
  final VisitStatus status;
  final DateTime createdAt;
  final String message;

  /// Owner's counter-proposal when status is [VisitStatus.rescheduled].
  final DateTime? proposedTime;

  /// 4-digit code the owner shows to confirm the visit happened.
  final String? visitCode;
  final VisitOutcome? outcome;
  final bool reviewed;

  DateTime get effectiveTime => proposedTime ?? preferredTime;

  VisitRequest copyWith({VisitStatus? status, DateTime? proposedTime, String? visitCode, VisitOutcome? outcome, bool? reviewed}) => VisitRequest(
    id: id,
    propertyId: propertyId,
    seekerId: seekerId,
    ownerId: ownerId,
    preferredTime: preferredTime,
    createdAt: createdAt,
    message: message,
    status: status ?? this.status,
    proposedTime: proposedTime ?? this.proposedTime,
    visitCode: visitCode ?? this.visitCode,
    outcome: outcome ?? this.outcome,
    reviewed: reviewed ?? this.reviewed,
  );
}

/// A "Go There" session (spec: VisitJourney).
class VisitJourney {
  const VisitJourney({
    required this.id,
    required this.seekerId,
    required this.propertyId,
    required this.status,
    required this.startTime,
    this.visitRequestId,
    this.shareWithOwner = false,
    this.arrivalTime,
    this.shareLink,
  });

  final String id;
  final String seekerId;
  final String propertyId;
  final String? visitRequestId;
  final JourneyStatus status;
  final bool shareWithOwner;
  final DateTime startTime;
  final DateTime? arrivalTime;
  final String? shareLink;

  VisitJourney copyWith({JourneyStatus? status, bool? shareWithOwner, DateTime? arrivalTime, String? shareLink}) => VisitJourney(
    id: id,
    seekerId: seekerId,
    propertyId: propertyId,
    visitRequestId: visitRequestId,
    startTime: startTime,
    status: status ?? this.status,
    shareWithOwner: shareWithOwner ?? this.shareWithOwner,
    arrivalTime: arrivalTime ?? this.arrivalTime,
    shareLink: shareLink ?? this.shareLink,
  );
}

class Review {
  const Review({
    required this.id,
    required this.propertyId,
    required this.authorId,
    required this.authorName,
    required this.overall,
    required this.categories,
    required this.comment,
    required this.createdAt,
    this.ownerReply,
  });

  final String id;
  final String propertyId;
  final String authorId;
  final String authorName;
  final double overall;

  /// cleanliness, safety, honesty, value, owner.
  final Map<String, double> categories;
  final String comment;
  final DateTime createdAt;
  final String? ownerReply;

  static const categoryLabels = {
    'cleanliness': 'Cleanliness',
    'safety': 'Safety',
    'honesty': 'Honesty of listing',
    'value': 'Value for money',
    'owner': 'Owner behaviour',
  };
}

class Inquiry {
  const Inquiry({
    required this.id,
    required this.propertyId,
    required this.seekerId,
    required this.seekerName,
    required this.message,
    required this.createdAt,
    this.preferredVisit,
    this.handled = false,
  });

  final String id;
  final String propertyId;
  final String seekerId;
  final String seekerName;
  final String message;
  final DateTime createdAt;
  final DateTime? preferredVisit;
  final bool handled;
}

class ListingReport {
  const ListingReport({
    required this.id,
    required this.reporterId,
    required this.reason,
    required this.details,
    required this.createdAt,
    this.propertyId,
    this.userId,
  });

  final String id;
  final String reporterId;
  final String? propertyId;
  final String? userId;
  final ReportReason reason;
  final String details;
  final DateTime createdAt;
}
