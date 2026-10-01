import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common.dart';
import '../../../core/widgets/property_card.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import '../../shell/app_shell.dart';
import '../explore/search_controller.dart';

class FavouritesScreen extends ConsumerStatefulWidget {
  const FavouritesScreen({super.key});
  @override
  ConsumerState<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends ConsumerState<FavouritesScreen> {
  final _compare = <String>{};
  bool _selecting = false;

  @override
  Widget build(BuildContext context) {
    final favIds = ref.watch(favouritesProvider).value ?? const {};
    // Use all properties the user can see (live), plus a placeholder for
    // favourites that are no longer live.
    final live = {for (final p in ref.watch(livePropertiesProvider).value ?? const <Property>[]) p.id: p};
    final favs = favIds.map((id) => live[id]).whereType<Property>().toList();
    final unavailable = favIds.length - favs.length;
    final origin = ref.watch(searchControllerProvider).userLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved places'),
        actions: [
          if (favs.length >= 2)
            TextButton.icon(
              onPressed: () => setState(() {
                _selecting = !_selecting;
                _compare.clear();
              }),
              icon: Icon(_selecting ? Icons.close : Icons.compare_arrows_rounded),
              label: Text(_selecting ? 'Cancel' : 'Compare'),
            ),
          const NotificationBell(),
        ],
      ),
      body: favs.isEmpty
          ? EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'No saved places yet',
              message: 'Tap the heart on any listing to keep it here and get price-drop alerts.',
              action: FilledButton(onPressed: () => context.go('/explore'), child: const Text('Explore the map')),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              children: [
                if (_selecting)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Select up to 3 places to compare side by side',
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                for (final p in favs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PropertyCard(
                      property: p,
                      origin: origin,
                      highlighted: _compare.contains(p.id),
                      onTap: _selecting ? () => _toggle(p.id) : null,
                      trailing: _selecting ? Checkbox(value: _compare.contains(p.id), onChanged: (_) => _toggle(p.id)) : null,
                      showDetailButton: !_selecting,
                    ),
                  ),
                if (unavailable > 0)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '$unavailable saved ${unavailable == 1 ? 'place is' : 'places are'} no longer available (rented, sold, full or paused). '
                      'We will notify you if ${unavailable == 1 ? 'it comes' : 'they come'} back.',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12.5),
                    ),
                  ),
              ],
            ),
      floatingActionButton: _selecting && _compare.length >= 2
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/compare?ids=${_compare.join(',')}'),
              icon: const Icon(Icons.compare_arrows_rounded),
              label: Text('Compare ${_compare.length}'),
            )
          : null,
    );
  }

  void _toggle(String id) {
    setState(() {
      if (_compare.contains(id)) {
        _compare.remove(id);
      } else if (_compare.length < 3) {
        _compare.add(id);
      } else {
        showSnack(context, 'You can compare up to 3 places');
      }
    });
  }
}
