import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import '../../shell/app_shell.dart';

/// Seeker's visit requests and history (spec 7.4).
class VisitsScreen extends ConsumerWidget {
  const VisitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(seekerVisitsProvider).value ?? const [];
    final upcoming = visits.where((v) => v.status.isOpen).toList();
    final past = visits.where((v) => !v.status.isOpen).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My visits'),
          actions: const [NotificationBell()],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Upcoming (${upcoming.length})'),
              Tab(text: 'History (${past.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _VisitList(
              visits: upcoming,
              empty: EmptyState(
                icon: Icons.event_available_outlined,
                title: 'No upcoming visits',
                message: 'Open a listing and tap Visit to request a time with the owner.',
                action: FilledButton(onPressed: () => context.go('/explore'), child: const Text('Find places')),
              ),
            ),
            _VisitList(
              visits: past,
              empty: const EmptyState(icon: Icons.history_rounded, title: 'No past visits yet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitList extends StatelessWidget {
  const _VisitList({required this.visits, required this.empty});
  final List<VisitRequest> visits;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    if (visits.isEmpty) return empty;
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: visits.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => SeekerVisitCard(visit: visits[i]),
    );
  }
}

class SeekerVisitCard extends ConsumerWidget {
  const SeekerVisitCard({super.key, required this.visit});
  final VisitRequest visit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(propertyProvider(visit.propertyId)).value;
    final scheme = Theme.of(context).colorScheme;
    final repo = ref.read(activityRepositoryProvider);
    final canGo = visit.status == VisitStatus.accepted || visit.status == VisitStatus.onTheWay;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => context.push('/property/${visit.propertyId}'),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(width: 64, height: 64, child: AppImage(p?.mainPhoto)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p?.title ?? 'Property',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(p?.area ?? '', style: TextStyle(color: scheme.outline, fontSize: 12.5)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 15, color: scheme.outline),
                            const SizedBox(width: 4),
                            Text(Fmt.dateTime(visit.effectiveTime), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Pill(visit.status.label, color: visitStatusColor(visit.status)),
                ],
              ),
            ),
            if (visit.status == VisitStatus.rescheduled && visit.proposedTime != null) ...[
              const SizedBox(height: 10),
              Text('The owner suggested ${Fmt.dateTime(visit.proposedTime!)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: () => repo.respondToVisit(visit.id, VisitStatus.cancelled), child: const Text('Decline')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => repo.respondToVisit(visit.id, VisitStatus.accepted, proposedTime: visit.proposedTime),
                      child: const Text('Accept time'),
                    ),
                  ),
                ],
              ),
            ],
            if (canGo) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final ok = await confirmDialog(
                          context,
                          title: 'Cancel visit?',
                          message: 'The owner will be notified. Cancelling is free.',
                          confirm: 'Cancel visit',
                          destructive: true,
                        );
                        if (ok) repo.respondToVisit(visit.id, VisitStatus.cancelled);
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push('/property/${visit.propertyId}/go?visit=${visit.id}'),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Go There'),
                    ),
                  ),
                ],
              ),
            ],
            if (visit.status == VisitStatus.requested) ...[
              const SizedBox(height: 8),
              Text('Waiting for the owner to respond…', style: TextStyle(color: scheme.outline, fontSize: 12.5)),
            ],
            if (visit.status == VisitStatus.completed) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (visit.outcome != null) Pill(visit.outcome!.label, color: scheme.secondary),
                  const Spacer(),
                  if (!visit.reviewed)
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                      onPressed: () => context.push('/review/${visit.id}'),
                      icon: const Icon(Icons.star_outline_rounded),
                      label: const Text('Rate & review'),
                    )
                  else
                    Text('Reviewed ✓', style: TextStyle(color: scheme.outline)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
