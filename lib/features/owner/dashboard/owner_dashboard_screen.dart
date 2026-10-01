import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import '../../shell/app_shell.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final config = ref.watch(configProvider);
    final listings = ref.watch(ownerPropertiesProvider).value ?? const [];
    final visits = ref.watch(ownerVisitsProvider).value ?? const [];
    final inquiries = ref.watch(ownerInquiriesProvider).value ?? const [];
    if (user == null) return const SizedBox.shrink();

    final live = listings.where((p) => p.status == ListingStatus.live).length;
    final views = listings.fold<int>(0, (s, p) => s + p.viewsCount);
    final favs = listings.fold<int>(0, (s, p) => s + p.favouritesCount);
    final visitsDone = listings.fold<int>(0, (s, p) => s + p.visitsCount);
    final pendingVisits = visits.where((v) => v.status == VisitStatus.requested).toList();
    final newInquiries = inquiries.where((i) => !i.handled).toList();
    final staleCutoff = DateTime.now().subtract(Duration(days: config.staleListingDays));
    final stale = listings.where((p) => p.status == ListingStatus.live && (p.lastConfirmedAt ?? p.createdAt).isBefore(staleCutoff)).toList();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('Hi ${user.name.split(' ').first}'), actions: const [NotificationBell()]),
      floatingActionButton: user.canPublish
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/add-property'),
              icon: const Icon(Icons.add_home_outlined),
              label: const Text('Add property'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          if (!user.canPublish) _VerificationBanner(status: user.ownerStatus),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.9,
            children: [
              _StatTile(
                icon: Icons.home_work_rounded,
                label: 'Live listings',
                value: '$live / ${listings.length}',
                color: AppColors.brand,
                onTap: () => context.go('/owner/listings'),
              ),
              _StatTile(
                icon: Icons.visibility_rounded,
                label: 'Views',
                value: Fmt.count(views),
                color: AppColors.verified,
                onTap: () => context.push('/owner-performance'),
              ),
              _StatTile(
                icon: Icons.favorite_rounded,
                label: 'Favourites',
                value: Fmt.count(favs),
                color: Colors.redAccent,
                onTap: () => context.push('/owner-performance'),
              ),
              _StatTile(
                icon: Icons.directions_walk_rounded,
                label: 'Visits',
                value: Fmt.count(visitsDone),
                color: AppColors.featured,
                onTap: () => context.push('/owner-performance'),
              ),
            ],
          ),
          if (stale.isNotEmpty) ...[
            const SectionTitle('Still available?', padding: EdgeInsets.fromLTRB(0, 20, 0, 8)),
            for (final p in stale)
              Card(
                color: const Color(0xFFFFF8E1),
                child: ListTile(
                  leading: const Icon(Icons.schedule_rounded, color: AppColors.warning),
                  title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Not confirmed for ${config.staleListingDays}+ days. Unconfirmed listings are paused automatically.'),
                  trailing: TextButton(onPressed: () => ref.read(propertyRepositoryProvider).confirmStillAvailable(p.id), child: const Text('Yes')),
                ),
              ),
          ],
          SectionTitle(
            'Visit requests',
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
            trailing: TextButton(onPressed: () => context.go('/owner/requests'), child: const Text('See all')),
          ),
          if (pendingVisits.isEmpty && newInquiries.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  listings.isEmpty ? 'Add your first property to start receiving inquiries.' : 'No new requests. We will notify you instantly.',
                  style: TextStyle(color: scheme.outline),
                ),
              ),
            ),
          for (final v in pendingVisits.take(3)) _RequestPreview(title: 'Visit request', time: v.effectiveTime, propertyId: v.propertyId),
          for (final i in newInquiries.take(3)) _RequestPreview(title: '${i.seekerName}: "${i.message}"', time: i.createdAt, propertyId: i.propertyId),
          const SectionTitle('Quick actions', padding: EdgeInsets.fromLTRB(0, 20, 0, 8)),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Quick(
                icon: Icons.add_home_outlined,
                label: 'Add property',
                onTap: () => user.canPublish ? context.push('/add-property') : context.push('/owner-verification'),
              ),
              _Quick(icon: Icons.inbox_outlined, label: 'Requests', onTap: () => context.go('/owner/requests')),
              _Quick(icon: Icons.insights_outlined, label: 'Performance', onTap: () => context.push('/owner-performance')),
              _Quick(icon: Icons.badge_outlined, label: 'Documents', onTap: () => context.push('/owner-verification')),
              _Quick(icon: Icons.support_agent_rounded, label: 'Support', onTap: () => context.push('/support')),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({required this.status});
  final OwnerStatus status;

  @override
  Widget build(BuildContext context) {
    final (title, body, color) = switch (status) {
      OwnerStatus.notSubmitted => ('Verify your account to start listing', 'Upload your ID and proof of ownership. It takes 2 minutes.', AppColors.warning),
      OwnerStatus.pending ||
      OwnerStatus.underReview => ('Verification under review', 'We are checking your documents. You will be notified soon.', AppColors.verified),
      OwnerStatus.rejected => ('Verification rejected', 'Please re-upload clear documents.', AppColors.danger),
      _ => ('Account ${status.label.toLowerCase()}', 'Contact support for help.', AppColors.danger),
    };
    return Card(
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/owner-verification'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.verified_user_outlined, color: color, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.w800, color: color),
                    ),
                    const SizedBox(height: 2),
                    Text(body, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value, required this.color, this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                  Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RequestPreview extends ConsumerWidget {
  const _RequestPreview({required this.title, required this.time, required this.propertyId});
  final String title;
  final DateTime time;
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(propertyProvider(propertyId)).value;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.go('/owner/requests'),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 44, height: 44, child: AppImage(p?.mainPhoto)),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${p?.title ?? ''} · ${Fmt.dateTime(time)}', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 32 - 20) / 3,
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
