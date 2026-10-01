import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import 'filter_sheet.dart';
import 'search_controller.dart';

/// The search form from spec 5.2: type, country, city, radius, centre,
/// optional filters and the Find Places button.
class SearchPanel extends ConsumerWidget {
  const SearchPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final state = ref.watch(searchControllerProvider);
    final ctrl = ref.read(searchControllerProvider.notifier);
    final q = state.draft;
    final city = config.city(q.cityId);
    final country = config.country(q.countryId);
    final theme = Theme.of(context);
    final searching = state.phase == SearchPhase.searching;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Text('What do you need?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: config.propertyTypes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final t = config.propertyTypes[i];
                    final selected = q.typeIds.contains(t.id);
                    return FilterChip(
                      showCheckmark: false,
                      selected: selected,
                      avatar: Icon(t.icon, size: 18, color: selected ? Colors.white : t.color),
                      label: Text(t.name),
                      labelStyle: TextStyle(color: selected ? Colors.white : null, fontWeight: FontWeight.w600),
                      selectedColor: t.color,
                      onSelected: (_) => ctrl.updateDraft((d) => d.copyWith(typeIds: {t.id})),
                    );
                  },
                ),
              ),
              if (q.typeIds.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text('${q.typeIds.length} types selected', style: TextStyle(color: theme.colorScheme.primary, fontSize: 12)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  onPressed: () => _pickTypes(context, ref),
                  icon: const Icon(Icons.checklist_rounded, size: 18),
                  label: const Text('Select multiple types'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _FieldButton(
                        icon: Icons.public,
                        label: 'Country',
                        value: '${country.flag} ${country.name}',
                        onTap: () => _pickCountry(context, ref),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FieldButton(
                        icon: Icons.location_city_rounded,
                        label: 'City',
                        value: city.name,
                        onTap: () => _pickCity(context, ref, q.countryId),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FieldButton(
                  icon: Icons.my_location_rounded,
                  label: 'Search centre',
                  value: q.centerLabel,
                  trailing: const Icon(Icons.edit_location_alt_outlined, size: 20),
                  onTap: () => showCentrePicker(context, ref),
                ),
              ),
              RadiusSlider(
                radiusKm: q.radiusKm,
                city: city,
                unit: country.distanceUnit,
                onChanged: (v) => ctrl.updateDraft((d) => d.copyWith(radiusKm: v)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                      onPressed: () => showFilterSheet(context, ref),
                      icon: Badge(isLabelVisible: q.filters.activeCount > 0, label: Text('${q.filters.activeCount}'), child: const Icon(Icons.tune_rounded)),
                      label: const Text('Filters'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: searching ? null : ctrl.search,
                        icon: searching
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Icon(Icons.search_rounded),
                        label: Text(searching ? 'Searching…' : 'Find Places'),
                      ),
                    ),
                  ],
                ),
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(state.error!, style: TextStyle(color: theme.colorScheme.error)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTypes(BuildContext context, WidgetRef ref) async {
    final config = ref.read(configProvider);
    final current = {...ref.read(searchControllerProvider).draft.typeIds};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Property types', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              for (final t in config.propertyTypes)
                CheckboxListTile(
                  secondary: Icon(t.icon, color: t.color),
                  title: Text(t.name),
                  value: current.contains(t.id),
                  onChanged: (v) => setState(() => v! ? current.add(t.id) : current.remove(t.id)),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(onPressed: current.isEmpty ? null : () => Navigator.pop(ctx, current), child: Text('Apply (${current.length})')),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) ref.read(searchControllerProvider.notifier).updateDraft((d) => d.copyWith(typeIds: result));
  }

  Future<void> _pickCountry(BuildContext context, WidgetRef ref) async {
    final config = ref.read(configProvider);
    final picked = await showModalBottomSheet<Country>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in config.countries)
              ListTile(
                leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                title: Text(c.name),
                subtitle: Text('${c.currencyCode} · ${c.distanceUnit == DistanceUnit.km ? 'km' : 'miles'}'),
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      ref.read(searchControllerProvider.notifier).selectCity(config.citiesOf(picked.id).first);
    }
  }

  Future<void> _pickCity(BuildContext context, WidgetRef ref, String countryId) async {
    final config = ref.read(configProvider);
    final picked = await showModalBottomSheet<City>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CityPicker(cities: config.citiesOf(countryId)),
    );
    if (picked != null) ref.read(searchControllerProvider.notifier).selectCity(picked);
  }
}

class _CityPicker extends StatefulWidget {
  const _CityPicker({required this.cities});
  final List<City> cities;
  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final list = widget.cities.where((c) => c.name.toLowerCase().contains(_q.toLowerCase())).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search city', prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in list) ListTile(leading: const Icon(Icons.location_city_rounded), title: Text(c.name), onTap: () => Navigator.pop(context, c)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({required this.icon, required this.label, required this.value, required this.onTap, this.trailing});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11.5, color: scheme.outline)),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            trailing ?? const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }
}

/// Slider + number, bounded by the city's admin-configured min/max (spec 5.2).
class RadiusSlider extends StatelessWidget {
  const RadiusSlider({super.key, required this.radiusKm, required this.city, required this.unit, required this.onChanged, this.compact = false});
  final double radiusKm;
  final City city;
  final DistanceUnit unit;
  final ValueChanged<double> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final min = city.minRadiusKm;
    final max = city.maxRadiusKm;
    final value = radiusKm.clamp(min, max);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 0 : 12, 8, compact ? 0 : 4),
      child: Row(
        children: [
          if (!compact) ...[const Text('Radius', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(width: 4)],
          Expanded(
            child: Slider(value: value, min: min, max: max, divisions: ((max - min) * 2).round(), label: Geo.formatRadius(value, unit), onChanged: onChanged),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final controller = TextEditingController(text: (unit == DistanceUnit.miles ? value / Geo.kmPerMile : value).toStringAsFixed(1));
              final result = await showDialog<double>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Radius'),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      suffixText: unit == DistanceUnit.miles ? 'mi' : 'km',
                      helperText: 'Between ${Geo.formatRadius(min, unit)} and ${Geo.formatRadius(max, unit)}',
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        final v = double.tryParse(controller.text);
                        Navigator.pop(ctx, v == null ? null : (unit == DistanceUnit.miles ? v * Geo.kmPerMile : v));
                      },
                      child: const Text('Set'),
                    ),
                  ],
                ),
              );
              if (result != null) onChanged(result.clamp(min, max));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
              child: Text(
                Geo.formatRadius(value, unit),
                style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Choose the search centre: GPS, saved place, or address search.
Future<void> showCentrePicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _CentrePicker());
}

