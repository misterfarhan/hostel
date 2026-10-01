import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  String? _photo;
  late String _countryId = ref.read(configProvider).countries.first.id;
  String? _cityId;
  AppMode _mode = AppMode.seeker;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
      if (file != null) setState(() => _photo = file.path);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not open the gallery', error: true);
    }
  }

  Future<void> _save() async {
    final user = ref.read(userProvider);
    if (user == null || _name.text.trim().length < 2 || _cityId == null) return;
    setState(() => _saving = true);
    try {
      ref.read(appModeProvider.notifier).set(_mode);
      // Ask for location now so the map can centre on the seeker (spec 5.1).
      await ref.read(locationServiceProvider).ensurePermission();
      await ref
          .read(authRepositoryProvider)
          .updateProfile(
            user.copyWith(
              name: _name.text.trim(),
              email: _email.text.trim().isEmpty ? null : _email.text.trim(),
              photoUrl: _photo,
              countryId: _countryId,
              cityId: _cityId,
            ),
          );
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider);
    final theme = Theme.of(context);
    final cities = config.citiesOf(_countryId);
    final canSave = _name.text.trim().length >= 2 && _cityId != null && !_saving;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Set up your profile', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('This helps owners and seekers trust each other.', style: TextStyle(color: theme.colorScheme.outline)),
            const SizedBox(height: 28),
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    SizedBox(
                      width: 104,
                      height: 104,
                      child: ClipOval(child: AppImage(_photo, fallbackIcon: Icons.person_rounded)),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 17,
                        backgroundColor: theme.colorScheme.primary,
                        child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (optional)', prefixIcon: Icon(Icons.mail_outline)),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _countryId,
              decoration: const InputDecoration(labelText: 'Country', prefixIcon: Icon(Icons.public)),
              items: [for (final c in config.countries) DropdownMenuItem(value: c.id, child: Text('${c.flag}  ${c.name}'))],
              onChanged: (v) => setState(() {
                _countryId = v!;
                _cityId = null;
              }),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey(_countryId),
              initialValue: _cityId,
              decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(Icons.location_city)),
              items: [for (final c in cities) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (v) => setState(() => _cityId = v),
            ),
            const SizedBox(height: 28),
            Text('What brings you here?', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _ModeCard(
              selected: _mode == AppMode.seeker,
              icon: Icons.travel_explore_rounded,
              title: 'I am looking for a place',
              subtitle: 'Hostel, flat, house, shop, office or land',
              onTap: () => setState(() => _mode = AppMode.seeker),
            ),
            const SizedBox(height: 10),
            _ModeCard(
              selected: _mode == AppMode.owner,
              icon: Icons.real_estate_agent_rounded,
              title: 'I want to list my property',
              subtitle: 'You can switch modes any time from your profile',
              onTap: () => setState(() => _mode = AppMode.owner),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: canSave ? _save : null,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.selected, required this.icon, required this.title, required this.subtitle, required this.onTap});
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer.withValues(alpha: 0.5) : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: scheme.primary, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: scheme.outline, fontSize: 13)),
                ],
              ),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? scheme.primary : scheme.outline),
          ],
        ),
      ),
    );
  }
}
