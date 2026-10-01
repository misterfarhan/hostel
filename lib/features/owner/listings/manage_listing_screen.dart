import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import 'my_listings_screen.dart';

/// Owner view of one listing: status, availability, price and actions.
class ManageListingScreen extends ConsumerWidget {
  const ManageListingScreen({super.key, required this.propertyId});
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(propertyProvider(propertyId)).value;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.home_work_outlined, title: 'Listing not found'),
      );
    }
    final config = ref.watch(configProvider);
    final type = config.type(p.typeId);
    final country = config.country(p.countryId);
    final repo = ref.read(propertyRepositoryProvider);
    final scheme = Theme.of(context).colorScheme;

    Future<void> run(Future<void> Function() action, String done) async {
      try {
        await action();
        if (context.mounted) showSnack(context, done);
      } catch (e) {
        if (context.mounted) showSnack(context, e.toString(), error: true);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage listing'),
        actions: [IconButton(tooltip: 'Edit', onPressed: () => context.push('/add-property?edit=${p.id}'), icon: const Icon(Icons.edit_outlined))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: AppImage(p.mainPhoto, fallbackIcon: type.icon, color: type.color),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Pill(p.status.label, color: listingStatusColor(p.status), solid: true),
              const SizedBox(width: 6),
              TypePill(type),
              if (p.isVerified) ...[const SizedBox(width: 6), const VerifiedPill()],
            ],
          ),
          const SizedBox(height: 8),
          Text(p.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text('${p.area}, ${config.city(p.cityId).name}', style: TextStyle(color: scheme.outline)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                Fmt.price(p, country),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: scheme.primary),
              ),
              const SizedBox(width: 8),
              TextButton.icon(onPressed: () => _editPrice(context, ref, p), icon: const Icon(Icons.edit, size: 16), label: const Text('Update price')),
            ],
          ),
          if (p.status == ListingStatus.rejected && p.rejectionReason != null)
            Card(
              color: scheme.errorContainer,
              child: ListTile(title: const Text('Rejected'), subtitle: Text(p.rejectionReason!)),
            ),
          if (p.status == ListingStatus.pendingReview)
            const Card(
              child: ListTile(
                leading: Icon(Icons.hourglass_top_rounded, color: AppColors.warning),
                title: Text('In review'),
                subtitle: Text('Our team checks every listing before it goes live. You will be notified.'),
              ),
            ),
          if (type.usesUnits && (p.status == ListingStatus.live || p.status == ListingStatus.full)) ...[
            const SizedBox(height: 8),
            Card(
              clipBehavior: Clip.antiAlias,
              child: SeatsStepper(property: p, label: type.unitsLabel),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat('Views', p.viewsCount),
                  _Stat('Saved', p.favouritesCount),
                  _Stat('Inquiries', p.inquiriesCount),
                  _Stat('Visits', p.visitsCount),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (p.expiresAt != null)
            Text(
              'Expires ${Fmt.date(p.expiresAt!)} · Last confirmed ${Fmt.relative(p.lastConfirmedAt ?? p.createdAt)}',
              style: TextStyle(color: scheme.outline, fontSize: 12.5),
            ),
          const SizedBox(height: 12),
          if (p.status == ListingStatus.draft || p.status == ListingStatus.rejected)
            FilledButton.icon(
              onPressed: () => run(() => repo.submitForReview(p.id), 'Submitted for review'),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Submit for review'),
            ),
          if (p.status == ListingStatus.live) ...[
            OutlinedButton.icon(
              onPressed: () => run(() => repo.confirmStillAvailable(p.id), 'Thanks! Listing confirmed.'),
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('Confirm still available'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => run(() => repo.setStatus(p.id, ListingStatus.paused), 'Listing paused'),
              icon: const Icon(Icons.pause_circle_outline),
              label: const Text('Pause listing'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => run(() => repo.setStatus(p.id, p.purpose == ListingPurpose.sale ? ListingStatus.sold : ListingStatus.rented), 'Marked as done'),
              icon: const Icon(Icons.key_rounded),
              label: Text(p.purpose == ListingPurpose.sale ? 'Mark as sold' : 'Mark as rented'),
            ),
          ],
          if (p.status == ListingStatus.paused || p.status == ListingStatus.expired || p.status == ListingStatus.rented || p.status == ListingStatus.sold)
            FilledButton.icon(
              onPressed: () => run(() => repo.setStatus(p.id, ListingStatus.live), 'Listing is live again'),
              icon: const Icon(Icons.play_circle_outline),
              label: Text(p.status == ListingStatus.expired ? 'Renew listing' : 'Reactivate'),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/property/${p.id}'),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('View as seeker'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () async {
              if (await confirmDialog(context, title: 'Delete listing?', message: 'This cannot be undone.', confirm: 'Delete', destructive: true)) {
                await repo.deleteProperty(p.id);
                if (context.mounted) context.pop();
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete listing'),
          ),
        ],
      ),
    );
  }

  Future<void> _editPrice(BuildContext context, WidgetRef ref, Property p) async {
    final c = TextEditingController(text: p.price.round().toString());
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update price'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(prefixText: '${p.currency} ', suffixText: p.pricePeriod.suffix),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, double.tryParse(c.text)), child: const Text('Save')),
        ],
      ),
    );
    if (v != null && v > 0) {
      await ref.read(propertyRepositoryProvider).updatePrice(p.id, v);
      if (context.mounted) showSnack(context, 'Price updated. Seekers who saved it will be notified of drops.');
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(Fmt.count(value), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
    ],
  );
}
