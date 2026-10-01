import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';

class _Tab {
  const _Tab(this.icon, this.selectedIcon, this.label, {this.badge = 0});
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
}

class _Shell extends StatelessWidget {
  const _Shell({required this.shell, required this.tabs});
  final StatefulNavigationShell shell;
  final List<_Tab> tabs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Badge(isLabelVisible: t.badge > 0, label: Text('${t.badge}'), child: Icon(t.icon)),
              selectedIcon: Badge(isLabelVisible: t.badge > 0, label: Text('${t.badge}'), child: Icon(t.selectedIcon)),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class SeekerShell extends ConsumerWidget {
  const SeekerShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadMessagesProvider);
    final upcoming = ref.watch(seekerVisitsProvider).value?.where((v) => v.status.isOpen).length ?? 0;
    return _Shell(
      shell: shell,
      tabs: [
        const _Tab(Icons.map_outlined, Icons.map_rounded, 'Explore'),
        const _Tab(Icons.favorite_border_rounded, Icons.favorite_rounded, 'Saved'),
        _Tab(Icons.event_outlined, Icons.event_rounded, 'Visits', badge: upcoming),
        _Tab(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Messages', badge: unread),
        const _Tab(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
      ],
    );
  }
}

class OwnerShell extends ConsumerWidget {
  const OwnerShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadMessagesProvider);
    final pending = ref.watch(pendingOwnerRequestsProvider);
    return _Shell(
      shell: shell,
      tabs: [
        const _Tab(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home'),
        const _Tab(Icons.home_work_outlined, Icons.home_work_rounded, 'Listings'),
        _Tab(Icons.inbox_outlined, Icons.inbox_rounded, 'Requests', badge: pending),
        _Tab(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Messages', badge: unread),
        const _Tab(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
      ],
    );
  }
}

/// Bell icon with unread badge, used in app bars.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, this.onMap = false});
  final bool onMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationsProvider);
    final button = IconButton(
      tooltip: 'Notifications',
      onPressed: () => context.push('/notifications'),
      icon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.notifications_none_rounded)),
    );
    if (!onMap) return button;
    return Material(color: Theme.of(context).colorScheme.surface, shape: const CircleBorder(), elevation: 3, child: button);
  }
}
