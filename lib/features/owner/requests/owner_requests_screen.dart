import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import '../../shell/app_shell.dart';

/// Visit requests and inquiries for the owner (spec 7.4 and 8).
class OwnerRequestsScreen extends ConsumerWidget {
  const OwnerRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(ownerVisitsProvider).value ?? const [];
    final inquiries = ref.watch(ownerInquiriesProvider).value ?? const [];
    final pending = visits.where((v) => v.status == VisitStatus.requested).length;
    final unhandled = inquiries.where((i) => !i.handled).length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Requests'),
          actions: const [NotificationBell()],
          bottom: TabBar(
            tabs: [
              Tab(
                child: Badge(isLabelVisible: pending > 0, label: Text('$pending'), offset: const Offset(14, -4), child: const Text('Visit requests')),
              ),
              Tab(
                child: Badge(isLabelVisible: unhandled > 0, label: Text('$unhandled'), offset: const Offset(14, -4), child: const Text('Inquiries')),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            visits.isEmpty
                ? const EmptyState(
                    icon: Icons.event_outlined,
                    title: 'No visit requests yet',
                    message: 'Seekers can request a time to visit your live listings.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: visits.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _OwnerVisitCard(visit: visits[i]),
                  ),
            inquiries.isEmpty
                ? const EmptyState(icon: Icons.mark_email_unread_outlined, title: 'No inquiries yet')
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: inquiries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _InquiryCard(inquiry: inquiries[i]),
                  ),
          ],
        ),
      ),
    );
  }
}

class _OwnerVisitCard extends ConsumerWidget {
  const _OwnerVisitCard({required this.visit});
  final VisitRequest visit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(propertyProvider(visit.propertyId)).value;
    final seeker = ref.watch(userByIdProvider(visit.seekerId)).value;
    final repo = ref.read(activityRepositoryProvider);
    final scheme = Theme.of(context).colorScheme;

    Future<void> reschedule() async {
      final date = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 30)),
        initialDate: visit.preferredTime.isAfter(DateTime.now()) ? visit.preferredTime : DateTime.now(),
      );
      if (date == null || !context.mounted) return;
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(visit.preferredTime));
      if (time == null) return;
      await repo.respondToVisit(visit.id, VisitStatus.rescheduled, proposedTime: DateTime(date.year, date.month, date.day, time.hour, time.minute));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(seeker, radius: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(seeker?.name ?? 'Seeker', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        p?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.outline, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Pill(visit.status.label, color: visitStatusColor(visit.status)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Text(Fmt.dateTime(visit.effectiveTime), style: const TextStyle(fontWeight: FontWeight.w700)),
                if (visit.proposedTime != null) Text('  (you proposed)', style: TextStyle(color: scheme.outline, fontSize: 12)),
              ],
            ),
            if (visit.message.isNotEmpty) ...[const SizedBox(height: 6), Text('"${visit.message}"', style: const TextStyle(fontStyle: FontStyle.italic))],
            if (visit.status == VisitStatus.requested) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: () => repo.respondToVisit(visit.id, VisitStatus.declined), child: const Text('Decline')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(onPressed: reschedule, child: const Text('New time')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(onPressed: () => repo.respondToVisit(visit.id, VisitStatus.accepted), child: const Text('Accept')),
                  ),
                ],
              ),
            ],
            if (visit.status == VisitStatus.accepted || visit.status == VisitStatus.onTheWay || visit.status == VisitStatus.arrived) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    const Text('Visit code — show this to the visitor on arrival'),
                    const SizedBox(height: 4),
                    Text(
                      visit.visitCode ?? '----',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 10, color: scheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(onPressed: () => repo.respondToVisit(visit.id, VisitStatus.noShow), child: const Text('Mark no-show')),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final c = await ref
                            .read(chatRepositoryProvider)
                            .openConversation(propertyId: visit.propertyId, seekerId: visit.seekerId, ownerId: visit.ownerId);
                        if (context.mounted) context.push('/chat/${c.id}');
                      },
                      child: const Text('Message'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InquiryCard extends ConsumerWidget {
  const _InquiryCard({required this.inquiry});
  final Inquiry inquiry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(propertyProvider(inquiry.propertyId)).value;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(inquiry.seekerName[0])),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inquiry.seekerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        p?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.outline, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Text(Fmt.relative(inquiry.createdAt), style: TextStyle(color: scheme.outline, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(inquiry.message),
            if (inquiry.preferredVisit != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Preferred visit: ${Fmt.dateTime(inquiry.preferredVisit!)}',
                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!inquiry.handled)
                  TextButton(onPressed: () => ref.read(activityRepositoryProvider).markInquiryHandled(inquiry.id), child: const Text('Mark handled'))
                else
                  Text('Handled ✓', style: TextStyle(color: scheme.outline)),
                const Spacer(),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () async {
                    final c = await ref
                        .read(chatRepositoryProvider)
                        .openConversation(propertyId: inquiry.propertyId, seekerId: inquiry.seekerId, ownerId: ref.read(userProvider)!.id);
                    await ref.read(activityRepositoryProvider).markInquiryHandled(inquiry.id);
                    if (context.mounted) context.push('/chat/${c.id}');
                  },
                  icon: const Icon(Icons.reply_rounded),
                  label: const Text('Reply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
