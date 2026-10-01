import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../shell/app_shell.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(userProvider);
    final mode = ref.watch(appModeProvider);
    final all = ref.watch(conversationsProvider).value ?? const [];
    final list = all.where((c) => mode == AppMode.owner ? c.ownerId == me?.id : c.seekerId == me?.id).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Messages'), actions: const [NotificationBell()]),
      body: list.isEmpty
          ? EmptyState(
              icon: Icons.forum_outlined,
              title: 'No conversations yet',
              message: mode == AppMode.owner
                  ? 'When seekers message you about a listing, it shows up here.'
                  : 'Open a listing and tap Chat to ask the owner a question. Your number stays private.',
            )
          : ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(indent: 76),
              itemBuilder: (_, i) => _ConversationTile(conversation: list[i], me: me!.id),
            ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation, required this.me});
  final Conversation conversation;
  final String me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final other = ref.watch(userByIdProvider(conversation.otherParty(me))).value;
    final property = ref.watch(propertyProvider(conversation.propertyId)).value;
    final unread = conversation.unreadFor[me] ?? 0;
    final scheme = Theme.of(context).colorScheme;
    final last = conversation.lastMessage;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => context.push('/chat/${conversation.id}'),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          UserAvatar(other, radius: 24),
          Positioned(
            right: -4,
            bottom: -4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(width: 24, height: 24, child: AppImage(property?.mainPhoto)),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              other?.name ?? '…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600),
            ),
          ),
          if (last != null) Text(Fmt.relative(last.sentAt), style: TextStyle(fontSize: 12, color: scheme.outline)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            property?.title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.primary),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  last == null ? 'Say hello 👋' : '${last.senderId == me ? 'You: ' : ''}${last.preview}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.normal),
                ),
              ),
              if (unread > 0) Badge(label: Text('$unread')),
            ],
          ),
        ],
      ),
    );
  }
}
