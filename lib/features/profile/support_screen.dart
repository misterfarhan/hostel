import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

/// Support centre: FAQ + tickets (spec 14).
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faqs = ref.watch(supportRepositoryProvider).faqs;
    final tickets = ref.watch(ticketsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newTicket(context, ref),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New ticket'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          if (tickets.isNotEmpty) ...[
            const SectionTitle('Your tickets'),
            for (final t in tickets)
              ListTile(
                leading: const Icon(Icons.confirmation_number_outlined),
                title: Text(t.subject, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${t.id} · ${t.category} · ${Fmt.relative(t.createdAt)}'),
                trailing: Pill(
                  t.status.label,
                  color: t.status == TicketStatus.resolved || t.status == TicketStatus.closed ? Colors.green : Colors.orange,
                  dense: true,
                ),
                onTap: () => context.push('/support/${t.id}'),
              ),
          ],
          const SectionTitle('Frequently asked questions'),
          for (final f in faqs)
            ExpansionTile(
              title: Text(f.question, style: const TextStyle(fontWeight: FontWeight.w600)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [Text(f.answer)],
            ),
        ],
      ),
    );
  }

  Future<void> _newTicket(BuildContext context, WidgetRef ref) async {
    const categories = ['Listing problem', 'Visit problem', 'Account', 'Payment', 'Safety', 'Other'];
    var category = categories.first;
    final subject = TextEditingController();
    final message = TextEditingController();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Contact support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final c in categories) ChoiceChip(label: Text(c), selected: category == c, onSelected: (_) => setState(() => category = c))],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: message,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Describe the problem'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (subject.text.trim().isEmpty || message.text.trim().isEmpty) return;
                      await ref
                          .read(supportRepositoryProvider)
                          .createTicket(userId: ref.read(userProvider)!.id, subject: subject.text.trim(), category: category, message: message.text.trim());
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    },
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (created == true && context.mounted) showSnack(context, 'Ticket created. We usually reply within a few hours.');
  }
}

class TicketScreen extends ConsumerStatefulWidget {
  const TicketScreen({super.key, required this.ticketId});
  final String ticketId;
  @override
  ConsumerState<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends ConsumerState<TicketScreen> {
  final _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(ticketsProvider).value?.where((t) => t.id == widget.ticketId).firstOrNull;
    final scheme = Theme.of(context).colorScheme;
    if (t == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(t.id)),
      body: Column(
        children: [
          ListTile(
            title: Text(t.subject, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(t.category),
            trailing: Pill(t.status.label, color: scheme.primary),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final m in t.messages)
                  Align(
                    alignment: m.fromSupport ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
                      decoration: BoxDecoration(
                        color: m.fromSupport ? scheme.surfaceContainerHighest : scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (m.fromSupport) const Text('StayFinder Support', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          Text(m.text),
                          Text(Fmt.dateTime(m.sentAt), style: TextStyle(fontSize: 11, color: scheme.outline)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (t.status != TicketStatus.closed)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        decoration: const InputDecoration(hintText: 'Reply'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      onPressed: () {
                        if (_reply.text.trim().isEmpty) return;
                        ref.read(supportRepositoryProvider).replyToTicket(t.id, _reply.text.trim());
                        _reply.clear();
                      },
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
