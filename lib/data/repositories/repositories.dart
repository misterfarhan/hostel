import '../models/models.dart';

/// Repository contracts. The UI only talks to these interfaces. The bundled
/// `MockBackend` implements all of them in memory so the app runs without a
/// server; a REST/WebSocket (or Firebase) implementation can be dropped in
/// later by overriding the providers in `providers.dart`.

abstract interface class AuthRepository {
  Stream<AppUser?> watchCurrentUser();
  AppUser? get currentUser;

  /// Sends an OTP. Throws [AppException] when rate limited.
  Future<void> requestOtp(String phone);
  Future<AppUser> verifyOtp(String phone, String code);
  Future<AppUser> updateProfile(AppUser user);
  Future<void> logout();
  Future<void> deleteAccount();
  Future<AppUser?> userById(String id);

  /// Owner verification (spec 7.1).
  Future<AppUser> uploadOwnerDocument(String kind, String filePath);
  Future<AppUser> submitOwnerVerification();
}

abstract interface class PropertyRepository {
  /// All LIVE listings; emits again whenever any listing changes (real-time).
  Stream<List<Property>> watchLive();

  /// Server-side radius search. Implementations must only return LIVE
  /// listings within [SearchQuery.radiusKm] of the centre.
  Future<List<Property>> search(SearchQuery query);
  Stream<Property?> watchProperty(String id);
  Stream<List<Property>> watchOwnerProperties(String ownerId);
  Future<Property> saveProperty(Property property);
  Future<void> submitForReview(String id);
  Future<void> setStatus(String id, ListingStatus status);
  Future<void> updateAvailability(String id, int availableUnits);
  Future<void> updatePrice(String id, double price);
  Future<void> confirmStillAvailable(String id);
  Future<void> deleteProperty(String id);
  Future<void> recordView(String id);
  Stream<List<Review>> watchReviews(String propertyId);
  Future<void> addReview(Review review, {required String visitRequestId});
  Future<void> report(ListingReport report);

  /// Average price of similar LIVE listings nearby (price guidance hint).
  Future<double?> averagePrice({required String typeId, required String cityId, required String area});
}

abstract interface class ActivityRepository {
  Stream<Set<String>> watchFavourites(String userId);
  Future<void> toggleFavourite(String userId, String propertyId);

  Stream<List<SavedSearch>> watchSavedSearches(String userId);
  Future<void> saveSearch(String userId, String name, SearchQuery query);
  Future<void> toggleSearchAlerts(String id, bool enabled);
  Future<void> deleteSavedSearch(String id);

  Stream<List<VisitRequest>> watchSeekerVisits(String seekerId);
  Stream<List<VisitRequest>> watchOwnerVisits(String ownerId);
  Future<VisitRequest> requestVisit({required String propertyId, required String seekerId, required DateTime time, String message});
  Future<void> respondToVisit(String id, VisitStatus status, {DateTime? proposedTime});
  Future<void> confirmVisitCode(String id, String code);
  Future<void> setVisitOutcome(String id, VisitOutcome outcome);

  Stream<List<Inquiry>> watchOwnerInquiries(String ownerId);
  Future<void> sendInquiry({required String propertyId, required AppUser seeker, required String message, DateTime? preferredVisit});
  Future<void> markInquiryHandled(String id);

  Future<VisitJourney> startJourney({required String seekerId, required String propertyId, String? visitRequestId, required bool shareWithOwner});
  Future<void> updateJourney(VisitJourney journey);
}

abstract interface class ChatRepository {
  Stream<List<Conversation>> watchConversations(String userId);
  Stream<List<ChatMessage>> watchMessages(String conversationId);
  Future<Conversation> openConversation({required String propertyId, required String seekerId, required String ownerId});
  Future<void> sendMessage(ChatMessage message);
  Future<void> markRead(String conversationId, String userId);
  Future<void> block(String conversationId, String userId);
}

abstract interface class NotificationRepository {
  Stream<List<AppNotification>> watchNotifications(String userId);
  Future<void> markRead(String id);
  Future<void> markAllRead(String userId);
}

abstract interface class SupportRepository {
  List<FaqItem> get faqs;
  Stream<List<SupportTicket>> watchTickets(String userId);
  Future<SupportTicket> createTicket({required String userId, required String subject, required String category, required String message, String? propertyId});
  Future<void> replyToTicket(String id, String message);
}

class AppException implements Exception {
  const AppException(this.message);
  final String message;
  @override
  String toString() => message;
}
