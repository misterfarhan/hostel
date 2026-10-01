import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/property_facts.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/map_widgets.dart';
import '../../../core/widgets/property_card.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import '../explore/search_controller.dart';
import 'detail_actions.dart';

class PropertyDetailScreen extends ConsumerStatefulWidget {
  const PropertyDetailScreen({super.key, required this.propertyId});
  final String propertyId;

  @override
  ConsumerState<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen> {
  final _page = PageController();
  int _photo = 0;

  @override
  void initState() {
    super.initState();
    ref.read(propertyRepositoryProvider).recordView(widget.propertyId);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(propertyProvider(widget.propertyId));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.error_outline, title: 'Could not load', message: '$e'),
      ),
      data: (p) => p == null
          ? Scaffold(
              appBar: AppBar(),
              body: const EmptyState(icon: Icons.home_work_outlined, title: 'Listing not available', message: 'This listing was removed or is no longer live.'),
            )
          : _build(context, p),
    );
  }

  Widget _build(BuildContext context, Property p) {
    final config = ref.watch(configProvider);
    final type = config.type(p.typeId);
    final country = config.country(p.countryId);
    final me = ref.watch(userProvider);
    final isMine = me?.id == p.ownerId;
    final scheme = Theme.of(context).colorScheme;
    final search = ref.watch(searchControllerProvider);
    final origin = search.userLocation ?? search.active?.center;
    final km = origin == null ? null : Geo.distanceKm(origin, p.point);
    final groups = PropertyFacts.grouped(p, type);
    final photos = p.photos.isEmpty ? <String?>[null] : p.photos;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            foregroundColor: Colors.white,
            backgroundColor: scheme.primary,
            leading: const _CircleBack(),
            actions: [
              _AppBarCircle(child: FavouriteButton(propertyId: p.id, size: 20)),
              _AppBarCircle(
                child: IconButton(
                  tooltip: 'Share',
                  icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(text: '${p.title} — ${Fmt.price(p, country)}\n${p.area}, ${config.city(p.cityId).name}\nhttps://stayfinder.app/p/${p.id}'),
                  ),
                ),
              ),
              _AppBarCircle(
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                  onSelected: (v) {
                    if (v == 'report') showReportSheet(context, ref, propertyId: p.id);
                    if (v == 'support') context.push('/support');
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'report',
                      child: ListTile(leading: Icon(Icons.flag_outlined), title: Text('Report listing')),
                    ),
                    PopupMenuItem(
                      value: 'support',
                      child: ListTile(leading: Icon(Icons.support_agent), title: Text('Contact support')),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _page,
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _photo = i),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => _openGallery(context, p.photos, i),
                      child: AppImage(photos[i], fallbackIcon: type.icon, color: type.color),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black45, Colors.transparent, Colors.transparent, Colors.black38],
                        stops: [0, 0.3, 0.7, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        '${_photo + 1} / ${photos.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (p.videoUrl != null)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.black54, minimumSize: const Size(0, 34)),
                        onPressed: () => launchUrl(Uri.parse(p.videoUrl!)),
                        icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                        label: const Text('Video'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      TypePill(type),
                      Pill(p.purpose.label, color: scheme.secondary),
                      if (p.isVerified) const VerifiedPill(label: 'Verified listing'),
                      if (p.isFeatured) const FeaturedPill(),
                      if (p.status != ListingStatus.live) Pill(p.status.label, color: listingStatusColor(p.status), solid: true),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(p.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 16, color: scheme.outline),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('${p.area}, ${config.city(p.cityId).name}', style: TextStyle(color: scheme.outline)),
                      ),
                      RatingLabel(p.averageRating, count: p.reviewCount == 0 ? null : p.reviewCount),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PriceCard(property: p, country: country, type: type),
                  if (type.usesUnits) ...[const SizedBox(height: 12), _UnitsCard(property: p, type: type)],
                  if (type.safetyHighlighted) ...[const SizedBox(height: 12), _SafetyCard(property: p)],
                  const SizedBox(height: 12),
                  const _ScamWarning(),
                ],
              ),
            ),
          ),
          if (p.included.isNotEmpty || p.extras.isNotEmpty)
            SliverToBoxAdapter(
              child: _Section(
                title: 'What is included in the price',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final i in p.included)
                          Chip(
                            avatar: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                            label: Text(i),
                          ),
                      ],
                    ),
                    if (p.extras.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Extra charges',
                        style: TextStyle(fontWeight: FontWeight.w700, color: scheme.outline),
                      ),
                      for (final e in p.extras)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle_outline, size: 18, color: AppColors.warning),
                              const SizedBox(width: 8),
                              Expanded(child: Text(e.name)),
                              Text(Fmt.money(e.price, country), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          if (p.description.isNotEmpty)
            SliverToBoxAdapter(
              child: _Section(
                title: 'About this place',
                child: Text(p.description, style: const TextStyle(height: 1.45)),
              ),
            ),
          for (final entry in groups.entries)
            SliverToBoxAdapter(
              child: _Section(
                title: entry.key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final (field, value) in entry.value) _DetailRow(field: field, value: value, country: country)],
                ),
              ),
            ),
          if (p.rules.isNotEmpty)
            SliverToBoxAdapter(
              child: _Section(
                title: 'Rules and notes',
                child: Text(p.rules, style: const TextStyle(height: 1.45)),
              ),
            ),
          if (p.nearby.isNotEmpty)
            SliverToBoxAdapter(
              child: _Section(
                title: 'Nearby',
                child: Column(
                  children: [
                    for (final n in p.nearby)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(_nearbyIcon(n.category), color: scheme.primary),
                        title: Text(n.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(n.category),
                        trailing: Text(Geo.formatDistance(n.distanceKm, country.distanceUnit)),
                      ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Location',
              child: _LocationCard(property: p, km: km, unit: country.distanceUnit),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Owner',
              child: OwnerCard(ownerId: p.ownerId, preferredContact: p.preferredContact, bestTime: p.bestTimeToCall),
            ),
          ),
          SliverToBoxAdapter(child: _ReviewsSection(property: p)),
          SliverToBoxAdapter(child: _SimilarNearby(property: p)),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: isMine
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: () => context.push('/manage/${p.id}'),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Manage this listing'),
                ),
              ),
            )
          : DetailActionBar(property: p),
    );
  }

  IconData _nearbyIcon(String category) => switch (category) {
    'Hospital' => Icons.local_hospital_outlined,
    'Market' => Icons.shopping_bag_outlined,
    'Transport' => Icons.directions_bus_outlined,
    'University' => Icons.school_outlined,
    _ => Icons.place_outlined,
  };

  void _openGallery(BuildContext context, List<String> photos, int index) {
    if (photos.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: PageView.builder(
            controller: PageController(initialPage: index),
            itemCount: photos.length,
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(child: AppImage(photos[i], fit: BoxFit.contain)),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleBack extends StatelessWidget {
  const _CircleBack();
  @override
  Widget build(BuildContext context) => _AppBarCircle(
    child: IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
      onPressed: () => context.canPop() ? context.pop() : context.go('/explore'),
    ),
  );
}

class _AppBarCircle extends StatelessWidget {
  const _AppBarCircle({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(4),
    child: Material(
      color: Colors.black.withValues(alpha: 0.3),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(width: 40, height: 40, child: Center(child: child)),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.field, required this.value, required this.country});
  final PropertyField field;
  final dynamic value;
  final Country country;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (value is List) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label, style: TextStyle(color: scheme.outline)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final v in value as List) Pill(v.toString(), color: scheme.primary)]),
          ],
        ),
      );
    }
    final isBool = value is bool;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(field.label, style: TextStyle(color: scheme.outline)),
          ),
          const SizedBox(width: 12),
          if (isBool)
            Icon(value as bool ? Icons.check_circle_rounded : Icons.cancel_outlined, color: value as bool ? AppColors.success : scheme.outline, size: 20)
          else
            Expanded(
              child: Text(
                field.money && value is num
                    ? (value == 0 ? 'Included' : Fmt.money((value as num).toDouble(), country))
                    : PropertyFacts.formatValue(value, unit: field.unit),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _PriceCard extends ConsumerWidget {
  const _PriceCard({required this.property, required this.country, required this.type});
  final Property property;
  final Country country;
  final PropertyType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = property;
    final scheme = Theme.of(context).colorScheme;
    final rows = <(String, String)>[
      if (p.deposit > 0) ('Security deposit', Fmt.money(p.deposit, country)),
      if (p.advanceMonths > 0) ('Advance', '${p.advanceMonths} month${p.advanceMonths > 1 ? 's' : ''}'),
      if (p.agreementMonths > 0) ('Agreement', '${p.agreementMonths} months'),
      if (p.availableFrom != null) ('Available from', p.availableFrom!.isBefore(DateTime.now()) ? 'Now' : Fmt.date(p.availableFrom!)),
      if (p.genderRule != GenderRule.any) ('Who can stay', p.genderRule.label),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.money(p.price, country),
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: scheme.primary),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(p.pricePeriod.suffix, style: TextStyle(color: scheme.outline)),
              ),
              const Spacer(),
              if (p.negotiable) const Pill('Negotiable', color: AppColors.success, icon: Icons.handshake_outlined),
            ],
          ),
          if (rows.isNotEmpty) const Divider(height: 24),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: TextStyle(color: scheme.outline)),
                  ),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          _PriceGuidance(property: p, country: country),
        ],
      ),
    );
  }
}

