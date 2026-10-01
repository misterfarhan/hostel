import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/env.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/map_widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../seeker/detail/detail_actions.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _seekerQuickReplies = ['Is it still available?', 'Can I visit today?', 'Is the price negotiable?', 'Are bills included?'];
  static const _ownerQuickReplies = [
    'Yes, it is available.',
    'You can visit between 11 AM and 7 PM.',
    'Please send a visit request.',
    'Sorry, it is no longer available.',
  ];

  final _text = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send({String? text, MessageKind kind = MessageKind.text, String? imagePath, LatLng? location}) async {
    final me = ref.read(userProvider);
    if (me == null) return;
    final body = text ?? _text.text.trim();
    if (kind == MessageKind.text && body.isEmpty) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            ChatMessage(
              id: 'm_${DateTime.now().microsecondsSinceEpoch}',
              conversationId: widget.conversationId,
              senderId: me.id,
              kind: kind,
              sentAt: DateTime.now(),
              text: body,
              imagePath: imagePath,
              location: location,
            ),
          );
      if (text == null) _text.clear();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _attach() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Photo'), onTap: () => Navigator.pop(ctx, 'photo')),
            ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Camera'), onTap: () => Navigator.pop(ctx, 'camera')),
            ListTile(leading: const Icon(Icons.my_location_rounded), title: const Text('My location'), onTap: () => Navigator.pop(ctx, 'location')),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'location') {
      final pos = await ref.read(locationServiceProvider).current();
      if (pos == null) {
        if (mounted) showSnack(context, 'Location is not available', error: true);
        return;
      }
      await _send(kind: MessageKind.location, text: 'My location', location: pos);
      return;
    }
    try {
      final file = await ImagePicker().pickImage(source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 1400, imageQuality: 75);
      if (file != null) await _send(kind: MessageKind.image, text: '', imagePath: file.path);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not open the camera or gallery', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(userProvider);
    final convo = ref.watch(conversationsProvider).value?.where((c) => c.id == widget.conversationId).firstOrNull;
    final messages = ref.watch(messagesProvider(widget.conversationId)).value ?? const [];
    if (me == null || convo == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Mark as read whenever new messages arrive while this screen is open.
    if ((convo.unreadFor[me.id] ?? 0) > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(chatRepositoryProvider).markRead(convo.id, me.id));
    }

    final otherId = convo.otherParty(me.id);
    final other = ref.watch(userByIdProvider(otherId)).value;
    final property = ref.watch(propertyProvider(convo.propertyId)).value;
    final iAmSeeker = convo.seekerId == me.id;
    final blocked = convo.blockedBy != null;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(other, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(other?.name ?? '…', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(
                    iAmSeeker ? (other?.responseLabel ?? '') : 'Seeker',
                    style: TextStyle(fontSize: 12, color: scheme.outline, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (kMaskedCallingEnabled && iAmSeeker && property != null)
            IconButton(tooltip: 'Call (masked)', onPressed: () => maskedCall(context, ref, property), icon: const Icon(Icons.call_outlined)),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'report') showReportSheet(context, ref, userId: otherId);
              if (v == 'block') {
                final ok = await confirmDialog(
                  context,
                  title: 'Block ${other?.name ?? 'user'}?',
                  message: 'They will not be able to message you about this listing.',
                  confirm: 'Block',
                  destructive: true,
                );
                if (ok) await ref.read(chatRepositoryProvider).block(convo.id, me.id);
              }
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: Text('Report')), PopupMenuItem(value: 'block', child: Text('Block'))],
          ),
        ],
      ),
      body: Column(
        children: [
          if (property != null)
            Material(
              color: scheme.surface,
              child: ListTile(
                onTap: () => context.push('/property/${property.id}'),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 44, height: 44, child: AppImage(property.mainPhoto)),
                ),
                title: Text(
                  property.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: Text(Fmt.price(property, ref.watch(configProvider).country(property.countryId)), style: TextStyle(color: scheme.primary)),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFFFFF8E1),
            child: const Text(
              '🔒 Keep payments and chats inside StayFinder. Never pay before visiting.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6D4C00)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[messages.length - 1 - i];
                return _Bubble(message: m, mine: m.senderId == me.id);
              },
            ),
          ),
          if (blocked)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('This conversation is blocked.', style: TextStyle(color: scheme.outline)),
            )
          else ...[
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final q in iAmSeeker ? _seekerQuickReplies : _ownerQuickReplies)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(q),
                        onPressed: () => _send(text: q),
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: [
                    IconButton(onPressed: _attach, icon: const Icon(Icons.add_circle_outline_rounded)),
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(hintText: 'Message', contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(onPressed: () => _send(), icon: const Icon(Icons.send_rounded)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = mine ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = mine ? scheme.onPrimary : scheme.onSurface;
    Widget content = switch (message.kind) {
      MessageKind.image => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 200, height: 200, child: AppImage(message.imagePath)),
      ),
      MessageKind.location when message.location != null => GestureDetector(
        onTap: () => launchUrl(
          Uri.parse('https://www.google.com/maps/search/?api=1&query=${message.location!.latitude},${message.location!.longitude}'),
          mode: LaunchMode.externalApplication,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 220,
            height: 130,
            child: IgnorePointer(
              child: FlutterMap(
                options: MapOptions(initialCenter: message.location!, initialZoom: 15),
                children: [
                  appTileLayer(),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: message.location!,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 32),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      _ => Text(message.text, style: TextStyle(color: fg, fontSize: 15)),
    };
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: message.kind == MessageKind.text ? const EdgeInsets.symmetric(horizontal: 14, vertical: 9) : const EdgeInsets.all(4),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            content,
            const SizedBox(height: 2),
            Padding(
              padding: message.kind == MessageKind.text ? EdgeInsets.zero : const EdgeInsets.only(right: 6, bottom: 2),
              child: Text(Fmt.time(message.sentAt), style: TextStyle(fontSize: 10.5, color: mine ? fg.withValues(alpha: 0.75) : scheme.outline)),
            ),
          ],
        ),
      ),
    );
  }
}
