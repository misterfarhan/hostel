import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/env.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/property_facts.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/map_widgets.dart';
import '../../../core/widgets/property_card.dart';
import '../../../data/config/app_config.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';
import 'dynamic_field.dart';

/// Owner listing wizard (spec 4.8): one small page at a time, Save as Draft
/// at any step, validation before submit.
class AddPropertyScreen extends ConsumerStatefulWidget {
  const AddPropertyScreen({super.key, this.editId});
  final String? editId;

  @override
  ConsumerState<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends ConsumerState<AddPropertyScreen> {
  static const _titles = ['Property type', 'Location', 'Details', 'Price', 'Photos', 'Rules & nearby', 'Preview', 'Submit'];

  final _pages = PageController();
  int _step = 0;
  bool _showErrors = false;
  bool _saving = false;

  // Draft state.
  String? _id;
  ListingStatus _status = ListingStatus.draft;
  DateTime? _createdAt;
  String? _typeId;
  ListingPurpose? _purpose;
  LatLng? _point;
  String? _cityId;
  String _area = '';
  String _address = '';
  String _title = '';
  String _description = '';
  int _totalUnits = 0;
  int _availableUnits = 0;
  Map<String, dynamic> _details = {};
  double? _price;
  PricePeriod? _period;
  bool _negotiable = false;
  double _deposit = 0;
  int _advance = 0;
  int _agreement = 0;
  DateTime? _availableFrom;
  GenderRule _gender = GenderRule.any;
  List<String> _included = [];
  List<PriceExtra> _extras = [];
  List<String> _photos = [];
  String _videoUrl = '';
  String _rules = '';
  List<NearbyPlace> _nearby = [];
  String _contact = 'Chat';
  String _bestTime = '';
  LatLng? _gps;

  AppConfig get _config => ref.read(configProvider);
  PropertyType? get _type => _typeId == null ? null : _config.type(_typeId!);

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    _cityId = user?.cityId ?? _config.cities.first.id;
    if (widget.editId != null) {
      final p = ref.read(propertyProvider(widget.editId!)).value;
      if (p != null) _load(p);
    }
    ref.read(locationServiceProvider).current().then((pos) {
      if (!mounted) return;
      setState(() {
        _gps = pos;
        _point ??= pos;
      });
    });
  }

