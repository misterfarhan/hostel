import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/widgets/common.dart';
import '../../data/providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final _user = ref.read(userProvider)!;
  late final _name = TextEditingController(text: _user.name);
  late final _email = TextEditingController(text: _user.email ?? '');
  late final _ecName = TextEditingController(text: _user.emergencyContactName ?? '');
  late final _ecPhone = TextEditingController(text: _user.emergencyContactPhone ?? '');
  late String? _photo = _user.photoUrl;
  late String _countryId = _user.countryId ?? ref.read(configProvider).countries.first.id;
  late String? _cityId = _user.cityId;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _ecName, _ecPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2 || _cityId == null) return;
    setState(() => _saving = true);
    await ref
        .read(authRepositoryProvider)
        .updateProfile(
          ref
              .read(userProvider)!
              .copyWith(
                name: _name.text.trim(),
                email: _email.text.trim(),
                photoUrl: _photo,
                countryId: _countryId,
                cityId: _cityId,
                emergencyContactName: _ecName.text.trim().isEmpty ? null : _ecName.text.trim(),
                emergencyContactPhone: _ecPhone.text.trim().isEmpty ? null : _ecPhone.text.trim(),
              ),
        );
    if (mounted) {
      showSnack(context, 'Profile updated');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Personal information')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: () async {
                final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
                if (f != null) setState(() => _photo = f.path);
              },
              child: SizedBox(
                width: 96,
                height: 96,
                child: ClipOval(child: AppImage(_photo, fallbackIcon: Icons.person_rounded)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: Text('Tap to change photo', style: TextStyle(fontSize: 12))),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            enabled: false,
            initialValue: _user.phone,
            decoration: const InputDecoration(labelText: 'Mobile number (verified)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _countryId,
            decoration: const InputDecoration(labelText: 'Country'),
            items: [for (final c in config.countries) DropdownMenuItem(value: c.id, child: Text('${c.flag}  ${c.name}'))],
            onChanged: (v) => setState(() {
              _countryId = v!;
              _cityId = null;
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_countryId),
            initialValue: _cityId,
            decoration: const InputDecoration(labelText: 'City'),
            items: [for (final c in config.citiesOf(_countryId)) DropdownMenuItem(value: c.id, child: Text(c.name))],
            onChanged: (v) => setState(() => _cityId = v),
          ),
          const SectionTitle('Emergency contact', padding: EdgeInsets.fromLTRB(0, 24, 0, 8)),
          const Text('Used by SOS to alert someone you trust when you visit a place alone.', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: _ecName,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ecPhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
        ],
      ),
    );
  }
}
