import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../data/providers.dart';

/// Views, favourites, inquiries and visits per listing (spec 7.2).
class PerformanceScreen extends ConsumerWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(ownerPropertiesProvider).value ?? const [];
    final maxViews = listings.fold<int>(1, (m, p) => max(m, p.viewsCount));
    final totals = [
      ('Views', listings.fold<int>(0, (s, p) => s + p.viewsCount), AppColors.verified),
      ('Favourites', listings.fold<int>(0, (s, p) => s + p.favouritesCount), Colors.redAccent),
      ('Inquiries', listings.fold<int>(0, (s, p) => s + p.inquiriesCount), AppColors.brand),
      ('Visits', listings.fold<int>(0, (s, p) => s + p.visitsCount), AppColors.featured),
    ];
    final views = totals[0].$2;
    final inquiries = totals[2].$2;
    final visits = totals[3].$2;

    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: listings.isEmpty
          ? const EmptyState(icon: Icons.insights_outlined, title: 'No data yet', message: 'Stats appear once your listings go live.')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        for (final (label, value, color) in totals)
                          Column(
                            children: [
                              Text(
                                Fmt.count(value),
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
                              ),
                              Text(label, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Conversion', style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text('View → inquiry: ${views == 0 ? 0 : (inquiries / views * 100).toStringAsFixed(1)}%'),
                        Text('Inquiry → visit: ${inquiries == 0 ? 0 : (visits / inquiries * 100).toStringAsFixed(1)}%'),
                      ],
                    ),
                  ),
                ),
                const SectionTitle('By listing', padding: EdgeInsets.fromLTRB(0, 16, 0, 8)),
                for (final p in listings)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => context.push('/manage/${p.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                ),
                                Pill(p.status.label, color: listingStatusColor(p.status), dense: true),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: p.viewsCount / maxViews, minHeight: 8, borderRadius: BorderRadius.circular(4)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 14,
                              children: [
                                _Metric(Icons.visibility_outlined, p.viewsCount),
                                _Metric(Icons.favorite_border, p.favouritesCount),
                                _Metric(Icons.mark_email_unread_outlined, p.inquiriesCount),
                                _Metric(Icons.directions_walk_rounded, p.visitsCount),
                                if (p.reviewCount > 0) RatingLabel(p.averageRating, count: p.reviewCount, size: 12),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.icon, this.value);
  final IconData icon;
  final int value;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
      const SizedBox(width: 3),
      Text(Fmt.count(value), style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );
}