/// Average price of similar places nearby, shown only as a hint (spec 10).
class _PriceGuidance extends ConsumerWidget {
  const _PriceGuidance({required this.property, required this.country});
  final Property property;
  final Country country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (property.pricePeriod == PricePeriod.oneTime) return const SizedBox.shrink();
    return FutureBuilder<double?>(
      future: ref.read(propertyRepositoryProvider).averagePrice(typeId: property.typeId, cityId: property.cityId, area: property.area),
      builder: (context, snap) {
        final avg = snap.data;
        if (avg == null) return const SizedBox.shrink();
        final diff = (property.price - avg) / avg * 100;
        final label = diff.abs() < 5 ? 'around the average' : (diff < 0 ? '${diff.abs().round()}% below average' : '${diff.round()}% above average');
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: Theme.of(context).colorScheme.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Similar places nearby average ${Fmt.money(avg, country)} — this is $label.',
                  style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.outline),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UnitsCard extends StatelessWidget {
  const _UnitsCard({required this.property, required this.type});
  final Property property;
  final PropertyType type;

  @override
  Widget build(BuildContext context) {
    final p = property;
    final full = p.availableUnits <= 0;
    final ratio = p.totalUnits == 0 ? 0.0 : (p.totalUnits - p.availableUnits) / p.totalUnits;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 6,
                    backgroundColor: AppColors.success.withValues(alpha: 0.15),
                    color: full ? AppColors.danger : AppColors.warning,
                  ),
                  Icon(type.icon, color: type.color),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    full
                        ? 'Currently full'
                        : '${p.availableUnits} ${p.availableUnits == 1 ? _singular(type.unitsLabel) : type.unitsLabel.toLowerCase()} available now',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: full ? AppColors.danger : AppColors.success),
                  ),
                  Text('${p.totalUnits} ${type.unitsLabel.toLowerCase()} in total', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _singular(String plural) {
  final s = plural.toLowerCase();
  return s.endsWith('s') ? s.substring(0, s.length - 1) : s;
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.property});
  final Property property;

