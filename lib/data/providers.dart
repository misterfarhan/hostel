import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'mock/mock_backend.dart';
import 'models/models.dart';
import 'repositories/repositories.dart';
import 'services/location_service.dart';
import 'services/routing_service.dart';

// ---------------------------------------------------------------------------
// Infrastructure. Override these in `main.dart` (or tests) to plug in a real
// backend — nothing else in the app needs to change.
// ---------------------------------------------------------------------------

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('Override in main()'));

final configProvider = Provider<AppConfig>((ref) => AppConfig.defaults);

final mockBackendProvider = Provider<MockBackend>((ref) => MockBackend(ref.watch(configProvider), ref.watch(sharedPrefsProvider)));

final authRepositoryProvider = Provider<AuthRepository>((ref) => ref.watch(mockBackendProvider));
final propertyRepositoryProvider = Provider<PropertyRepository>((ref) => ref.watch(mockBackendProvider));
final activityRepositoryProvider = Provider<ActivityRepository>((ref) => ref.watch(mockBackendProvider));
final chatRepositoryProvider = Provider<ChatRepository>((ref) => ref.watch(mockBackendProvider));
final supportRepositoryProvider = Provider<SupportRepository>((ref) => ref.watch(mockBackendProvider));
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) => MockNotificationRepository(ref.watch(mockBackendProvider)));

final locationServiceProvider = Provider((ref) => LocationService());
final geocodingServiceProvider = Provider((ref) => GeocodingService());
final routingServiceProvider = Provider((ref) => RoutingService());

// ---------------------------------------------------------------------------
// Session
// ---------------------------------------------------------------------------

final currentUserProvider = StreamProvider<AppUser?>((ref) => ref.watch(authRepositoryProvider).watchCurrentUser());

/// Synchronous access to the signed-in user (null while logged out).
final userProvider = Provider<AppUser?>((ref) => ref.watch(currentUserProvider).value);

String _uid(Ref ref) => ref.watch(userProvider)?.id ?? '';

class AppModeNotifier extends Notifier<AppMode> {
  static const _key = 'app.mode';

  @override
  AppMode build() {
    final saved = ref.read(sharedPrefsProvider).getString(_key);
    return saved == 'owner' ? AppMode.owner : AppMode.seeker;
  }

  void set(AppMode mode) {
    state = mode;
    ref.read(sharedPrefsProvider).setString(_key, mode.name);
  }
}

final appModeProvider = NotifierProvider<AppModeNotifier, AppMode>(AppModeNotifier.new);

// ---------------------------------------------------------------------------
// Data streams
// ---------------------------------------------------------------------------

final livePropertiesProvider = StreamProvider<List<Property>>((ref) => ref.watch(propertyRepositoryProvider).watchLive());

final propertyProvider = StreamProvider.family<Property?, String>((ref, id) => ref.watch(propertyRepositoryProvider).watchProperty(id));

final reviewsProvider = StreamProvider.family<List<Review>, String>((ref, id) => ref.watch(propertyRepositoryProvider).watchReviews(id));

final userByIdProvider = FutureProvider.family<AppUser?, String>((ref, id) => ref.watch(authRepositoryProvider).userById(id));

final favouritesProvider = StreamProvider<Set<String>>((ref) => ref.watch(activityRepositoryProvider).watchFavourites(_uid(ref)));

final savedSearchesProvider = StreamProvider<List<SavedSearch>>((ref) => ref.watch(activityRepositoryProvider).watchSavedSearches(_uid(ref)));

final seekerVisitsProvider = StreamProvider<List<VisitRequest>>((ref) => ref.watch(activityRepositoryProvider).watchSeekerVisits(_uid(ref)));

final ownerVisitsProvider = StreamProvider<List<VisitRequest>>((ref) => ref.watch(activityRepositoryProvider).watchOwnerVisits(_uid(ref)));

final ownerInquiriesProvider = StreamProvider<List<Inquiry>>((ref) => ref.watch(activityRepositoryProvider).watchOwnerInquiries(_uid(ref)));

final ownerPropertiesProvider = StreamProvider<List<Property>>((ref) => ref.watch(propertyRepositoryProvider).watchOwnerProperties(_uid(ref)));

final conversationsProvider = StreamProvider<List<Conversation>>((ref) => ref.watch(chatRepositoryProvider).watchConversations(_uid(ref)));

final messagesProvider = StreamProvider.family<List<ChatMessage>, String>((ref, id) => ref.watch(chatRepositoryProvider).watchMessages(id));

/// Notifications of one specific user (used by the in-app popup so the first
/// value it sees is guaranteed to belong to that user).
final notificationsForUserProvider = StreamProvider.family<List<AppNotification>, String>(
  (ref, uid) => ref.watch(notificationRepositoryProvider).watchNotifications(uid),
);

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) => ref.watch(notificationRepositoryProvider).watchNotifications(_uid(ref)));

final ticketsProvider = StreamProvider<List<SupportTicket>>((ref) => ref.watch(supportRepositoryProvider).watchTickets(_uid(ref)));

// ---------------------------------------------------------------------------
// Badges
// ---------------------------------------------------------------------------

final unreadNotificationsProvider = Provider<int>((ref) => ref.watch(notificationsProvider).value?.where((n) => !n.read).length ?? 0);

final unreadMessagesProvider = Provider<int>((ref) {
  final me = _uid(ref);
  final mode = ref.watch(appModeProvider);
  return ref
          .watch(conversationsProvider)
          .value
          ?.where((c) => mode == AppMode.owner ? c.ownerId == me : c.seekerId == me)
          .fold<int>(0, (sum, c) => sum + (c.unreadFor[me] ?? 0)) ??
      0;
});

final pendingOwnerRequestsProvider = Provider<int>((ref) {
  final visits = ref.watch(ownerVisitsProvider).value ?? const [];
  final inquiries = ref.watch(ownerInquiriesProvider).value ?? const [];
  return visits.where((v) => v.status == VisitStatus.requested).length + inquiries.where((i) => !i.handled).length;
});
