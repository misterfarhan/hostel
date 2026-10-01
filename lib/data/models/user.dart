import 'enums.dart';
import 'location.dart';

enum OwnerBadge {
  verifiedOwner('Verified Owner'),
  fastResponder('Fast Responder'),
  topRated('Top Rated');

  const OwnerBadge(this.label);
  final String label;
}

class OwnerDocument {
  const OwnerDocument({required this.kind, required this.label, required this.status, this.required = true, this.filePath, this.note});

  final String kind;
  final String label;
  final DocumentStatus status;
  final bool required;
  final String? filePath;
  final String? note;

  OwnerDocument copyWith({DocumentStatus? status, String? filePath, String? note}) =>
      OwnerDocument(kind: kind, label: label, required: required, status: status ?? this.status, filePath: filePath ?? this.filePath, note: note ?? this.note);
}

class AppUser {
  const AppUser({
    required this.id,
    required this.phone,
    required this.name,
    this.photoUrl,
    this.countryId,
    this.cityId,
    this.email,
    this.ownerStatus = OwnerStatus.notSubmitted,
    this.documents = const [],
    this.savedPlaces = const [],
    this.rating = 0,
    this.ratingCount = 0,
    this.responseMinutes,
    this.badges = const [],
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.referralCode = '',
    this.languageCode = 'en',
    this.joinedAt,
  });

  final String id;
  final String phone;
  final String name;
  final String? photoUrl;
  final String? countryId;
  final String? cityId;
  final String? email;
  final OwnerStatus ownerStatus;
  final List<OwnerDocument> documents;
  final List<SavedPlace> savedPlaces;
  final double rating;
  final int ratingCount;

  /// Measured owner response time, shown as "Usually replies within ...".
  final int? responseMinutes;
  final List<OwnerBadge> badges;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String referralCode;
  final String languageCode;
  final DateTime? joinedAt;

  bool get isProfileComplete => name.trim().isNotEmpty && countryId != null && cityId != null;
  bool get canPublish => ownerStatus == OwnerStatus.approved;

  /// Phone numbers are never shown to other users (masked calling).
  String get maskedPhone {
    if (phone.length < 6) return '•••';
    return '${phone.substring(0, 3)} ••• ••${phone.substring(phone.length - 2)}';
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String get responseLabel {
    final m = responseMinutes;
    if (m == null) return 'New owner';
    if (m <= 15) return 'Usually replies within minutes';
    if (m <= 60) return 'Usually replies within 1 hour';
    if (m <= 180) return 'Usually replies within a few hours';
    return 'Usually replies within a day';
  }

  AppUser copyWith({
    String? name,
    String? photoUrl,
    String? countryId,
    String? cityId,
    String? email,
    OwnerStatus? ownerStatus,
    List<OwnerDocument>? documents,
    List<SavedPlace>? savedPlaces,
    List<OwnerBadge>? badges,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? languageCode,
  }) => AppUser(
    id: id,
    phone: phone,
    rating: rating,
    ratingCount: ratingCount,
    responseMinutes: responseMinutes,
    referralCode: referralCode,
    joinedAt: joinedAt,
    name: name ?? this.name,
    photoUrl: photoUrl ?? this.photoUrl,
    countryId: countryId ?? this.countryId,
    cityId: cityId ?? this.cityId,
    email: email ?? this.email,
    ownerStatus: ownerStatus ?? this.ownerStatus,
    documents: documents ?? this.documents,
    savedPlaces: savedPlaces ?? this.savedPlaces,
    badges: badges ?? this.badges,
    emergencyContactName: emergencyContactName ?? this.emergencyContactName,
    emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
    languageCode: languageCode ?? this.languageCode,
  );
}
