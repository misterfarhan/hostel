import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/common.dart';
import '../../../data/providers.dart';
import '../explore/search_controller.dart';

class SavedSearchesScreen extends ConsumerWidget {
  const SavedSearchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searches = ref.watch(savedSearchesProvider).value ?? const [];
    final config = ref.watch(configProvider);
    final repo = ref.read(activityRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved searches')),
      body: searches.isEmpty
          ? const EmptyState(
              icon: Icons.bookmarks_outlined,
              title: 'No saved searches',
              message: 'After a search, tap the bookmark button on the map to get alerts for new matching places.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: searches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final s = searches[i];
                final q = s.query;
                final country = config.country(q.countryId);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            ),
                            IconButton(onPressed: () => repo.deleteSavedSearch(s.id), icon: const Icon(Icons.delete_outline_rounded), tooltip: 'Delete'),
                          ],
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final id in q.typeIds) TypePill(config.type(id), dense: true),
                            Pill(config.city(q.cityId).name, color: Colors.blueGrey, dense: true),
                            Pill(Geo.formatRadius(q.radiusKm, country.distanceUnit), color: Colors.blueGrey, dense: true),
                            if (q.filters.activeCount > 0) Pill('${q.filters.activeCount} filters', color: Colors.blueGrey, dense: true),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('Saved ${Fmt.relative(s.createdAt)}', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
                            const Spacer(),
                            const Text('Alerts', style: TextStyle(fontSize: 13)),
                            Switch(value: s.alertsEnabled, onChanged: (v) => repo.toggleSearchAlerts(s.id, v)),
                            TextButton(
                              onPressed: () {
                                ref.read(searchControllerProvider.notifier).applySaved(q);
                                context.go('/explore');
                              },
                              child: const Text('Run'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
