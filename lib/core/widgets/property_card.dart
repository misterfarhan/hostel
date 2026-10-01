import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/geo.dart';
import '../utils/property_facts.dart';
import 'common.dart';

/// Heart button bound to the favourites stream.
class FavouriteButton extends ConsumerWidget {
  const FavouriteButton({super.key, required this.propertyId, this.onImage = false, this.size = 22});
  final String propertyId;
  final bool onImage;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fav = ref.watch(favouritesProvider).value?.contains(propertyId) ?? false;
    final icon = Icon(
      fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      color: fav ? Colors.redAccent : (onImage ? Colors.white : Theme.of(context).colorScheme.outline),
      size: size,
    );
    void toggle() {
      final uid = ref.read(userProvider)?.id;
      if (uid == null) return;
      ref.read(activityRepositoryProvider).toggleFavourite(uid, propertyId);
      showSnack(context, fav ? 'Removed from saved' : 'Saved to favourites');
    }

    if (onImage) {
      return Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: toggle,
          child: Padding(padding: const EdgeInsets.all(7), child: icon),
        ),
      );
    }
    return IconButton(visualDensity: VisualDensity.compact, tooltip: fav ? 'Remove from saved' : 'Save', onPressed: toggle, icon: icon);
  }
}

/// Horizontal list card: photo, title, type, price, distance, ETA, key facts,
/// rating, verified badge and Detail button (spec 5.5).
class PropertyCard extends ConsumerWidget {
  const PropertyCard({super.key, required this.property, this.origin, this.highlighted = false, this.onTap, this.trailing, this.showDetailButton = true});

  final Property property;

  /// Distance/ETA are measured from here (search centre or user location).
  final LatLng? origin;
  final bool highlighted;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showDetailButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final type = config.type(property.typeId);
    final country = config.country(property.countryId);
    final scheme = Theme.of(context).colorScheme;
    final facts = PropertyFacts.keyFacts(property, type);
    final km = origin == null ? null : Geo.distanceKm(origin!, property.point);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: highlighted
              ? scheme.primary
              : (property.isFeatured ? AppColors.featured.withValues(alpha: 0.6) : scheme.outlineVariant.withValues(alpha: 0.5)),
          width: highlighted ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap ?? () => context.push('/property/${property.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 108,
                  height: 118,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppImage(property.mainPhoto, fallbackIcon: type.icon, color: type.color),
                      if (property.isFeatured) const Positioned(left: 6, top: 6, child: FeaturedPill(dense: true)),
                      if (property.status == ListingStatus.full)
                        Container(
                          color: Colors.black45,
                          alignment: Alignment.center,
                          child: const Text(
                            'FULL',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
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
                    const SizedBox(height: 5),
                    Text(
                      property.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      property.area,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.outline, fontSize: 12.5),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: Fmt.money(property.price, country, compact: true),
                            style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary, fontSize: 15),
                          ),
                          TextSpan(
                            text: ' ${property.pricePeriod.suffix}',
                            style: TextStyle(color: scheme.outline, fontSize: 12),
                          ),
                          if (property.negotiable)
                            TextSpan(
                              text: ' · Negotiable',
                              style: TextStyle(color: scheme.outline, fontSize: 11.5),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (facts.isNotEmpty)
                      Text(
                        facts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        RatingLabel(property.averageRating, count: property.reviewCount == 0 ? null : property.reviewCount, size: 12),
                        if (km != null) ...[
                          Text('  ·  ', style: TextStyle(color: scheme.outline)),
                          Icon(Icons.near_me_rounded, size: 13, color: scheme.outline),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              '${Geo.formatDistance(km, country.distanceUnit)} · ${Geo.formatEta(Geo.estimateEta(km))}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: scheme.outline),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  trailing ?? FavouriteButton(propertyId: property.id),
                  if (showDetailButton) ...[
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 32,
                      child: FilledButton.tonal(
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
