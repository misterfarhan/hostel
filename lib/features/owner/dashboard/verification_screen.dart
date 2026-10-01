import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/env.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';

/// Owner registration & verification (spec 7.1).
class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});
  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  String? _uploading;
  bool _submitting = false;

  Future<void> _upload(OwnerDocument doc) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 2000, imageQuality: 85);
      if (file == null) return;
      setState(() => _uploading = doc.kind);
      await ref.read(authRepositoryProvider).uploadOwnerDocument(doc.kind, file.path);
    } catch (e) {
      if (mounted) showSnack(context, 'Upload failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(authRepositoryProvider).submitOwnerVerification();
      if (mounted) showSnack(context, 'Submitted! Our team will review your documents.');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    if (user == null) return const SizedBox.shrink();
    final status = user.ownerStatus;
    final editable = status == OwnerStatus.notSubmitted || status == OwnerStatus.rejected;
    final scheme = Theme.of(context).colorScheme;
    const steps = [OwnerStatus.notSubmitted, OwnerStatus.underReview, OwnerStatus.approved];
    final stepIndex = switch (status) {
      OwnerStatus.approved => 2,
      OwnerStatus.pending || OwnerStatus.underReview => 1,
      _ => 0,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Verification')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: i <= stepIndex ? AppColors.success : scheme.outlineVariant,
                          child: Icon(
                            i < stepIndex || status == OwnerStatus.approved ? Icons.check : Icons.circle,
                            size: i < stepIndex || status == OwnerStatus.approved ? 18 : 8,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(['Upload', 'Review', 'Approved'][i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (i < steps.length - 1) Expanded(child: Divider(thickness: 2, color: i < stepIndex ? AppColors.success : scheme.outlineVariant)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (status == OwnerStatus.approved)
            const Card(
              color: Color(0xFFE8F5E9),
              child: ListTile(
                leading: Icon(Icons.verified_rounded, color: AppColors.success),
                title: Text('You are a Verified Owner', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('You can publish listings. Your documents stay private.'),
              ),
            ),
          if (status == OwnerStatus.underReview || status == OwnerStatus.pending)
            const Card(
              child: ListTile(
                leading: Icon(Icons.hourglass_top_rounded, color: AppColors.verified),
                title: Text('Under review', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Usually within 24 hours. We will notify you.'),
              ),
            ),
          const SectionTitle('Documents', padding: EdgeInsets.fromLTRB(0, 16, 0, 8)),
          for (final d in user.documents)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: SizedBox(
                  width: 48,
                  height: 48,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: d.filePath == null
                        ? Container(color: scheme.surfaceContainerHighest, child: const Icon(Icons.description_outlined))
                        : AppImage(d.filePath),
                  ),
                ),
                title: Text(d.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(d.required ? d.status.label : '${d.status.label} · optional'),
                trailing: _uploading == d.kind
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : editable
                    ? TextButton(onPressed: () => _upload(d), child: Text(d.filePath == null ? 'Upload' : 'Replace'))
                    : d.status == DocumentStatus.missing
                    ? const Icon(Icons.remove_rounded)
                    : Icon(
                        d.status == DocumentStatus.approved ? Icons.check_circle_rounded : Icons.schedule_rounded,
                        color: d.status == DocumentStatus.approved ? AppColors.success : AppColors.warning,
                      ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: scheme.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Documents are encrypted and visible only to the verification team.', style: TextStyle(color: scheme.outline, fontSize: 12.5)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (editable && kDemoMode)
            TextButton.icon(
              onPressed: () async {
                final repo = ref.read(authRepositoryProvider);
                for (final d in user.documents.where((d) => d.required && d.filePath == null)) {
                  await repo.uploadOwnerDocument(d.kind, 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=600');
                }
              },
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Demo: use sample documents'),
            ),
          if (editable) FilledButton(onPressed: _submitting ? null : _submit, child: Text(_submitting ? 'Submitting…' : 'Submit for verification')),
        ],
      ),
    );
  }
}