  void _load(Property p) {
    _id = p.id;
    _status = p.status;
    _createdAt = p.createdAt;
    _typeId = p.typeId;
    _purpose = p.purpose;
    _point = p.point;
    _cityId = p.cityId;
    _area = p.area;
    _address = p.address;
    _title = p.title;
    _description = p.description;
    _totalUnits = p.totalUnits;
    _availableUnits = p.availableUnits;
    _details = Map.of(p.details);
    _price = p.price;
    _period = p.pricePeriod;
    _negotiable = p.negotiable;
    _deposit = p.deposit;
    _advance = p.advanceMonths;
    _agreement = p.agreementMonths;
    _availableFrom = p.availableFrom;
    _gender = p.genderRule;
    _included = [...p.included];
    _extras = [...p.extras];
    _photos = [...p.photos];
    _videoUrl = p.videoUrl ?? '';
    _rules = p.rules;
    _nearby = [...p.nearby];
    _contact = p.preferredContact;
    _bestTime = p.bestTimeToCall;
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  City? _cityForPoint(LatLng p) {
    City? best;
    var bestKm = double.infinity;
    for (final c in _config.cities.where((c) => c.enabled)) {
      final km = Geo.distanceKm(c.center, p);
      if (km <= c.maxRadiusKm * 1.6 && km < bestKm) {
        best = c;
        bestKm = km;
      }
    }
    return best;
  }

  /// Returns an error message for the current step, or null when valid.
  String? _validate(int step) {
    final type = _type;
    if (type == null) return 'Choose a property type';
    switch (step) {
      case 0:
        if (_purpose == null) return 'Choose rent, sale or lease';
      case 1:
        if (_point == null) return 'Drop a pin on the map';
        if (_cityForPoint(_point!) == null) return 'This location is outside our enabled service areas';
        if (_area.trim().isEmpty) return 'Enter the area / neighbourhood';
        if (_address.trim().isEmpty) return 'Enter the full address';
      case 2:
        if (_title.trim().length < 5) return 'Title must be at least 5 characters';
        if (type.usesUnits && _totalUnits <= 0) return 'Enter total ${type.unitsLabel.toLowerCase()}';
        if (type.usesUnits && _availableUnits > _totalUnits) return 'Available ${type.unitsLabel.toLowerCase()} cannot exceed total';
        final missing = PropertyFacts.missingRequired(_details, type);
        if (missing.isNotEmpty) return 'Please fill: ${missing.map((f) => f.label).join(', ')}';
      case 3:
        if (_price == null || _price! <= 0) return 'Enter a price';
      case 4:
        if (_photos.length < type.minPhotos) return 'Add at least ${type.minPhotos} photos';
    }
    return null;
  }

  void _next() {
    final error = _validate(_step);
    if (error != null) {
      setState(() => _showErrors = true);
      showSnack(context, error, error: true);
      return;
    }
    _showErrors = false;
    if (_step < _titles.length - 1) _go(_step + 1);
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _pages.animateToPage(step, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Property _build() {
    final type = _type ?? _config.propertyTypes.first;
    final city = _config.city(_cityId ?? _config.cities.first.id);
    final country = _config.country(city.countryId);
    final user = ref.read(userProvider)!;
    final now = DateTime.now();
    return Property(
      id: _id ?? '',
      ownerId: user.id,
      typeId: type.id,
      purpose: _purpose ?? type.purposes.first,
      title: _title.trim(),
      description: _description.trim(),
      countryId: country.id,
      cityId: city.id,
      area: _area.trim(),
      address: _address.trim(),
      point: _point ?? city.center,
      price: _price ?? 0,
      pricePeriod: _period ?? type.defaultPeriod,
      currency: country.currencyCode,
      negotiable: _negotiable,
      deposit: _deposit,
      advanceMonths: _advance,
      agreementMonths: _agreement,
      availableFrom: _availableFrom,
      totalUnits: _totalUnits,
      availableUnits: _availableUnits,
      genderRule: type.forcedGender ?? _gender,
      details: _details,
      included: _included,
      extras: _extras,
      photos: _photos,
      videoUrl: _videoUrl.trim().isEmpty ? null : _videoUrl.trim(),
      rules: _rules.trim(),
      nearby: _nearby,
      preferredContact: _contact,
      bestTimeToCall: _bestTime,
      status: _status,
      createdAt: _createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _saveDraft() async {
    if (_type == null) {
      showSnack(context, 'Choose a property type first', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref.read(propertyRepositoryProvider).saveProperty(_build());
      _id = saved.id;
      _createdAt = saved.createdAt;
      if (mounted) showSnack(context, _status == ListingStatus.draft ? 'Draft saved' : 'Changes saved');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    for (var s = 0; s < 5; s++) {
      final e = _validate(s);
      if (e != null) {
        setState(() => _showErrors = true);
        _go(s);
        showSnack(context, e, error: true);
        return;
      }
    }
    setState(() => _saving = true);
    final repo = ref.read(propertyRepositoryProvider);
    try {
      final saved = await repo.saveProperty(_build());
      _id = saved.id;
      final wasLive = _status == ListingStatus.live;
      if (!wasLive) await repo.submitForReview(saved.id);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
          title: Text(wasLive ? 'Listing updated' : 'Submitted for review'),
          content: Text(
            wasLive
                ? 'Your changes are live.'
                : 'Our team will check your listing${_type!.safetyHighlighted ? ' (girls hostels get an extra safety check)' : ''}. You will be notified when it goes live.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      if (mounted) context.go('/owner/listings');
    } catch (e) {
      // Saved as draft even if submit is blocked (e.g. plan limit).
      _status = ListingStatus.draft;
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.editId == null ? 'Add property' : 'Edit property'),
          actions: [TextButton(onPressed: _saving ? null : _saveDraft, child: const Text('Save draft'))],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(34),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step ${_step + 1} of ${_titles.length} · ${_titles[_step]}',
                    style: TextStyle(color: scheme.outline, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: (_step + 1) / _titles.length, minHeight: 5, borderRadius: BorderRadius.circular(3)),
                ],
              ),
            ),
          ),
        ),
        body: PageView(
          controller: _pages,
          physics: const NeverScrollableScrollPhysics(),
          children: [_typeStep(), _locationStep(), _detailsStep(), _priceStep(), _photosStep(), _rulesStep(), _previewStep(), _submitStep()],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(onPressed: () => _go(_step - 1), child: const Text('Back')),
                  ),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : (_step == _titles.length - 1 ? _submit : _next),
                    child: Text(
                      _saving
                          ? 'Please wait…'
                          : (_step == _titles.length - 1 ? (_status == ListingStatus.live ? 'Save changes' : 'Submit for review') : 'Next'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Step 1 ---------------------------------------------------------------

  Widget _typeStep() {
    final type = _type;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('What are you listing?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            for (final t in _config.propertyTypes)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() {
                  if (_typeId != t.id) {
                    _details = {};
                    _included = [];
                  }
                  _typeId = t.id;
                  _purpose = t.purposes.first;
                  _period = t.defaultPeriod;
                  _gender = t.forcedGender ?? GenderRule.any;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: _typeId == t.id ? t.color.withValues(alpha: 0.12) : Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _typeId == t.id ? t.color : Theme.of(context).colorScheme.outlineVariant, width: _typeId == t.id ? 2 : 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(t.icon, color: t.color, size: 32),
                      const SizedBox(height: 6),
                      Text(
                        t.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (type != null) ...[
          const SizedBox(height: 20),
          const Text('Listing purpose', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final p in type.purposes)
                ChoiceChip(
                  label: Text(p.label),
                  selected: _purpose == p,
                  onSelected: (_) => setState(() {
                    _purpose = p;
                    _period = p == ListingPurpose.sale ? PricePeriod.oneTime : (p == ListingPurpose.perSeat ? PricePeriod.perSeatMonth : type.defaultPeriod);
                  }),
                ),
            ],
          ),
        ],
      ],
    );
  }

  // --- Step 2 ---------------------------------------------------------------

  Widget _locationStep() {
    final city = _config.city(_cityId!);
    final pinCity = _point == null ? null : _cityForPoint(_point!);
    final farFromGps = _gps != null && _point != null && Geo.distanceKm(_gps!, _point!) > 1;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Where is it?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Tap the map to drop the pin exactly on the entrance.'),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 280,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _point ?? city.center,
                initialZoom: _point == null ? 12 : 16,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                onTap: (_, p) async {
                  setState(() {
                    _point = p;
                    final c = _cityForPoint(p);
                    if (c != null) _cityId = c.id;
                  });
                  final addr = await ref.read(geocodingServiceProvider).reverse(p);
                  if (addr != null && mounted) {
                    setState(() {
                      _address = addr;
                      if (_area.isEmpty) _area = addr.split(',').take(2).join(',').trim();
                    });
                  }
                },
              ),
              children: [
                appTileLayer(),
                if (_point != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _point!,
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 44),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () async {
                final pos = await ref.read(locationServiceProvider).current();
                if (pos == null) {
                  if (mounted) showSnack(context, 'Location unavailable. Tap the map instead.', error: true);
                  return;
                }
                setState(() {
                  _gps = pos;
                  _point = pos;
                  final c = _cityForPoint(pos);
                  if (c != null) _cityId = c.id;
                });
              },
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Use current location'),
            ),
            const Spacer(),
            if (pinCity != null) Pill(pinCity.name, color: AppColors.success, icon: Icons.check_rounded),
          ],
        ),
        if (_point != null && pinCity == null)
          const Text('This pin is outside our service areas. Listings can only be published in enabled cities.', style: TextStyle(color: AppColors.danger)),
        if (farFromGps)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'You seem far from this pin. We may ask you to confirm the location on-site before approval.',
              style: TextStyle(color: AppColors.warning, fontSize: 12.5),
            ),
          ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('area_${_area.isEmpty}'),
          initialValue: _area,
          decoration: InputDecoration(labelText: 'Area / neighbourhood *', errorText: _showErrors && _area.trim().isEmpty ? 'Required' : null),
          onChanged: (v) => _area = v,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('addr_$_address'),
          initialValue: _address,
          maxLines: 2,
          decoration: InputDecoration(labelText: 'Full address *', errorText: _showErrors && _address.trim().isEmpty ? 'Required' : null),
          onChanged: (v) => _address = v,
        ),
      ],
    );
  }

  // --- Step 3 ---------------------------------------------------------------

  Widget _detailsStep() {
    final type = _type;
    if (type == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${type.name} details', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _title,
          maxLength: 70,
          decoration: InputDecoration(
            labelText: 'Title *',
            hintText: 'e.g. Scholars Boys Hostel near Punjab University',
            errorText: _showErrors && _title.trim().length < 5 ? 'At least 5 characters' : null,
          ),
          onChanged: (v) => _title = v,
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _description,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(labelText: 'Short description', alignLabelWithHint: true),
          onChanged: (v) => _description = v,
        ),
        if (type.usesUnits) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _totalUnits == 0 ? '' : '$_totalUnits',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'Total ${type.unitsLabel.toLowerCase()} *'),
                  onChanged: (v) => _totalUnits = int.tryParse(v) ?? 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: _availableUnits == 0 ? '' : '$_availableUnits',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Available now *'),
                  onChanged: (v) => _availableUnits = int.tryParse(v) ?? 0,
                ),
              ),
            ],
          ),
        ],
        for (final group in type.groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 10),
            child: Row(
              children: [
                Text(group, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                const Expanded(child: Divider()),
              ],
            ),
          ),
          for (final f in type.fields.where((f) => f.group == group))
            DynamicFieldInput(
              field: f,
              value: _details[f.key],
              showError: _showErrors,
              onChanged: (v) => setState(() => v == null ? _details.remove(f.key) : _details[f.key] = v),
            ),
        ],
      ],
    );
  }

  // --- Step 4 ---------------------------------------------------------------

  Widget _priceStep() {
    final type = _type;
    if (type == null) return const SizedBox.shrink();
    final country = _config.country(_config.city(_cityId!).countryId);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Price and terms', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _price == null ? '' : _price!.round().toString(),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            labelText: 'Price *',
            prefixText: '${country.currencyCode} ',
            errorText: _showErrors && (_price ?? 0) <= 0 ? 'Required' : null,
          ),
          onChanged: (v) => _price = double.tryParse(v),
        ),
        _PriceHint(typeId: type.id, cityId: _cityId!, area: _area, country: country),
        const SizedBox(height: 12),
        const Text('Price period', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final p in PricePeriod.values)
              ChoiceChip(
                label: Text(switch (p) {
                  PricePeriod.perMonth => 'Per month',
                  PricePeriod.perSeatMonth => 'Per seat / month',
                  PricePeriod.perDay => 'Per day',
                  PricePeriod.oneTime => 'One-time',
                }),
                selected: (_period ?? type.defaultPeriod) == p,
                onSelected: (_) => setState(() => _period = p),
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Price is negotiable'),
          value: _negotiable,
          onChanged: (v) => setState(() => _negotiable = v),
        ),
        if (_purpose != ListingPurpose.sale) ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _deposit == 0 ? '' : _deposit.round().toString(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Security deposit'),
                  onChanged: (v) => _deposit = double.tryParse(v) ?? 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: _advance == 0 ? '' : '$_advance',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Advance', suffixText: 'months'),
                  onChanged: (v) => _advance = int.tryParse(v) ?? 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _agreement == 0 ? '' : '$_agreement',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Agreement / contract length', suffixText: 'months'),
            onChanged: (v) => _agreement = int.tryParse(v) ?? 0,
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              firstDate: now.subtract(const Duration(days: 1)),
              lastDate: now.add(const Duration(days: 365)),
              initialDate: _availableFrom ?? now,
            );
            if (d != null) setState(() => _availableFrom = d);
          },
          icon: const Icon(Icons.event_available_rounded),
          label: Text(_availableFrom == null ? 'Available from: now' : 'Available from ${Fmt.date(_availableFrom!)}'),
        ),
        if (type.forcedGender == null) ...[
          const SizedBox(height: 16),
          const Text('Who can stay / use it', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final g in GenderRule.values) ChoiceChip(label: Text(g.label), selected: _gender == g, onSelected: (_) => setState(() => _gender = g)),
            ],
          ),
        ],
        if (type.includedOptions.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('What is included in the price', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in type.includedOptions)
                FilterChip(label: Text(o), selected: _included.contains(o), onSelected: (on) => setState(() => on ? _included.add(o) : _included.remove(o))),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text('Extra charges (not included)', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            TextButton.icon(onPressed: _addExtra, icon: const Icon(Icons.add), label: const Text('Add')),
          ],
        ),
        for (final e in _extras)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(e.name),
            subtitle: Text(Fmt.money(e.price, country)),
            trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _extras.remove(e))),
          ),
      ],
    );
  }

  Future<void> _addExtra() async {
    final name = TextEditingController();
    final price = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Extra charge'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. AC electricity'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    final p = double.tryParse(price.text);
    if (ok == true && name.text.trim().isNotEmpty && p != null) {
      setState(() => _extras.add(PriceExtra(name: name.text.trim(), price: p)));
    }
  }

  // --- Step 5 ---------------------------------------------------------------

  Future<void> _pickPhotos() async {
    try {
      final files = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 80);
      final room = _config.maxPhotos - _photos.length;
      if (files.isEmpty) return;
      setState(() => _photos.addAll(files.take(room).map((f) => f.path)));
      if (files.length > room && mounted) showSnack(context, 'Maximum ${_config.maxPhotos} photos');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not open the gallery', error: true);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
      if (f != null) setState(() => _photos.add(f.path));
    } catch (_) {
      if (mounted) showSnack(context, 'Camera not available', error: true);
    }
  }

  Widget _photosStep() {
    final type = _type;
    if (type == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Photos and video', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          'At least ${type.minPhotos}, up to ${_config.maxPhotos}. Tap ★ to set the main photo; long-press to reorder.',
          style: TextStyle(color: scheme.outline),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(onPressed: _pickPhotos, icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.photo_camera_outlined), label: const Text('Camera')),
            ),
          ],
        ),
        if (kDemoMode)
          TextButton.icon(
            onPressed: () => setState(() => _photos.addAll(_demoPhotos(type))),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Demo: add sample photos'),
          ),
        const SizedBox(height: 12),
        if (_photos.isEmpty)
          Container(
            height: 140,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: _showErrors ? scheme.error : scheme.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text('No photos yet', style: TextStyle(color: scheme.outline)),
          )
        else
          ReorderableListView(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            physics: const NeverScrollableScrollPhysics(),
            onReorderItem: (a, b) => setState(() => _photos.insert(b, _photos.removeAt(a))),
            children: [
              for (var i = 0; i < _photos.length; i++)
                ReorderableDelayedDragStartListener(
                  key: ValueKey('${_photos[i]}_$i'),
                  index: i,
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        SizedBox(width: 110, height: 76, child: AppImage(_photos[i])),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(i == 0 ? 'Main photo' : 'Photo ${i + 1}', style: TextStyle(fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w500)),
                        ),
                        IconButton(
                          tooltip: 'Set as main',
                          onPressed: i == 0 ? null : () => setState(() => _photos.insert(0, _photos.removeAt(i))),
                          icon: Icon(i == 0 ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.accent),
                        ),
                        IconButton(onPressed: () => setState(() => _photos.removeAt(i)), icon: const Icon(Icons.delete_outline)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _videoUrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Video link (optional)',
            hintText: 'YouTube or 360° tour link',
            prefixIcon: Icon(Icons.videocam_outlined),
          ),
          onChanged: (v) => _videoUrl = v,
        ),
      ],
    );
  }

  List<String> _demoPhotos(PropertyType type) {
    const base = 'https://images.unsplash.com/photo-';
    const q = '?w=1000&q=70&auto=format&fit=crop';
    final ids = switch (type.id) {
      'boys_hostel' || 'girls_hostel' || 'other' => ['1555854877-bab0e564b8d5', '1505693416388-ac5ce068fe85', '1540518614846-7eded433c457'],
      'flat' => ['1502672260266-1c1ef2d93688', '1560448204-e02f11c3d0e2', '1586023492125-27b2c045efd7'],
      'house' => ['1564013799919-ab600027ffc6', '1568605114967-8130f3a36994', '1570129477492-45c003edd2be'],
      'shop' => ['1441986300917-64674bd600d8', '1604719312566-8912e9227c6a', '1472224371017-08207f84aaae'],
      'office' => ['1497366216548-37526070297c', '1497366811353-6870744d04b2', '1521737604893-d14cc237f11d'],
      _ => ['1500382017468-9049fed747ef', '1416331108676-a22ccb276e35', '1500382017468-9049fed747ef'],
    };
    return ids.map((id) => '$base$id$q').toList();
  }

  // --- Step 6 ---------------------------------------------------------------

  Widget _rulesStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Rules and nearby places', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _rules,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Rules and notes', alignLabelWithHint: true, hintText: 'e.g. No smoking. Rent due by the 5th.'),
          onChanged: (v) => _rules = v,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text('Nearby places', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            TextButton.icon(onPressed: _addNearby, icon: const Icon(Icons.add), label: const Text('Add')),
          ],
        ),
        for (final n in _nearby)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: Text(n.name),
            subtitle: Text('${n.category} · ${n.distanceKm.toStringAsFixed(1)} km'),
            trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _nearby.remove(n))),
          ),
        if (kMaskedCallingEnabled) ...[
          const SizedBox(height: 16),
          const Text('Preferred contact', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final c in kMaskedCallingEnabled ? const ['Chat', 'Call', 'Chat or call'] : const ['Chat'])
                ChoiceChip(label: Text(c), selected: _contact == c, onSelected: (_) => setState(() => _contact = c)),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _bestTime,
            decoration: const InputDecoration(labelText: 'Best time to call', hintText: 'e.g. 10 AM – 6 PM'),
            onChanged: (v) => _bestTime = v,
          ),
        ],
        const SizedBox(height: 16),
        Text(
          kMaskedCallingEnabled
              ? 'Your phone number is never shown. Calls go through a masked line.'
              : 'Your phone number is never shown. Seekers contact you through in-app chat.',
          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12.5),
        ),
      ],
    );
  }

  Future<void> _addNearby() async {
    final name = TextEditingController();
    final km = TextEditingController();
    var category = 'University';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Nearby place'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in const ['University', 'Hospital', 'Market', 'Transport', 'Office', 'Landmark']) DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setD(() => category = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: km,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Distance', suffixText: 'km'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    final d = double.tryParse(km.text);
    if (ok == true && name.text.trim().isNotEmpty) {
      setState(() => _nearby.add(NearbyPlace(name: name.text.trim(), category: category, distanceKm: d ?? 0.5)));
    }
  }

  // --- Step 7 ---------------------------------------------------------------

  Widget _previewStep() {
    if (_type == null) return const SizedBox.shrink();
    final draft = _build().copyWith(status: ListingStatus.live);
    final type = _type!;
    final country = _config.country(draft.countryId);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Preview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('This is how seekers will see your listing.'),
        const SectionTitle('On the map', padding: EdgeInsets.fromLTRB(0, 16, 0, 8)),
        Row(
          children: [
            PropertyPin(type: type, property: draft, selected: true),
            const SizedBox(width: 12),
            Expanded(child: Text('${type.name} pin${draft.isFeatured ? ' (featured)' : ''}')),
          ],
        ),
        const SectionTitle('In the list', padding: EdgeInsets.fromLTRB(0, 16, 0, 8)),
        IgnorePointer(child: PropertyCard(property: draft)),
        const SectionTitle('Detail page summary', padding: EdgeInsets.fromLTRB(0, 16, 0, 8)),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: AppImage(draft.mainPhoto, fallbackIcon: type.icon, color: type.color),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(draft.title.isEmpty ? 'Untitled' : draft.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('${draft.area}, ${_config.city(draft.cityId).name}'),
                    const SizedBox(height: 6),
                    Text(
                      Fmt.price(draft, country),
                      style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(PropertyFacts.keyFacts(draft, type).join(' · ')),
                    if (draft.included.isNotEmpty) Text('Includes: ${draft.included.join(', ')}'),
                    Text('${draft.photos.length} photos · ${PropertyFacts.grouped(draft, type).values.fold<int>(0, (s, l) => s + l.length)} details filled'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Step 8 ---------------------------------------------------------------

  Widget _submitStep() {
    final checks = [for (var s = 0; s < 5; s++) (_titles[s], _validate(s))];
    final allOk = checks.every((c) => c.$2 == null);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(allOk ? 'Ready to submit' : 'Almost there', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        for (final (i, (title, error)) in checks.indexed)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                error == null ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: error == null ? AppColors.success : AppColors.danger,
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: error == null ? null : Text(error),
              trailing: error == null ? null : TextButton(onPressed: () => _go(i), child: const Text('Fix')),
            ),
          ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'By submitting you confirm the details and photos are accurate and you have the right to list this property. '
              'Fake or misleading listings are removed and may lead to account suspension.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceHint extends ConsumerWidget {
  const _PriceHint({required this.typeId, required this.cityId, required this.area, required this.country});
  final String typeId;
  final String cityId;
  final String area;
  final Country country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<double?>(
      future: ref.read(propertyRepositoryProvider).averagePrice(typeId: typeId, cityId: cityId, area: area),
      builder: (_, snap) => snap.data == null
          ? const SizedBox(height: 8)
          : Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.insights_rounded, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Similar listings nearby average ${Fmt.money(snap.data!, country)}', style: const TextStyle(fontSize: 12.5))),
                ],
              ),
            ),
    );
  }
}
