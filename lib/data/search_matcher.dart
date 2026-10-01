import '../core/utils/geo.dart';
import 'models/models.dart';

/// The radius + filter rules from spec section 6. The backend applies the
/// same rules in SQL (PostGIS `ST_DWithin`); the app re-applies them locally
/// to real-time updates so pins appear/disappear without a refresh.
abstract final class SearchMatcher {
  static bool isVisible(Property p, {required bool showFull}) => p.status == ListingStatus.live || (showFull && p.status == ListingStatus.full);

  static bool matches(Property p, SearchQuery q, {bool showFull = false}) {
    if (!isVisible(p, showFull: showFull)) return false;
    if (q.typeIds.isNotEmpty && !q.typeIds.contains(p.typeId)) return false;
    if (!Geo.withinRadius(q.center, p.point, q.radiusKm)) return false;
    final f = q.filters;
    if (f.minBudget != null && p.price < f.minBudget!) return false;
    if (f.maxBudget != null && p.price > f.maxBudget!) return false;
    if (f.purpose != null && p.purpose != f.purpose) return false;
    if (f.minSeats != null && p.availableUnits < f.minSeats!) return false;
    if (f.furnished != null && p.details['furnishing'] != f.furnished) return false;
    if (f.kitchen != null && p.details['kitchen'] != f.kitchen) return false;
    if (f.genderRule != null && p.genderRule != f.genderRule && p.genderRule != GenderRule.any) return false;
    if (f.availableBy != null && p.availableFrom != null && p.availableFrom!.isAfter(f.availableBy!)) return false;
    if (f.verifiedOnly && !p.isVerified) return false;
    if (f.facilities.isNotEmpty) {
      final all = <String>{
        ...p.included,
        for (final v in p.details.values)
          if (v is List) ...v.map((e) => e.toString()),
      };
      if (!f.facilities.every(all.contains)) return false;
    }
    return true;
  }

  static List<Property> sort(List<Property> list, SortOption sort, SearchQuery q) {
    final out = [...list];
    int featuredFirst(Property a, Property b) => (b.isFeatured ? 1 : 0) - (a.isFeatured ? 1 : 0);
    double dist(Property p) => Geo.distanceMeters(q.center, p.point);
    out.sort((a, b) {
      final c = switch (sort) {
        SortOption.nearest => dist(a).compareTo(dist(b)),
        SortOption.lowestPrice => a.price.compareTo(b.price),
        SortOption.highestPrice => b.price.compareTo(a.price),
        SortOption.rating => b.averageRating.compareTo(a.averageRating),
        SortOption.newest => b.createdAt.compareTo(a.createdAt),
        SortOption.seatsAvailable => b.availableUnits.compareTo(a.availableUnits),
      };
      // Featured listings float to the top only for the default sort.
      if (sort == SortOption.nearest) {
        final f = featuredFirst(a, b);
        if (f != 0) return f;
      }
      return c;
    });
    return out;
  }
}