  @override
  Widget build(BuildContext context) {
    final d = property.details;
    final safety = (d['safety'] as List?)?.cast<String>() ?? const [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE4EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF48FB1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_rounded, color: Color(0xFFD81B60)),
              SizedBox(width: 8),
              Text(
                'Safety features',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF880E4F)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final s in safety) Pill(s, color: const Color(0xFFD81B60), icon: Icons.check_rounded)],
          ),
          const SizedBox(height: 10),
          if (d['warden_name'] != null)
            Text(
              'Warden: ${d['warden_name']}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF880E4F)),
            ),
          if (d['entry_timing'] != null) Text('Gate timing: ${d['entry_timing']}', style: const TextStyle(color: Color(0xFF880E4F))),
          const SizedBox(height: 6),
          const Text('Safety concern? Use Report → Safety issue. It goes to a dedicated team.', style: TextStyle(fontSize: 12, color: Color(0xFF880E4F))),
        ],
      ),
    );
  }
}

class _ScamWarning extends StatelessWidget {
  const _ScamWarning();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8E1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFFE082)),
    ),
    child: const Row(
      children: [
        Icon(Icons.gpp_maybe_rounded, color: AppColors.warning),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Never pay advance money before visiting, and never outside the app.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6D4C00), fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _LocationCard extends ConsumerWidget {
  const _LocationCard({required this.property, required this.km, required this.unit});
  final Property property;
  final double? km;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(configProvider).type(property.typeId);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 170,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: property.point,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                appTileLayer(),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: property.point,
                      width: PropertyPin.size.width,
                      height: PropertyPin.size.height,
                      alignment: Alignment.topCenter,
                      child: PropertyPin(type: type, property: property, selected: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(property.address, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (km != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${Geo.formatDistance(km!, unit)} from you · about ${Geo.formatEta(Geo.estimateEta(km!))} by road',
              style: TextStyle(color: scheme.outline),
            ),
          ),
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: () => launchUrl(
            Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${property.point.latitude},${property.point.longitude}'),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('Open in Google Maps'),
        ),
      ],
    );
  }
}

