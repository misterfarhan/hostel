import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import 'notifications_screen.dart';

/// Opens a notification's deep link. Tab roots are switched to with `go`,
/// everything else is pushed on top so Back returns to where the user was.
void openNotificationLink(GoRouter router, String? link) {
  if (link == null) return;
  const tabRoots = {'/explore', '/favourites', '/visits', '/messages', '/profile', '/owner', '/owner/listings', '/owner/requests', '/owner/messages'};
  tabRoots.contains(link) ? router.go(link) : router.push(link);
}

/// Shows new notifications as a banner that slides down from the top while
/// the app is open. Free alternative to push notifications (no Firebase):
/// it listens to the same notification stream as the bell/notification
/// centre, so anything the backend adds pops up instantly.
class InAppNotificationHost extends ConsumerStatefulWidget {
  const InAppNotificationHost({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<InAppNotificationHost> createState() => _InAppNotificationHostState();
}

class _InAppNotificationHostState extends ConsumerState<InAppNotificationHost> {
  static const _visibleFor = Duration(seconds: 5);

  final _seen = <String>{};
  final _queue = <AppNotification>[];
  ProviderSubscription<AsyncValue<List<AppNotification>>>? _subscription;
  bool _primed = false;
  AppNotification? _current;
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    ref.listenManual(userProvider.select((u) => u?.id), (_, uid) => _subscribe(uid), fireImmediately: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.close();
    super.dispose();
  }

  /// (Re)subscribes when the signed-in user changes. The first value for a
  /// user is their history, which is remembered but not shown.
  void _subscribe(String? uid) {
    _subscription?.close();
    _subscription = null;
    _seen.clear();
    _queue.clear();
    _primed = false;
    if (_current != null) _hide();
    if (uid == null) return;
    _subscription = ref.listenManual(notificationsForUserProvider(uid), (_, next) => _onValue(next), fireImmediately: true);
  }

  void _onValue(AsyncValue<List<AppNotification>> value) {
    if (value.isLoading || !value.hasValue) return;
    final list = value.requireValue;
    if (!_primed) {
      _primed = true;
      _seen.addAll(list.map((n) => n.id));
      return;
    }
    // The list is newest-first; queue fresh ones oldest-first.
    for (final n in list.reversed) {
      if (_seen.add(n.id) && !n.read && !_isAlreadyOnScreen(n)) _queue.add(n);
    }
    if (_current == null) _showNext();
  }

  /// Don't pop up a chat message while the user is reading that chat.
  bool _isAlreadyOnScreen(AppNotification n) {
    final link = n.deepLink;
    if (link == null) return false;
    final location = ref.read(routerProvider).routerDelegate.currentConfiguration.uri.path;
    return location == link;
  }

  void _showNext() {
    if (!mounted || _queue.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _current = _queue.removeAt(0);
      _visible = true;
    });
    _timer?.cancel();
    _timer = Timer(_visibleFor, _hide);
  }

  void _hide() {
    _timer?.cancel();
    if (!mounted || _current == null) return;
    setState(() => _visible = false);
    // Wait for the slide-out animation, then show the next one.
    Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _current = null);
      _showNext();
    });
  }

  void _open(AppNotification n) {
    ref.read(notificationRepositoryProvider).markRead(n.id);
    _hide();
    openNotificationLink(ref.read(routerProvider), n.deepLink);
  }

  @override
  Widget build(BuildContext context) {
    final n = _current;
    return Stack(
      children: [
        widget.child,
        if (n != null)
          Positioned(
            left: 10,
            right: 10,
            top: 0,
            child: SafeArea(
              child: AnimatedSlide(
                offset: _visible ? Offset.zero : const Offset(0, -1.5),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: Dismissible(
                  key: ValueKey(n.id),
                  direction: DismissDirection.up,
                  onDismissed: (_) {
                    _timer?.cancel();
                    setState(() => _current = null);
                    _showNext();
                  },
                  child: _Banner(notification: n, onTap: () => _open(n), onClose: _hide),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.notification, required this.onTap, required this.onClose});
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        elevation: 10,
        shadowColor: Colors.black45,
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(NotificationsScreenIcons.iconFor(notification.category), color: scheme.onPrimaryContainer, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(visualDensity: VisualDensity.compact, onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 20)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
