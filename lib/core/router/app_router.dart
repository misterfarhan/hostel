import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/auth/profile_setup_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/chat/chat_list_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/owner/add_property/add_property_screen.dart';
import '../../features/owner/dashboard/owner_dashboard_screen.dart';
import '../../features/owner/dashboard/performance_screen.dart';
import '../../features/owner/dashboard/verification_screen.dart';
import '../../features/owner/listings/manage_listing_screen.dart';
import '../../features/owner/listings/my_listings_screen.dart';
import '../../features/owner/requests/owner_requests_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/saved_places_screen.dart';
import '../../features/profile/support_screen.dart';
import '../../features/seeker/detail/property_detail_screen.dart';
import '../../features/seeker/explore/explore_screen.dart';
import '../../features/seeker/favourites/compare_screen.dart';
import '../../features/seeker/favourites/favourites_screen.dart';
import '../../features/seeker/journey/journey_screen.dart';
import '../../features/seeker/journey/review_screen.dart';
import '../../features/seeker/saved/saved_searches_screen.dart';
import '../../features/seeker/visits/visits_screen.dart';
import '../../features/shell/app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Re-runs router redirects whenever the session or mode changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(currentUserProvider, (_, _) => notifyListeners());
    ref.listen(appModeProvider, (_, _) => notifyListeners());
  }
}

const _authPaths = {'/splash', '/login', '/otp', '/setup'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(currentUserProvider);
      final path = state.matchedLocation;
      if (auth.isLoading && !auth.hasValue) return '/splash';
      final user = auth.value;
      if (user == null) return (path == '/login' || path == '/otp') ? null : '/login';
      if (!user.isProfileComplete) return path == '/setup' ? null : '/setup';
      if (_authPaths.contains(path)) {
        return ref.read(appModeProvider) == AppMode.owner ? '/owner' : '/explore';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        builder: (_, s) => OtpScreen(phone: s.uri.queryParameters['phone'] ?? ''),
      ),
      GoRoute(path: '/setup', builder: (_, _) => const ProfileSetupScreen()),

      // Seeker mode tabs.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => SeekerShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/explore', builder: (_, _) => const ExploreScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/favourites', builder: (_, _) => const FavouritesScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/visits', builder: (_, _) => const VisitsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/messages', builder: (_, _) => const ChatListScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),

      // Owner mode tabs.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => OwnerShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/owner', builder: (_, _) => const OwnerDashboardScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/owner/listings', builder: (_, _) => const MyListingsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/owner/requests', builder: (_, _) => const OwnerRequestsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/owner/messages', builder: (_, _) => const ChatListScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/owner/profile', builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),

      // Full-screen pages above the tab bar.
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/property/:id',
        builder: (_, s) => PropertyDetailScreen(propertyId: s.pathParameters['id']!),
        routes: [
          GoRoute(
            parentNavigatorKey: _rootKey,
            path: 'go',
            builder: (_, s) => JourneyScreen(propertyId: s.pathParameters['id']!, visitId: s.uri.queryParameters['visit']),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/review/:visitId',
        builder: (_, s) => ReviewScreen(visitId: s.pathParameters['visitId']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/chat/:id',
        builder: (_, s) => ChatScreen(conversationId: s.pathParameters['id']!),
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/saved-searches', builder: (_, _) => const SavedSearchesScreen()),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/compare',
        builder: (_, s) => CompareScreen(ids: s.uri.queryParameters['ids']?.split(',') ?? const []),
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/support', builder: (_, _) => const SupportScreen()),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/support/:id',
        builder: (_, s) => TicketScreen(ticketId: s.pathParameters['id']!),
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/edit-profile', builder: (_, _) => const EditProfileScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/saved-places', builder: (_, _) => const SavedPlacesScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/owner-verification', builder: (_, _) => const VerificationScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/owner-performance', builder: (_, _) => const PerformanceScreen()),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/add-property',
        builder: (_, s) => AddPropertyScreen(editId: s.uri.queryParameters['edit']),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/manage/:id',
        builder: (_, s) => ManageListingScreen(propertyId: s.pathParameters['id']!),
      ),
    ],
  );
});
