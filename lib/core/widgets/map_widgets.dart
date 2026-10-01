import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../data/models/models.dart';
import '../theme/app_theme.dart';
import '../utils/geo.dart';

/// OpenStreetMap tiles. For production switch to a commercial tile provider
/// (Mapbox, MapTiler, Google) — OSM's public servers are for light use only.
TileLayer appTileLayer() =>
    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.stayfinder.stayfinder', maxZoom: 19);

/// Small attribution required by the OSM tile usage policy.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    color: Colors.white.withValues(alpha: 0.75),
    child: const Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 9, color: Colors.black87)),
  );
}

CircleMarker radiusCircle(LatLng center, double radiusKm, {Color color = AppColors.brand}) => CircleMarker(
  point: center,
  radius: radiusKm * 1000,
  useRadiusInMeter: true,
  color: color.withValues(alpha: 0.10),
  borderColor: color.withValues(alpha: 0.8),
  borderStrokeWidth: 2,
);

/// Camera bounds that fully contain a radius circle.
LatLngBounds boundsForRadius(LatLng center, double radiusKm) {
  final n = Geo.offset(center, radiusKm, 0);
  final e = Geo.offset(center, radiusKm, 90);
  final s = Geo.offset(center, radiusKm, 180);
  final w = Geo.offset(center, radiusKm, 270);
  return LatLngBounds(LatLng(s.latitude, w.longitude), LatLng(n.latitude, e.longitude));
}

/// A property pin. Icon depends on type; Featured pins are larger with a gold
/// ring; Verified pins carry a blue check (spec 5.3).
class PropertyPin extends StatelessWidget {
  const PropertyPin({super.key, required this.type, required this.property, this.selected = false, this.onTap});

  final PropertyType type;
  final Property property;
  final bool selected;
  final VoidCallback? onTap;

  static const size = Size(52, 60);

  @override
  Widget build(BuildContext context) {
    final featured = property.isFeatured;
    final full = property.status == ListingStatus.full;
    final color = full ? Colors.grey : type.color;
    final d = selected ? 46.0 : (featured ? 40.0 : 34.0);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              bottom: 0,
              child: CustomPaint(size: const Size(14, 10), painter: _PinTail(color)),
            ),
            Positioned(
              bottom: 8,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: d,
                height: d,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: featured ? AppColors.accent : Colors.white, width: featured ? 3 : 2.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: selected ? 10 : 4, offset: const Offset(0, 2))],
                ),
                child: Icon(type.icon, color: Colors.white, size: d * 0.52),
              ),
            ),
            if (property.isVerified)
              Positioned(
                bottom: 8 + d - 14,
                right: (size.width - d) / 2 - 4,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.verified_rounded, size: 16, color: AppColors.verified),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PinTail extends CustomPainter {
  _PinTail(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinTail old) => old.color != color;
}

class ClusterBubble extends StatelessWidget {
  const ClusterBubble({super.key, required this.count, this.onTap});
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final d = count < 10 ? 40.0 : (count < 50 ? 48.0 : 56.0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: d,
        height: d,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brand,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(color: AppColors.brand.withValues(alpha: 0.35), blurRadius: 0, spreadRadius: 5),
            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6),
          ],
        ),
        child: Text(
          '$count',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
    );
  }
}

/// Pulsing blue dot for the user's GPS position.
class UserDot extends StatelessWidget {
  const UserDot({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      color: AppColors.verified,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: [BoxShadow(color: AppColors.verified.withValues(alpha: 0.35), blurRadius: 0, spreadRadius: 8)],
    ),
  );
}

/// The search-centre marker.
class CenterMarker extends StatelessWidget {
  const CenterMarker({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.brand, width: 5),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
    ),
  );
}

class MapCluster<T> {
  MapCluster(this.items, this.center);
  final List<T> items;
  final LatLng center;
  bool get isSingle => items.length == 1;
}

/// Grid-based clustering in screen space: items whose pins would overlap at
/// the current zoom are merged into a numbered bubble (spec 5.3).
List<MapCluster<T>> clusterItems<T>(List<T> items, LatLng Function(T) pointOf, double zoom, {double cellPx = 60, double maxClusterZoom = 16}) {
  if (zoom >= maxClusterZoom) {
    return [
      for (final i in items) MapCluster([i], pointOf(i)),
    ];
  }
  final scale = 256 * math.pow(2, zoom);
  final cells = <String, List<T>>{};
  for (final item in items) {
    final p = pointOf(item);
    final x = (p.longitude + 180) / 360 * scale;
    final latRad = p.latitude * math.pi / 180;
    final y = (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * scale;
    final key = '${(x / cellPx).floor()}:${(y / cellPx).floor()}';
    (cells[key] ??= []).add(item);
  }
  return [
    for (final group in cells.values)
      MapCluster(
        group,
        LatLng(
          group.map((e) => pointOf(e).latitude).reduce((a, b) => a + b) / group.length,
          group.map((e) => pointOf(e).longitude).reduce((a, b) => a + b) / group.length,
        ),
      ),
  ];
}

/// Round white floating button used on maps.
class MapFab extends StatelessWidget {
  const MapFab({super.key, required this.icon, required this.onPressed, this.tooltip});
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: const CircleBorder(),
    elevation: 3,
    child: IconButton(tooltip: tooltip, onPressed: onPressed, icon: Icon(icon)),
  );
}
