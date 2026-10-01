import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/property_facts.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import '../explore/search_controller.dart';

/// Side-by-side comparison of up to 3 properties (spec 11).
class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key, required this.ids});
  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final props = ids.map((id) => ref.watch(propertyProvider(id)).value).whereType<Property>().toList();
    final origin = ref.watch(searchControllerProvider).userLocation;
    final scheme = Theme.of(context).colorScheme;
    if (props.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Compare')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final allFacilities = <String>{
      for (final p in props) ...p.included,
      for (final p in props)
        for (final v in p.details.values)
          if (v is List) ...v.map((e) => e.toString()),
    }.toList()..sort();

    bool has(Property p, String f) => p.included.contains(f) || p.details.values.any((v) => v is List && v.map((e) => e.toString()).contains(f));

    final rows = <(String, List<Widget>)>[
      (
        'Price',
        [
          for (final p in props)
            Text(
              Fmt.price(p, config.country(p.countryId), compact: true),
              style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary),
            ),
        ],
      ),
      ('Type', [for (final p in props) Text(config.type(p.typeId).name)]),
      ('Area', [for (final p in props) Text(p.area)]),
      if (origin != null)
        ('Distance', [for (final p in props) Text(Geo.formatDistance(Geo.distanceKm(origin, p.point), config.country(p.countryId).distanceUnit))]),
      ('Key facts', [for (final p in props) Text(PropertyFacts.keyFacts(p, config.type(p.typeId)).join('\n'))]),
      ('Deposit', [for (final p in props) Text(p.deposit == 0 ? '—' : Fmt.money(p.deposit, config.country(p.countryId), compact: true))]),
      ('Rating', [for (final p in props) RatingLabel(p.averageRating, count: p.reviewCount == 0 ? null : p.reviewCount)]),
      (
        'Verified',
        [for (final p in props) Icon(p.isVerified ? Icons.verified_rounded : Icons.remove, color: p.isVerified ? AppColors.verified : scheme.outline)],
      ),
      for (final f in allFacilities)
        (
          f,
          [
            for (final p in props)
              Icon(has(p, f) ? Icons.check_circle_rounded : Icons.close_rounded, size: 20, color: has(p, f) ? AppColors.success : scheme.outlineVariant),
          ],
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Compare')),
      body: SingleChildScrollView(
        child: Table(
          columnWidths: {0: const FixedColumnWidth(110), for (var i = 1; i <= props.length; i++) i: const FlexColumnWidth()},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder(horizontalInside: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
          children: [
            TableRow(
              children: [
                const SizedBox(),
                for (final p in props)
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: InkWell(
                      onTap: () => context.push('/property/${p.id}'),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AspectRatio(aspectRatio: 1.2, child: AppImage(p.mainPhoto)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p.title,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            for (final (label, cells) in rows)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(label, style: TextStyle(color: scheme.outline, fontSize: 13)),
                  ),
                  for (final c in cells)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Center(
                        child: DefaultTextStyle.merge(textAlign: TextAlign.center, style: const TextStyle(fontSize: 13), child: c),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
