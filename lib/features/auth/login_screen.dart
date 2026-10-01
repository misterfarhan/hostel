import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import 'splash_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  late Country _country = ref.read(configProvider).countries.first;
  bool _loading = false;
  bool _agreed = true;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0'), '');
  bool get _valid => _digits.length >= 9 && _digits.length <= 11 && _agreed;

  Future<void> _submit() async {
    if (!_valid || _loading) return;
    setState(() => _loading = true);
    final phone = '${_country.dialCode}$_digits';
    try {
      await ref.read(authRepositoryProvider).requestOtp(phone);
      if (mounted) context.push('/otp?phone=${Uri.encodeComponent(phone)}');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 56)),
            const SizedBox(height: 36),
            Text('Find your next place,\nright on the map.', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 10),
            Text(
              'Hostels, flats, houses, shops, offices and land — near you, with real photos and verified owners.',
              style: TextStyle(color: theme.colorScheme.outline, fontSize: 15),
            ),
            const SizedBox(height: 36),
            Text('Mobile number', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final picked = await showModalBottomSheet<Country>(
                      context: context,
                      builder: (_) => SafeArea(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final c in config.countries)
                              ListTile(
                                leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                                title: Text(c.name),
                                trailing: Text(c.dialCode),
                                onTap: () => Navigator.pop(context, c),
                              ),
                          ],
                        ),
                      ),
                    );
                    if (picked != null) setState(() => _country = picked);
                  },
                  child: Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Text(_country.flag, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 6),
                        Text(_country.dialCode, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phone,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 1),
                    decoration: const InputDecoration(hintText: '300 1234567'),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v ?? false)),
                Expanded(
                  child: Text(
                    'I agree to the Terms of Service and Privacy Policy. My number stays private — owners never see it.',
                    style: TextStyle(color: theme.colorScheme.outline, fontSize: 12.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _valid && !_loading ? _submit : null,
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Send OTP'),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text('We will send a 6-digit code by SMS.', style: TextStyle(color: theme.colorScheme.outline, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
