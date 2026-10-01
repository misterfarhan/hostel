import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import 'search_controller.dart';

Future<void> showFilterSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const _FilterSheet());
}

const _facilityOptions = ['Wi-Fi', 'AC', 'Parking', 'Generator / UPS backup', 'CCTV', 'Security guard', 'Lift', 'Laundry', 'Meals'];

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();
  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late SearchFilters _f = ref.read(searchControllerProvider).draft.filters;
  late final _min = TextEditingController(text: _f.minBudget?.round().toString() ?? '');
  late final _max = TextEditingController(text: _f.maxBudget?.round().toString() ?? '');

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  SearchFilters _copy({
    Object? purpose = _keep,
    Object? minSeats = _keep,
    Object? furnished = _keep,
    Object? kitchen = _keep,
    Object? gender = _keep,
    Object? availableBy = _keep,
    bool? verifiedOnly,
    Set<String>? facilities,
  }) => SearchFilters(
    minBudget: double.tryParse(_min.text),
    maxBudget: double.tryParse(_max.text),
    purpose: purpose == _keep ? _f.purpose : purpose as ListingPurpose?,
    minSeats: minSeats == _keep ? _f.minSeats : minSeats as int?,
    furnished: furnished == _keep ? _f.furnished : furnished as String?,
    kitchen: kitchen == _keep ? _f.kitchen : kitchen as String?,
    genderRule: gender == _keep ? _f.genderRule : gender as GenderRule?,
    availableBy: availableBy == _keep ? _f.availableBy : availableBy as DateTime?,
    verifiedOnly: verifiedOnly ?? _f.verifiedOnly,
    facilities: facilities ?? _f.facilities,
  );

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(searchControllerProvider).draft;
    final config = ref.watch(configProvider);
    final country = config.country(draft.countryId);
    final types = draft.typeIds.map(config.type).toList();
    final isHostel = types.any((t) => t.usesUnits);
    final hasFurnishing = types.any((t) => t.field('furnishing') != null);
    final purposes = {for (final t in types) ...t.purposes}.toList();

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );

    Widget choices<T>(List<T> options, T? selected, String Function(T) label, void Function(T?) onChanged) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options) ChoiceChip(label: Text(label(o)), selected: selected == o, onSelected: (on) => setState(() => onChanged(on ? o : null))),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _f = const SearchFilters();
                      _min.clear();
                      _max.clear();
                    }),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                children: [
                  section(
                    'Budget (${country.currencyCode})',
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _min,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'Min'),
                          ),
                        ),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('–')),
                        Expanded(
                          child: TextField(
                            controller: _max,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'Max'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (purposes.length > 1)
                    section('Rent or sale', choices<ListingPurpose>(purposes, _f.purpose, (p) => p.label, (v) => _f = _copy(purpose: v))),
                  if (isHostel)
                    section('Seats available (at least)', choices<int>(const [1, 2, 3, 4], _f.minSeats, (n) => '$n+', (v) => _f = _copy(minSeats: v))),
                  if (isHostel)
                    section('Kitchen', choices<String>(const ['Attached to room', 'Common kitchen'], _f.kitchen, (s) => s, (v) => _f = _copy(kitchen: v))),
                  if (hasFurnishing)
                    section(
                      'Furnishing',
                      choices<String>(const ['Furnished', 'Semi-furnished', 'Unfurnished'], _f.furnished, (s) => s, (v) => _f = _copy(furnished: v)),
                    ),
                  section(
                    'Who can stay',
                    choices<GenderRule>(
                      GenderRule.values.where((g) => g != GenderRule.any).toList(),
                      _f.genderRule,
                      (g) => g.label,
                      (v) => _f = _copy(gender: v),
                    ),
                  ),
                  section(
                    'Available from',
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: context,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                          initialDate: _f.availableBy ?? now,
                        );
                        setState(() => _f = _copy(availableBy: d));
                      },
                      icon: const Icon(Icons.event_rounded),
                      label: Text(_f.availableBy == null ? 'Any date' : 'By ${Fmt.date(_f.availableBy!)}'),
                    ),
                  ),
                  section(
                    'Facilities',
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in _facilityOptions)
                          FilterChip(
                            label: Text(f),
                            selected: _f.facilities.contains(f),
                            onSelected: (on) => setState(() {
                              final set = {..._f.facilities};
                              on ? set.add(f) : set.remove(f);
                              _f = _copy(facilities: set);
                            }),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                    child: SwitchListTile(
                      title: const Text('Verified listings only', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Documents checked by the StayFinder team'),
                      value: _f.verifiedOnly,
                      onChanged: (v) => setState(() => _f = _copy(verifiedOnly: v)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () {
                    ref.read(searchControllerProvider.notifier).setFilters(_copy());
                    Navigator.pop(context);
                  },
                  child: const Text('Apply filters'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _keep = Object();
