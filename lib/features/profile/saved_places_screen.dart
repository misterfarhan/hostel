import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/widgets/common.dart';
import '../../core/widgets/map_widgets.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

/// Home, Work, University, Office, Other (spec 11). Saved places appear as
/// quick search centres on the explore screen.
class SavedPlacesScreen extends ConsumerWidget {
  const SavedPlacesScreen({super.key});

  static IconData iconFor(SavedPlaceKind k) => switch (k) {
    SavedPlaceKind.home => Icons.home_outlined,
    SavedPlaceKind.work => Icons.work_outline,
    SavedPlaceKind.university => Icons.school_outlined,
    SavedPlaceKind.office => Icons.business_outlined,
    SavedPlaceKind.other => Icons.place_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final places = user?.savedPlaces ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Saved places')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _AddPlaceScreen())),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add place'),
      ),
      body: places.isEmpty
          ? const EmptyState(icon: Icons.place_outlined, title: 'No saved places', message: 'Save your university, office or home to search around it quickly.')
          : ListView(
              children: [
                for (final p in places)
                  ListTile(
                    leading: Icon(iconFor(p.kind)),
                    title: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(p.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref.read(authRepositoryProvider).updateProfile(user!.copyWith(savedPlaces: places.where((x) => x.id != p.id).toList())),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _AddPlaceScreen extends ConsumerStatefulWidget {
  const _AddPlaceScreen();
  @override
  ConsumerState<_AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends ConsumerState<_AddPlaceScreen> {
  SavedPlaceKind _kind = SavedPlaceKind.university;
  final _label = TextEditingController();
  late LatLng _point = () {
    final u = ref.read(userProvider);
    final config = ref.read(configProvider);
    return u?.cityId == null ? config.cities.first.center : config.city(u!.cityId!).center;
  }();
  String _address = 'Tap the map to choose';

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pick(LatLng p) async {
    setState(() {
      _point = p;
      _address = 'Looking up address…';
    });
    final a = await ref.read(geocodingServiceProvider).reverse(p);
    if (mounted) setState(() => _address = a ?? '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a place')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(initialCenter: _point, initialZoom: 13, onTap: (_, p) => _pick(p)),
              children: [
                appTileLayer(),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _point,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_on, size: 40, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_address, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final k in SavedPlaceKind.values)
                        ChoiceChip(
                          avatar: Icon(SavedPlacesScreen.iconFor(k), size: 18),
                          label: Text(k.name[0].toUpperCase() + k.name.substring(1)),
                          selected: _kind == k,
                          onSelected: (_) => setState(() => _kind = k),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _label,
                    decoration: const InputDecoration(labelText: 'Label', hintText: 'e.g. Punjab University'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final user = ref.read(userProvider)!;
                        final label = _label.text.trim().isEmpty ? _kind.name : _label.text.trim();
                        await ref
                            .read(authRepositoryProvider)
                            .updateProfile(
                              user.copyWith(
                                savedPlaces: [
                                  ...user.savedPlaces,
                                  SavedPlace(id: 'sp_${DateTime.now().millisecondsSinceEpoch}', kind: _kind, label: label, address: _address, point: _point),
                                ],
                              ),
                            );
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Save place'),
                    ),
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