class _CentrePicker extends ConsumerStatefulWidget {
  const _CentrePicker();
  @override
  ConsumerState<_CentrePicker> createState() => _CentrePickerState();
}

class _CentrePickerState extends ConsumerState<_CentrePicker> {
  Timer? _debounce;
  List<PlaceResult> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final draft = ref.read(searchControllerProvider).draft;
      setState(() => _loading = true);
      final results = await ref.read(geocodingServiceProvider).search(text, near: draft.center, countryCode: draft.countryId);
      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    });
  }

  void _choose(PlaceResult r) {
    ref.read(searchControllerProvider.notifier).setCenter(r.point, r.name);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final city = ref.watch(configProvider).city(ref.watch(searchControllerProvider).draft.cityId);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search an address, area or university',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                  ),
                  onChanged: _onChanged,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.my_location_rounded),
                      title: const Text('Use my current location'),
                      onTap: () async {
                        final nav = Navigator.of(context);
                        await ref.read(searchControllerProvider.notifier).locateUser();
                        final s = ref.read(searchControllerProvider);
                        if (s.locationDenied && context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Location is off. Pick a spot on the map or search an address.')));
                          return;
                        }
                        if (s.phase == SearchPhase.results) ref.read(searchControllerProvider.notifier).search();
                        nav.pop();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.location_city_rounded),
                      title: Text('${city.name} centre'),
                      onTap: () => _choose(PlaceResult(name: '${city.name} centre', address: city.name, point: city.center)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.touch_app_outlined),
                      title: const Text('Pick on the map'),
                      subtitle: const Text('Close this and tap anywhere on the map'),
                      onTap: () => Navigator.pop(context),
                    ),
                    for (final p in user?.savedPlaces ?? const <SavedPlace>[])
                      ListTile(
                        leading: const Icon(Icons.bookmark_rounded),
                        title: Text(p.label),
                        subtitle: Text(p.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _choose(PlaceResult(name: p.label, address: p.address, point: p.point)),
                      ),
                    if (_results.isNotEmpty) const Divider(),
                    for (final r in _results)
                      ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(r.name),
                        subtitle: Text(r.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => _choose(r),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
