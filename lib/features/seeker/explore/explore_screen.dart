import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/property_facts.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/map_widgets.dart';
import '../../../core/widgets/property_card.dart';
import '../../../data/config/app_config.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import '../../shell/app_shell.dart';
import 'filter_sheet.dart';
import 'search_controller.dart';
import 'search_panel.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  static const _sheetMin = 0.2;
  final _map = MapController();
  final _sheet = DraggableScrollableController();
  final _listScroll = <String, GlobalKey>{};
  bool _mapReady = false;
  double _zoom = 13;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final s = ref.read(searchControllerProvider);
      if (s.userLocation == null && s.phase == SearchPhase.idle) {
        await ref.read(searchControllerProvider.notifier).locateUser();
      }
    });
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _fit(SearchQuery q, {bool leaveRoomForSheet = false}) {
    if (!_mapReady) return;
    final bottom = MediaQuery.sizeOf(context).height * (leaveRoomForSheet ? 0.28 : 0.52);
    _map.fitCamera(CameraFit.bounds(bounds: boundsForRadius(q.center, q.radiusKm), padding: EdgeInsets.fromLTRB(24, 110, 24, bottom)));
  }

  void _onStateChanged(SearchState? prev, SearchState next) {
    final active = next.active;
    if (next.phase == SearchPhase.results && active != null) {
      final changed = prev?.phase != SearchPhase.results || prev?.active?.radiusKm != active.radiusKm || prev?.active?.center != active.center;
      if (changed) _fit(active, leaveRoomForSheet: true);
      final sel = next.selected;
      if (sel != null && sel.id != prev?.selectedId && _mapReady) {
        _map.move(sel.point, _map.camera.zoom < 14 ? 14 : _map.camera.zoom);
      }
    } else if (next.phase == SearchPhase.idle) {
      if (prev?.draft.center != next.draft.center || prev?.draft.radiusKm != next.draft.radiusKm || prev?.phase != SearchPhase.idle) {
        _fit(next.draft);
      }
    }
  }

  void _selectFromList(Property p) {
    ref.read(searchControllerProvider.notifier).select(p.id);
    if (_sheet.isAttached) {
      _sheet.animateTo(_sheetMin, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _selectFromPin(Property p) {
    ref.read(searchControllerProvider.notifier).select(p.id);
    // Keep the map and list in sync: scroll the list card into view.
    final key = _listScroll[p.id];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 250), alignment: 0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(searchControllerProvider, _onStateChanged);
    final s = ref.watch(searchControllerProvider);
    final config = ref.watch(configProvider);
    final ctrl = ref.read(searchControllerProvider.notifier);
    final showResults = s.phase == SearchPhase.results && s.active != null;
    final circle = showResults ? s.active! : s.draft;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: circle.center,
                initialZoom: 13,
                minZoom: 4,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                onMapReady: () {
                  _mapReady = true;
                  _fit(circle, leaveRoomForSheet: showResults);
                },
                onPositionChanged: (camera, _) {
                  final z = (camera.zoom * 2).roundToDouble() / 2;
                  if (z != _zoom) setState(() => _zoom = z);
                },
                onTap: (_, point) {
                  if (showResults) {
                    ctrl.select(null);
                  } else {
                    ctrl.setCenter(point, 'Pinned location');
                  }
                },
              ),
              children: [
                appTileLayer(),
                CircleLayer(circles: [radiusCircle(circle.center, circle.radiusKm)]),
                MarkerLayer(
                  markers: [
                    if (s.userLocation != null) Marker(point: s.userLocation!, width: 22, height: 22, child: const UserDot()),
                    Marker(point: circle.center, width: 18, height: 18, child: const CenterMarker()),
                  ],
                ),
                if (showResults) MarkerLayer(markers: _pins(s, config)),
              ],
            ),
            const Positioned(left: 0, bottom: 0, child: SafeArea(child: MapAttribution())),

            // Top bar.
            Positioned(
              left: 12,
              right: 12,
              top: 0,
              child: SafeArea(child: showResults ? _ResultsTopBar(state: s) : const _IdleTopBar()),
            ),

            // Right-side map controls.
            Positioned(
              right: 12,
              top: MediaQuery.paddingOf(context).top + 72,
              child: Column(
                children: [
                  MapFab(
                    icon: Icons.my_location_rounded,
                    tooltip: 'My location',
                    onPressed: () async {
                      await ctrl.locateUser(moveCenter: !showResults);
                      final st = ref.read(searchControllerProvider);
                      if (st.locationDenied && context.mounted) {
                        showSnack(context, 'Location permission is off. Tap the map or search an address to set the centre.');
                      } else if (st.userLocation != null && _mapReady) {
                        _map.move(st.userLocation!, 15);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  MapFab(
                    icon: Icons.center_focus_strong_rounded,
                    tooltip: 'Show whole circle',
                    onPressed: () => _fit(circle, leaveRoomForSheet: showResults),
                  ),
                  if (showResults) ...[
                    const SizedBox(height: 10),
                    MapFab(icon: Icons.bookmark_add_outlined, tooltip: 'Save this search', onPressed: () => _saveSearch(context, s.active!)),
                  ],
                ],
              ),
            ),

            if (!showResults) const Align(alignment: Alignment.bottomCenter, child: SearchPanel()),

            if (showResults) ...[
              DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: _sheetMin,
                minChildSize: _sheetMin,
                maxChildSize: 0.92,
                snap: true,
                snapSizes: const [_sheetMin, 0.55],
                builder: (context, scroll) => _ResultsSheet(
                  state: s,
                  scroll: scroll,
                  keys: _listScroll,
                  onTapCard: _selectFromList,
                  onExpand: () => _sheet.animateTo(0.55, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                ),
              ),
              if (s.selected != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: box.maxHeight * _sheetMin + 10,
                  child: _PinPopup(property: s.selected!, origin: s.active!, onClose: () => ctrl.select(null)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  List<Marker> _pins(SearchState s, AppConfig config) {
    final clusters = clusterItems<Property>(s.results, (p) => p.point, _zoom);
    final markers = <Marker>[];
    Marker? selectedMarker;
    for (final c in clusters) {
      if (c.isSingle) {
        final p = c.items.first;
        final selected = p.id == s.selectedId;
        final m = Marker(
          key: ValueKey(p.id),
          point: p.point,
          width: PropertyPin.size.width,
          height: PropertyPin.size.height,
          alignment: Alignment.topCenter,
          child: PropertyPin(type: config.type(p.typeId), property: p, selected: selected, onTap: () => _selectFromPin(p)),
        );
        selected ? selectedMarker = m : markers.add(m);
      } else {
        final containsSelected = c.items.any((p) => p.id == s.selectedId);
        final m = Marker(
          point: c.center,
          width: 60,
          height: 60,
          child: ClusterBubble(count: c.items.length, onTap: () => _map.move(c.center, (_map.camera.zoom + 2).clamp(0, 18))),
        );
        containsSelected ? selectedMarker = m : markers.add(m);
      }
    }
    return [...markers, ?selectedMarker];
  }

  Future<void> _saveSearch(BuildContext context, SearchQuery q) async {
    final config = ref.read(configProvider);
    final types = q.typeIds.map((id) => config.type(id).name).join(', ');
    final country = config.country(q.countryId);
    final controller = TextEditingController(text: '$types · ${Geo.formatRadius(q.radiusKm, country.distanceUnit)} · ${q.centerLabel}');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save this search'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            const Text('We will notify you when a new matching place is listed.', style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final uid = ref.read(userProvider)?.id;
    if (uid == null) return;
    await ref.read(activityRepositoryProvider).saveSearch(uid, name, q);
    if (context.mounted) showSnack(context, 'Search saved. Alerts are on.');
  }
}

class _IdleTopBar extends ConsumerWidget {
  const _IdleTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final first = (user?.name ?? '').split(' ').first;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(16),
              color: scheme.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    UserAvatar(user, radius: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(first.isEmpty ? 'Hello!' : 'Hi $first 👋', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          Text('Tap the map to move the search centre', style: TextStyle(fontSize: 12, color: scheme.outline)),
                        ],
                      ),
                    ),
                    IconButton(tooltip: 'Saved searches', onPressed: () => context.push('/saved-searches'), icon: const Icon(Icons.bookmarks_outlined)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const NotificationBell(onMap: true),
        ],
      ),
    );
  }
}

class _ResultsTopBar extends ConsumerWidget {
  const _ResultsTopBar({required this.state});
  final SearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final q = state.active!;
    final ctrl = ref.read(searchControllerProvider.notifier);
    final country = config.country(q.countryId);
    final types = q.typeIds.map(config.type).toList();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          MapFab(icon: Icons.arrow_back_rounded, tooltip: 'Edit search', onPressed: ctrl.reset),
          const SizedBox(width: 8),
          Expanded(
            child: Material(
              elevation: 3,
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: ctrl.reset,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(
                    children: [
                      Icon(types.length == 1 ? types.first.icon : Icons.category_rounded, color: types.length == 1 ? types.first.color : scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              types.length == 1 ? types.first.name : '${types.length} property types',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${Geo.formatRadius(q.radiusKm, country.distanceUnit)} around ${q.centerLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: scheme.outline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: scheme.surface,
            shape: const CircleBorder(),
            elevation: 3,
            child: IconButton(
              tooltip: 'Filters',
              onPressed: () => showFilterSheet(context, ref),
              icon: Badge(isLabelVisible: q.filters.activeCount > 0, label: Text('${q.filters.activeCount}'), child: const Icon(Icons.tune_rounded)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsSheet extends ConsumerWidget {
  const _ResultsSheet({required this.state, required this.scroll, required this.keys, required this.onTapCard, required this.onExpand});
  final SearchState state;
  final ScrollController scroll;
  final Map<String, GlobalKey> keys;
  final ValueChanged<Property> onTapCard;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final q = state.active!;
    final city = config.city(q.cityId);
    final country = config.country(q.countryId);
    final ctrl = ref.read(searchControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final list = state.sorted;
    final usesUnits = q.typeIds.map(config.type).any((t) => t.usesUnits);

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: CustomScrollView(
        controller: scroll,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${list.length} ',
                                style: TextStyle(color: scheme.primary),
                              ),
                              TextSpan(text: list.length == 1 ? 'place' : 'places'),
                              TextSpan(
                                text: ' within ${Geo.formatRadius(q.radiusKm, country.distanceUnit)}',
                                style: TextStyle(color: scheme.outline, fontWeight: FontWeight.w500, fontSize: 14),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (list.isNotEmpty) TextButton(onPressed: onExpand, child: Text('View all (${list.length})')),
                    ],
                  ),
                ),
                RadiusSlider(radiusKm: q.radiusKm, city: city, unit: country.distanceUnit, onChanged: ctrl.setRadius, compact: true),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final opt in SortOption.values)
                        if (opt != SortOption.seatsAvailable || usesUnits)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(opt.label),
                              selected: state.sort == opt,
                              onSelected: (_) => ctrl.setSort(opt),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          if (list.isEmpty)
            SliverToBoxAdapter(
              child: _NoResults(query: q, city: city),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              sliver: SliverList.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = list[i];
                  final key = keys.putIfAbsent(p.id, GlobalKey.new);
                  return PropertyCard(key: key, property: p, origin: q.center, highlighted: p.id == state.selectedId, onTap: () => onTapCard(p));
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _NoResults extends ConsumerWidget {
  const _NoResults({required this.query, required this.city});
  final SearchQuery query;
  final City city;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(searchControllerProvider.notifier);
    final canGrow = query.radiusKm < city.maxRadiusKm;
    final bigger = (query.radiusKm * 2).clamp(city.minRadiusKm, city.maxRadiusKm);
    final country = ref.watch(configProvider).country(query.countryId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 44),
          const SizedBox(height: 8),
          const Text('No places found', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Try a bigger radius, a different type, or save this search to get alerts.', textAlign: TextAlign.center),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (canGrow)
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                  onPressed: () => ctrl.setRadius(bigger),
                  icon: const Icon(Icons.zoom_out_map_rounded),
                  label: Text('Increase to ${Geo.formatRadius(bigger, country.distanceUnit)}'),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: ctrl.reset,
                icon: const Icon(Icons.category_outlined),
                label: const Text('Change type'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Popup card shown when a pin is tapped (spec 5.4).
class _PinPopup extends ConsumerWidget {
  const _PinPopup({required this.property, required this.origin, required this.onClose});
  final Property property;
  final SearchQuery origin;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final type = config.type(property.typeId);
    final country = config.country(property.countryId);
    final km = Geo.distanceKm(origin.center, property.point);
    final facts = PropertyFacts.keyFacts(property, type);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(18),
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/property/${property.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 96,
                  height: 104,
                  child: AppImage(property.mainPhoto, fallbackIcon: type.icon, color: type.color),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: TypePill(type, dense: true)),
                        if (property.isVerified) ...[const SizedBox(width: 4), const VerifiedPill(dense: true)],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text(
                      '${Fmt.price(property, country)}${property.negotiable ? ' · Negotiable' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Geo.formatDistance(km, country.distanceUnit)} away · ~${Geo.formatEta(Geo.estimateEta(km))}',
                      style: TextStyle(fontSize: 12.5, color: scheme.outline),
                    ),
                    if (facts.isNotEmpty) Text(facts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                    const SizedBox(height: 2),
                    RatingLabel(property.averageRating, count: property.reviewCount == 0 ? null : property.reviewCount, size: 12),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(visualDensity: VisualDensity.compact, onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 20)),
                  FavouriteButton(propertyId: property.id),
                  SizedBox(
                    height: 32,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () => context.push('/property/${property.id}'),
                      child: const Text('Detail'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
