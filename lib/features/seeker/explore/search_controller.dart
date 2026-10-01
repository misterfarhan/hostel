import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import '../../../data/search_matcher.dart';

/// Seeker app states from spec 5.8 that belong to the explore screen.
enum SearchPhase { idle, searching, results }

class SearchState {
  const SearchState({
    required this.draft,
    this.phase = SearchPhase.idle,
    this.active,
    this.results = const [],
    this.selectedId,
    this.sort = SortOption.nearest,
    this.userLocation,
    this.locationDenied = false,
    this.error,
  });

  /// The form being edited (type, country, city, radius, centre, filters).
  final SearchQuery draft;
  final SearchPhase phase;

  /// The query whose results are on the map.
  final SearchQuery? active;
  final List<Property> results;
  final String? selectedId;
  final SortOption sort;
  final LatLng? userLocation;
  final bool locationDenied;
  final String? error;

  List<Property> get sorted => active == null ? results : SearchMatcher.sort(results, sort, active!);
  Property? get selected => selectedId == null ? null : results.where((p) => p.id == selectedId).firstOrNull;

  SearchState copyWith({
    SearchQuery? draft,
    SearchPhase? phase,
    SearchQuery? active,
    List<Property>? results,
    String? selectedId,
    bool clearSelected = false,
    SortOption? sort,
    LatLng? userLocation,
    bool? locationDenied,
    String? error,
    bool clearError = false,
  }) => SearchState(
    draft: draft ?? this.draft,
    phase: phase ?? this.phase,
    active: active ?? this.active,
    results: results ?? this.results,
    selectedId: clearSelected ? null : (selectedId ?? this.selectedId),
    sort: sort ?? this.sort,
    userLocation: userLocation ?? this.userLocation,
    locationDenied: locationDenied ?? this.locationDenied,
    error: clearError ? null : (error ?? this.error),
  );
}

class PropertySearchController extends Notifier<SearchState> {
  @override
  SearchState build() {
    final config = ref.read(configProvider);
    final user = ref.read(userProvider);
    final city = config.cities.where((c) => c.id == user?.cityId).firstOrNull ?? config.cities.first;

    // Real-time: when any listing changes (new listing live, hostel full...),
    // re-apply the active query so pins appear/disappear without refresh.
    ref.listen(livePropertiesProvider, (_, next) {
      final live = next.value;
      final q = state.active;
      if (live == null || q == null || state.phase != SearchPhase.results) return;
      final showFull = config.showFullListingsWithBadge;
      final results = live.where((p) => SearchMatcher.matches(p, q, showFull: showFull)).toList();
      final keepSelected = results.any((p) => p.id == state.selectedId);
      state = state.copyWith(results: results, clearSelected: !keepSelected);
    });

    return SearchState(
      draft: SearchQuery(
        typeIds: {config.propertyTypes.first.id},
        countryId: city.countryId,
        cityId: city.id,
        center: city.center,
        radiusKm: city.defaultRadiusKm,
        centerLabel: '${city.name} centre',
      ),
    );
  }

  /// Uses GPS as the search centre when allowed (spec 5.1).
  Future<void> locateUser({bool moveCenter = true}) async {
    final pos = await ref.read(locationServiceProvider).current();
    if (pos == null) {
      state = state.copyWith(locationDenied: true);
      return;
    }
    state = state.copyWith(userLocation: pos, locationDenied: false);
    if (moveCenter) {
      state = state.copyWith(
        draft: state.draft.copyWith(center: pos, centerLabel: 'Current location'),
      );
    }
  }

  void updateDraft(SearchQuery Function(SearchQuery) change) => state = state.copyWith(draft: change(state.draft));

  void selectCity(City city) {
    final usingGps = state.draft.centerLabel == 'Current location' && state.userLocation != null;
    state = state.copyWith(
      draft: state.draft.copyWith(
        countryId: city.countryId,
        cityId: city.id,
        radiusKm: city.defaultRadiusKm.clamp(city.minRadiusKm, city.maxRadiusKm),
        center: usingGps ? null : city.center,
        centerLabel: usingGps ? null : '${city.name} centre',
      ),
    );
  }

  void setCenter(LatLng point, String label) {
    state = state.copyWith(
      draft: state.draft.copyWith(center: point, centerLabel: label),
    );
    if (state.phase == SearchPhase.results) search();
  }

  Future<void> search() async {
    final q = state.draft;
    state = state.copyWith(phase: SearchPhase.searching, clearError: true, clearSelected: true);
    try {
      final results = await ref.read(propertyRepositoryProvider).search(q);
      state = state.copyWith(phase: SearchPhase.results, active: q, results: results);
    } catch (e) {
      state = state.copyWith(phase: SearchPhase.idle, error: 'Could not load places. Check your connection and try again.');
    }
  }

  /// Radius slider on the results screen: redraw and refresh instantly.
  void setRadius(double km) {
    state = state.copyWith(draft: state.draft.copyWith(radiusKm: km));
    final active = state.active;
    if (state.phase != SearchPhase.results || active == null) return;
    final q = active.copyWith(radiusKm: km);
    final live = ref.read(livePropertiesProvider).value ?? const [];
    final showFull = ref.read(configProvider).showFullListingsWithBadge;
    state = state.copyWith(
      active: q,
      results: live.where((p) => SearchMatcher.matches(p, q, showFull: showFull)).toList(),
    );
  }

  void setFilters(SearchFilters filters) {
    state = state.copyWith(draft: state.draft.copyWith(filters: filters));
    if (state.phase == SearchPhase.results) search();
  }

  void setTypes(Set<String> typeIds) {
    state = state.copyWith(draft: state.draft.copyWith(typeIds: typeIds));
    if (state.phase == SearchPhase.results) search();
  }

  void select(String? id) => state = id == null ? state.copyWith(clearSelected: true) : state.copyWith(selectedId: id);

  void setSort(SortOption sort) => state = state.copyWith(sort: sort);

  void applySaved(SearchQuery q) {
    state = state.copyWith(draft: q);
    search();
  }

  void reset() => state = SearchState(draft: state.draft, userLocation: state.userLocation, sort: state.sort);
}

final searchControllerProvider = NotifierProvider<PropertySearchController, SearchState>(PropertySearchController.new);
