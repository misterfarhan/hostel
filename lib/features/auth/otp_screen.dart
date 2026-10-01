import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../core/widgets/common.dart';
import '../../data/mock/mock_backend.dart';
import '../../data/providers.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});
  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _length = 6;
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _secondsLeft = 60;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) t.cancel();
      if (mounted) setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != _length || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyOtp(widget.phone, _code.text);
      // Router redirect takes over (setup or home).
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        _code.clear();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(authRepositoryProvider).requestOtp(widget.phone);
      _startTimer();
      if (mounted) showSnack(context, 'A new code has been sent');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(backgroundColor: theme.colorScheme.surface),
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Enter verification code', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                text: 'We sent a 6-digit code to ',
                children: [
                  TextSpan(
                    text: widget.phone,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              style: TextStyle(color: theme.colorScheme.outline, fontSize: 15),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => _focus.requestFocus(),
              child: Stack(
                children: [
                  // Invisible field captures input (supports paste & SMS autofill).
                  Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _code,
                      focusNode: _focus,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_length)],
                      onChanged: (v) {
                        setState(() => _error = null);
                        if (v.length == _length) _verify();
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_length, (i) {
                      final char = i < _code.text.length ? _code.text[i] : '';
                      final active = i == _code.text.length && _focus.hasFocus;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 48,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            width: active ? 2 : 1,
                            color: _error != null ? theme.colorScheme.error : (active ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
                          ),
                        ),
                        child: Text(char, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                      );
                    }),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: theme.colorScheme.error))],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _code.text.length == _length && !_loading ? _verify : null,
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Verify'),
            ),
            const SizedBox(height: 12),
            Center(
              child: _secondsLeft > 0
                  ? Text('Resend code in 0:${_secondsLeft.toString().padLeft(2, '0')}', style: TextStyle(color: theme.colorScheme.outline))
                  : TextButton(onPressed: _resend, child: const Text('Resend code')),
            ),
            if (kDemoMode) ...[
              const SizedBox(height: 24),
              Card(
                color: theme.colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: theme.colorScheme.onTertiaryContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Demo mode: no SMS is sent. Use code ${MockBackend.demoOtp}.',
                          style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