class OwnerCard extends ConsumerWidget {
  const OwnerCard({super.key, required this.ownerId, this.preferredContact, this.bestTime});
  final String ownerId;
  final String? preferredContact;
  final String? bestTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(userByIdProvider(ownerId)).value;
    final scheme = Theme.of(context).colorScheme;
    if (owner == null) return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            UserAvatar(owner, radius: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(owner.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                      if (owner.badges.contains(OwnerBadge.verifiedOwner)) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, color: AppColors.verified, size: 18),
                      ],
                    ],
                  ),
                  RatingLabel(owner.rating, count: owner.ratingCount == 0 ? null : owner.ratingCount),
                  Text(owner.responseLabel, style: TextStyle(color: scheme.outline, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final b in owner.badges)
              Pill(
                b.label,
                color: switch (b) {
                  OwnerBadge.verifiedOwner => AppColors.verified,
                  OwnerBadge.fastResponder => AppColors.success,
                  OwnerBadge.topRated => AppColors.featured,
                },
                icon: switch (b) {
                  OwnerBadge.verifiedOwner => Icons.verified_user_rounded,
                  OwnerBadge.fastResponder => Icons.bolt_rounded,
                  OwnerBadge.topRated => Icons.emoji_events_rounded,
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: scheme.outline),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Phone hidden · ${preferredContact ?? 'Chat'}${bestTime == null || bestTime!.isEmpty ? '' : ' · Best time: $bestTime'}',
                style: TextStyle(color: scheme.outline, fontSize: 12.5),
              ),
            ),
          ],
        ),
        if (owner.joinedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Member since ${Fmt.date(owner.joinedAt!)}', style: TextStyle(color: scheme.outline, fontSize: 12.5)),
          ),
      ],
    );
  }
}

class _ReviewsSection extends ConsumerWidget {
  const _ReviewsSection({required this.property});
  final Property property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(reviewsProvider(property.id)).value ?? const [];
    final scheme = Theme.of(context).colorScheme;
    return _Section(
      title: 'Reviews',
      child: reviews.isEmpty
          ? Text('No reviews yet. Reviews can only be left after a confirmed visit.', style: TextStyle(color: scheme.outline))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(property.averageRating.toStringAsFixed(1), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (i) =>
                                Icon(i < property.averageRating.round() ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.accent, size: 18),
                          ),
                        ),
                        Text('${property.reviewCount} reviews from verified visits', style: TextStyle(color: scheme.outline, fontSize: 12.5)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _CategoryBars(reviews: reviews),
                const Divider(height: 24),
                for (final r in reviews.take(3)) ReviewTile(review: r),
                if (reviews.length > 3)
                  TextButton(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => DraggableScrollableSheet(
                        expand: false,
                        initialChildSize: 0.8,
                        builder: (_, scroll) => ListView(
                          controller: scroll,
                          padding: const EdgeInsets.all(16),
                          children: [for (final r in reviews) ReviewTile(review: r)],
                        ),
                      ),
                    ),
                    child: Text('See all ${reviews.length} reviews'),
                  ),
              ],
            ),
    );
  }
}

class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.reviews});
  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final e in Review.categoryLabels.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Builder(
              builder: (context) {
                final values = reviews.map((r) => r.categories[e.key]).whereType<double>().toList();
                final avg = values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
                return Row(
                  children: [
                    SizedBox(width: 130, child: Text(e.value, style: const TextStyle(fontSize: 12.5))),
                    Expanded(
                      child: LinearProgressIndicator(value: avg / 5, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        avg.toStringAsFixed(1),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 16, child: Text(review.authorName[0])),
              const SizedBox(width: 8),
              Expanded(
                child: Text(review.authorName, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              RatingLabel(review.overall, size: 12),
            ],
          ),
          const SizedBox(height: 6),
          Text(review.comment),
          const SizedBox(height: 2),
          Text('Verified visit · ${Fmt.relative(review.createdAt)}', style: TextStyle(color: scheme.outline, fontSize: 12)),
          if (review.ownerReply != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
              child: Text('Owner: ${review.ownerReply}', style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

class _SimilarNearby extends ConsumerWidget {
  const _SimilarNearby({required this.property});
  final Property property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(livePropertiesProvider).value ?? const [];
    final similar = live.where((p) => p.id != property.id && p.typeId == property.typeId && Geo.distanceKm(p.point, property.point) < 5).toList()
      ..sort((a, b) => Geo.distanceKm(a.point, property.point).compareTo(Geo.distanceKm(b.point, property.point)));
    if (similar.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Similar places nearby'),
        for (final p in similar.take(4))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: PropertyCard(property: p, origin: property.point),
          ),
      ],
    );
  }
}
