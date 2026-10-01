import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/env.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/map_widgets.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import '../../../data/services/routing_service.dart';
import '../explore/search_controller.dart';

enum _Stage { preview, onTheWay, arrived, confirmed, cancelled }

/// "Go There" — the ride part of the app (spec 5.7).
class JourneyScreen extends ConsumerStatefulWidget {
  const JourneyScreen({super.key, required this.propertyId, this.visitId});
  final String propertyId;
  final String? visitId;

  @override
  ConsumerState<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends ConsumerState<JourneyScreen> {
  final _map = MapController();
  _Stage _stage = _Stage.preview;
  LatLng? _me;
  bool _usingFallbackOrigin = false;
  RouteInfo? _route;
  bool _notifyOwner = true;
  VisitJourney? _journey;
  StreamSubscription<LatLng>? _tracking;
  Timer? _simulation;
  bool _mapReady = false;

  Property? get _property => ref.read(propertyProvider(widget.propertyId)).value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _tracking?.cancel();
    _simulation?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    var me = await ref.read(locationServiceProvider).current();
    if (me == null) {
      final s = ref.read(searchControllerProvider);
      me = s.active?.center ?? s.draft.center;
      _usingFallbackOrigin = true;
    }
    final p = await ref.read(propertyRepositoryProvider).watchProperty(widget.propertyId).first;
    if (p == null || !mounted) return;
    setState(() => _me = me);
    final route = await ref.read(routingServiceProvider).route(me, p.point);
    if (!mounted) return;
    setState(() => _route = route);
    _fitRoute();
  }

