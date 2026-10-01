import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import 'in_app_notification_host.dart';

/// Notification centre with categories (spec 12).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(notificationsProvider).value ?? const [];
    final list = _filter == null ? all : all.where((n) => n.category == _filter).toList();
    final me = ref.watch(userProvider);
    final repo = ref.read(notificationRepositoryProvider);
    final scheme = Theme.of(context).colorScheme;
    final present = all.map((n) => n.category).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [if (all.any((n) => !n.read)) TextButton(onPressed: () => repo.markAllRead(me!.id), child: const Text('Mark all read'))],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(label: const Text('All'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
                ),
                for (final c in NotificationCategory.values.where(present.contains))
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(label: Text(c.label), selected: _filter == c, onSelected: (_) => setState(() => _filter = c)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(icon: Icons.notifications_none_rounded, title: 'You are all caught up')
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(indent: 72),
                    itemBuilder: (_, i) {
                      final n = list[i];
                      return ListTile(
                        tileColor: n.read ? null : scheme.primaryContainer.withValues(alpha: 0.25),
                        leading: CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          child: Icon(NotificationsScreenIcons.iconFor(n.category), color: scheme.onPrimaryContainer),
                        ),
                        title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w800)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.body),
                            const SizedBox(height: 2),
                            Text('${n.category.label} · ${Fmt.relative(n.createdAt)}', style: TextStyle(fontSize: 12, color: scheme.outline)),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () {
                          repo.markRead(n.id);
                          openNotificationLink(GoRouter.of(context), n.deepLink);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

abstract final class NotificationsScreenIcons {
  static IconData iconFor(NotificationCategory c) => switch (c) {
    NotificationCategory.properties => Icons.home_work_outlined,
    NotificationCategory.visits => Icons.event_outlined,
    NotificationCategory.messages => Icons.chat_bubble_outline_rounded,
    NotificationCategory.payments => Icons.payments_outlined,
    NotificationCategory.promotions => Icons.local_offer_outlined,
    NotificationCategory.security => Icons.shield_outlined,
    NotificationCategory.support => Icons.support_agent_rounded,
    NotificationCategory.system => Icons.info_outline_rounded,
  };
}
