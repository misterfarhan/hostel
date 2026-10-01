import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import '../../shell/app_shell.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  static const _tabs = <(String, Set<ListingStatus>?)>[
    ('All', null),
    ('Live', {ListingStatus.live}),
    ('In review', {ListingStatus.pendingReview, ListingStatus.rejected}),
    ('Drafts', {ListingStatus.draft}),
    ('Inactive', {ListingStatus.paused, ListingStatus.full, ListingStatus.rented, ListingStatus.sold, ListingStatus.expired, ListingStatus.suspended}),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(ownerPropertiesProvider).value ?? const [];
    final user = ref.watch(userProvider);
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My properties'),
          actions: const [NotificationBell()],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final (label, statuses) in _tabs)
                Tab(text: '$label (${statuses == null ? listings.length : listings.where((p) => statuses.contains(p.status)).length})'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => user?.canPublish == true ? context.push('/add-property') : context.push('/owner-verification'),
          icon: const Icon(Icons.add_home_outlined),
          label: const Text('Add property'),
        ),
        body: TabBarView(
          children: [
            for (final (_, statuses) in _tabs)
              Builder(
                builder: (context) {
                  final list = statuses == null ? listings : listings.where((p) => statuses.contains(p.status)).toList();
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Icons.home_work_outlined,
                      title: 'Nothing here yet',
                      message: user?.canPublish == true ? 'Tap "Add property" to create a listing.' : 'Get verified to start listing your properties.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => OwnerListingCard(property: list[i]),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class OwnerListingCard extends ConsumerWidget {
  const OwnerListingCard({super.key, required this.property});
  final Property property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final type = config.type(property.typeId);
    final country = config.country(property.countryId);
    final repo = ref.read(propertyRepositoryProvider);
    final scheme = Theme.of(context).colorScheme;
    final p = property;
    final seatsEditable = type.usesUnits && (p.status == ListingStatus.live || p.status == ListingStatus.full);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/manage/${p.id}'),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: AppImage(p.mainPhoto, fallbackIcon: type.icon, color: type.color),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Pill(p.status.label, color: listingStatusColor(p.status), dense: true),
                            if (p.isVerified) ...[const SizedBox(width: 4), const VerifiedPill(dense: true)],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        Text(
                          Fmt.price(p, country, compact: true),
                          style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '👁 ${Fmt.count(p.viewsCount)}   ♥ ${Fmt.count(p.favouritesCount)}   ✉ ${p.inquiriesCount}   🚶 ${p.visitsCount}',
                          style: TextStyle(fontSize: 12, color: scheme.outline),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      switch (v) {
                        case 'edit':
                          context.push('/add-property?edit=${p.id}');
                        case 'pause':
                          await repo.setStatus(p.id, ListingStatus.paused);
                        case 'live':
                          await repo.setStatus(p.id, ListingStatus.live);
                        case 'rented':
                          await repo.setStatus(p.id, p.purpose == ListingPurpose.sale ? ListingStatus.sold : ListingStatus.rented);
                        case 'delete':
                          if (context.mounted &&
                              await confirmDialog(context, title: 'Delete listing?', message: 'This cannot be undone.', confirm: 'Delete', destructive: true)) {
                            await repo.deleteProperty(p.id);
                          }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (p.status == ListingStatus.live) const PopupMenuItem(value: 'pause', child: Text('Pause')),
                      if (p.status == ListingStatus.paused || p.status == ListingStatus.expired)
                        PopupMenuItem(value: 'live', child: Text(p.status == ListingStatus.expired ? 'Renew' : 'Reactivate')),
                      if (p.status == ListingStatus.live)
                        PopupMenuItem(value: 'rented', child: Text(p.purpose == ListingPurpose.sale ? 'Mark sold' : 'Mark rented')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
            ),
            if (p.status == ListingStatus.rejected && p.rejectionReason != null)
              Container(
                width: double.infinity,
                color: scheme.errorContainer,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text('Rejected: ${p.rejectionReason}', style: TextStyle(color: scheme.onErrorContainer)),
              ),
            if (seatsEditable) SeatsStepper(property: p, label: type.unitsLabel),
          ],
        ),
      ),
    );
  }
}

/// Hostel seats counter (spec 7.3). Hitting zero marks the listing FULL.
class SeatsStepper extends ConsumerWidget {
  const SeatsStepper({super.key, required this.property, required this.label});
  final Property property;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(propertyRepositoryProvider);
    final p = property;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.event_seat_outlined, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$label available', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          IconButton(
            onPressed: p.availableUnits > 0 ? () => repo.updateAvailability(p.id, p.availableUnits - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${p.availableUnits}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: p.availableUnits < p.totalUnits ? () => repo.updateAvailability(p.id, p.availableUnits + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
          Text('/ ${p.totalUnits}', style: TextStyle(color: scheme.outline)),
        ],
      ),
    );
  }
}