  void _fitRoute() {
    final r = _route;
    if (r == null || !_mapReady || r.points.length < 2) return;
    _map.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(r.points), padding: const EdgeInsets.fromLTRB(40, 140, 40, 300)));
  }

  double get _straightKm {
    final p = _property;
    if (p == null || _me == null) return 0;
    return Geo.distanceKm(_me!, p.point);
  }

  double? _startStraightKm;

  /// Remaining road distance and ETA, scaled from the routed trip so the
  /// numbers stay consistent with the route preview.
  (double, Duration) get _remaining {
    final r = _route;
    final start = _startStraightKm;
    final now = _straightKm;
    if (r == null || start == null || start <= 0) return (now, Geo.estimateEta(now));
    final f = (now / start).clamp(0.0, 1.0);
    return (r.distanceKm * f, Duration(seconds: (r.duration.inSeconds * f).round()));
  }

  Future<void> _start() async {
    final me = ref.read(userProvider);
    final p = _property;
    if (me == null || p == null) return;
    final journey = await ref
        .read(activityRepositoryProvider)
        .startJourney(seekerId: me.id, propertyId: p.id, visitRequestId: widget.visitId, shareWithOwner: _notifyOwner);
    setState(() {
      _journey = journey;
      _stage = _Stage.onTheWay;
      _startStraightKm = _straightKm;
    });
    if (!_usingFallbackOrigin) {
      _tracking = ref.read(locationServiceProvider).track().listen(_onPosition);
    }
  }

  void _onPosition(LatLng pos) {
    if (!mounted || _stage != _Stage.onTheWay) return;
    setState(() => _me = pos);
    if (_mapReady) _map.move(pos, _map.camera.zoom < 15 ? 15 : _map.camera.zoom);
    final threshold = ref.read(configProvider).arrivalThresholdMeters;
    final p = _property;
    if (p != null && Geo.distanceMeters(pos, p.point) <= threshold) _arrive();
  }

  /// Demo helper: drives along the route so the full flow can be tested
  /// without leaving your desk.
  void _simulate() {
    final points = _route?.points ?? const <LatLng>[];
    if (points.length < 2) return;
    _tracking?.cancel();
    final step = (points.length / 25).ceil().clamp(1, 1000);
    var i = 0;
    _simulation?.cancel();
    _simulation = Timer.periodic(const Duration(milliseconds: 600), (t) {
      i = (i + step).clamp(0, points.length - 1);
      _onPosition(points[i]);
      if (i >= points.length - 1) {
        t.cancel();
        _arrive();
      }
    });
  }

  Future<void> _arrive() async {
    if (_stage != _Stage.onTheWay) return;
    _tracking?.cancel();
    _simulation?.cancel();
    HapticFeedback.mediumImpact();
    setState(() => _stage = _Stage.arrived);
    final j = _journey;
    if (j != null) {
      await ref.read(activityRepositoryProvider).updateJourney(j.copyWith(status: JourneyStatus.arrived, arrivalTime: DateTime.now()));
    }
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel this trip?',
      message: 'Cancelling is free. The owner will be told you are no longer coming.',
      confirm: 'Cancel trip',
      destructive: true,
    );
    if (!ok) return;
    _tracking?.cancel();
    _simulation?.cancel();
    final j = _journey;
    if (j != null) await ref.read(activityRepositoryProvider).updateJourney(j.copyWith(status: JourneyStatus.cancelled));
    if (mounted) context.pop();
  }

  Future<void> _shareTrip() async {
    final p = _property;
    final link = _journey?.shareLink ?? 'https://stayfinder.app/trip';
    await SharePlus.instance.share(
      ShareParams(text: 'I am on my way to see "${p?.title}" (${p?.address}). ETA ${Geo.formatEta(_remaining.$2)}. Follow my trip live: $link'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(propertyProvider(widget.propertyId)).value;
    if (p == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final config = ref.watch(configProvider);
    final type = config.type(p.typeId);
    final country = config.country(p.countryId);
    final routePoints = _route?.points ?? const <LatLng>[];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: p.point,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onMapReady: () {
                _mapReady = true;
                _fitRoute();
              },
            ),
            children: [
              appTileLayer(),
              if (routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(points: routePoints, strokeWidth: 7, color: Colors.white),
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4.5,
                      color: AppColors.brand,
                      pattern: _route!.isEstimate ? StrokePattern.dashed(segments: const [12, 8]) : const StrokePattern.solid(),
                    ),
                  ],
                ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: p.point,
                    radius: config.arrivalThresholdMeters,
                    useRadiusInMeter: true,
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderColor: AppColors.success,
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: p.point,
                    width: PropertyPin.size.width,
                    height: PropertyPin.size.height,
                    alignment: Alignment.topCenter,
                    child: PropertyPin(type: type, property: p, selected: true),
                  ),
                  if (_me != null) Marker(point: _me!, width: 22, height: 22, child: const UserDot()),
                ],
              ),
            ],
          ),
          const Positioned(left: 0, bottom: 0, child: SafeArea(child: MapAttribution())),
          Positioned(
            top: 0,
            left: 12,
            right: 12,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    MapFab(icon: Icons.arrow_back_rounded, onPressed: () => _stage == _Stage.onTheWay ? _cancel() : context.pop()),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TopInfo(stage: _stage, property: p, remaining: _remaining, route: _route, unit: country.distanceUnit),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: AppColors.danger,
                      shape: const CircleBorder(),
                      elevation: 3,
                      child: IconButton(
                        tooltip: 'SOS',
                        onPressed: () => showSosSheet(context, ref, country, onShareLocation: _shareTrip),
                        icon: const Icon(Icons.sos_rounded, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomPanel(
              child: switch (_stage) {
                _Stage.preview => _previewPanel(p, country),
                _Stage.onTheWay => _onTheWayPanel(),
                _Stage.arrived => _ArrivedPanel(visitId: widget.visitId, onConfirmed: () => setState(() => _stage = _Stage.confirmed)),
                _Stage.confirmed => _OutcomePanel(visitId: widget.visitId!, propertyId: p.id),
                _Stage.cancelled => const SizedBox.shrink(),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewPanel(Property p, Country country) {
    final r = _route;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        Text(
          p.address,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: scheme.outline),
        ),
        const SizedBox(height: 12),
        if (r == null)
          const LinearProgressIndicator()
        else
          Row(
            children: [
              _Stat(icon: Icons.schedule_rounded, value: Geo.formatEta(r.duration), label: r.isEstimate ? 'Estimated' : 'By road'),
              const SizedBox(width: 24),
              _Stat(icon: Icons.route_rounded, value: Geo.formatDistance(r.distanceKm, country.distanceUnit), label: 'Distance'),
            ],
          ),
        if (_usingFallbackOrigin)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Location is off — route starts from your search centre.', style: TextStyle(color: AppColors.warning, fontSize: 12.5)),
          ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _notifyOwner,
          onChanged: (v) => setState(() => _notifyOwner = v),
          title: const Text('Notify owner I am coming', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Shares your live location with the owner until you arrive or cancel.'),
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.point.latitude},${p.point.longitude}&travelmode=driving'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Google Maps'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(onPressed: r == null ? null : _start, icon: const Icon(Icons.navigation_rounded), label: const Text('Start')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _onTheWayPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.directions_car_filled_rounded, color: AppColors.brand),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_notifyOwner ? 'On the way · owner can see your ETA' : 'On the way', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(onPressed: _shareTrip, icon: const Icon(Icons.share_location_rounded), label: const Text('Share trip')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: _cancel,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Cancel'),
              ),
            ),
          ],
        ),
        if (kDemoMode) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(onPressed: _simulate, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Demo: simulate drive')),
              ),
              Expanded(
                child: TextButton.icon(onPressed: _arrive, icon: const Icon(Icons.flag_rounded), label: const Text('Demo: arrive now')),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TopInfo extends StatelessWidget {
  const _TopInfo({required this.stage, required this.property, required this.remaining, required this.route, required this.unit});
  final _Stage stage;
  final Property property;
  final (double, Duration) remaining;
  final RouteInfo? route;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, color) = switch (stage) {
      _Stage.preview => ('Route preview', route == null ? 'Finding the best route…' : 'Ready when you are', AppColors.brand),
      _Stage.onTheWay => ('${Geo.formatEta(remaining.$2)} · ${Geo.formatDistance(remaining.$1, unit)}', 'to ${property.title}', AppColors.brand),
      _Stage.arrived || _Stage.confirmed => ('You have arrived', property.title, AppColors.success),
      _Stage.cancelled => ('Trip cancelled', property.title, Colors.grey),
    };
    return Material(
      elevation: 3,
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    elevation: 12,
    color: Theme.of(context).colorScheme.surface,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: AnimatedSize(duration: const Duration(milliseconds: 200), child: child),
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    ],
  );
}

/// Arrival: confirm the visit with the owner's 4-digit code (prevents fake
/// reviews). Walk-ins without a visit request skip straight to feedback.
class _ArrivedPanel extends ConsumerStatefulWidget {
  const _ArrivedPanel({required this.visitId, required this.onConfirmed});
  final String? visitId;
  final VoidCallback onConfirmed;
  @override
  ConsumerState<_ArrivedPanel> createState() => _ArrivedPanelState();
}

class _ArrivedPanelState extends ConsumerState<_ArrivedPanel> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(activityRepositoryProvider).confirmVisitCode(widget.visitId!, _code.text);
      widget.onConfirmed();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.visitId == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.where_to_vote_rounded, size: 44, color: AppColors.success),
          const SizedBox(height: 6),
          const Text('You have arrived!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'To leave a review next time, send a visit request first so the owner can confirm your visit.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.outline),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: () => context.pop(), child: const Text('Done')),
          ),
        ],
      );
    }
    final visit = ref.watch(seekerVisitsProvider).value?.where((v) => v.id == widget.visitId).firstOrNull;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.where_to_vote_rounded, size: 32, color: AppColors.success),
            SizedBox(width: 8),
            Text('You have arrived!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 6),
        Text('Ask the owner for the 4-digit visit code and enter it to confirm your visit.', style: TextStyle(color: scheme.outline)),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, letterSpacing: 14, fontWeight: FontWeight.w800),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(counterText: '', hintText: '• • • •', errorText: _error),
          onChanged: (_) => setState(() {}),
        ),
        if (kDemoMode && visit?.visitCode != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Demo: the owner\'s code is ${visit!.visitCode}', style: TextStyle(color: scheme.tertiary, fontSize: 12.5)),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: _code.text.length == 4 && !_busy ? _confirm : null, child: const Text('Confirm visit')),
        ),
      ],
    );
  }
}

class _OutcomePanel extends ConsumerWidget {
  const _OutcomePanel({required this.visitId, required this.propertyId});
  final String visitId;
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> choose(VisitOutcome o) async {
      await ref.read(activityRepositoryProvider).setVisitOutcome(visitId, o);
      if (context.mounted) context.pushReplacement('/review/$visitId');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Visit confirmed ✅', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('How did it go?'),
        const SizedBox(height: 12),
        for (final o in VisitOutcome.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => choose(o),
                icon: Icon(switch (o) {
                  VisitOutcome.interested => Icons.thumb_up_alt_outlined,
                  VisitOutcome.notInterested => Icons.thumb_down_alt_outlined,
                  VisitOutcome.needMoreTime => Icons.hourglass_empty_rounded,
                }),
                label: Text(o.label),
              ),
            ),
          ),
      ],
    );
  }
}

/// SOS / emergency (spec 13).
Future<void> showSosSheet(BuildContext context, WidgetRef ref, Country country, {Future<void> Function()? onShareLocation}) {
  final user = ref.read(userProvider);
  return showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.sos_rounded, color: AppColors.danger, size: 30),
                SizedBox(width: 10),
                Text('Emergency help', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size.fromHeight(56)),
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: country.emergencyNumber)),
              icon: const Icon(Icons.local_police_rounded),
              label: Text('Call emergency (${country.emergencyNumber})'),
            ),
            const SizedBox(height: 10),
            if (kSafetyTeamPhone.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.support_agent_rounded),
                title: const Text('Call StayFinder safety team'),
                subtitle: const Text('24/7'),
                onTap: () => launchUrl(Uri(scheme: 'tel', path: kSafetyTeamPhone)),
              ),
            ListTile(
              leading: const Icon(Icons.share_location_rounded),
              title: const Text('Share my live location'),
              onTap: () {
                Navigator.pop(ctx);
                onShareLocation?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_emergency_rounded),
              title: Text(user?.emergencyContactName == null ? 'Add an emergency contact' : 'Alert ${user!.emergencyContactName}'),
              subtitle: user?.emergencyContactPhone == null ? const Text('Set it in Profile → Personal information') : Text(user!.emergencyContactPhone!),
              onTap: () {
                final phone = user?.emergencyContactPhone;
                if (phone == null) {
                  Navigator.pop(ctx);
                  context.push('/edit-profile');
                } else {
                  launchUrl(Uri(scheme: 'sms', path: phone, queryParameters: {'body': 'I need help. I am visiting a property via StayFinder.'}));
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}
