import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';

/// Rate the property and owner after a confirmed visit (spec 9).
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.visitId});
  final String visitId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _ratings = {for (final k in Review.categoryLabels.keys) k: 0.0};
  final _comment = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  bool get _complete => _ratings.values.every((v) => v > 0);

  Future<void> _submit(VisitRequest visit) async {
    final me = ref.read(userProvider);
    if (me == null) return;
    setState(() => _saving = true);
    try {
      final overall = _ratings.values.reduce((a, b) => a + b) / _ratings.length;
      await ref
          .read(propertyRepositoryProvider)
          .addReview(
            Review(
              id: 'r_${DateTime.now().millisecondsSinceEpoch}',
              propertyId: visit.propertyId,
              authorId: me.id,
              authorName: me.name,
              overall: double.parse(overall.toStringAsFixed(1)),
              categories: Map.of(_ratings),
              comment: _comment.text.trim(),
              createdAt: DateTime.now(),
            ),
            visitRequestId: visit.id,
          );
      if (mounted) {
        showSnack(context, 'Thanks for your review!');
        context.go('/visits');
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visit = ref.watch(seekerVisitsProvider).value?.where((v) => v.id == widget.visitId).firstOrNull;
    final property = visit == null ? null : ref.watch(propertyProvider(visit.propertyId)).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate your visit'),
        actions: [TextButton(onPressed: () => context.go('/visits'), child: const Text('Later'))],
      ),
      body: visit == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (property != null)
                  Card(
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(width: 56, height: 56, child: AppImage(property.mainPhoto)),
                      ),
                      title: Text(property.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(property.area),
                    ),
                  ),
                const SizedBox(height: 12),
                for (final e in Review.categoryLabels.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        StarRatingInput(value: _ratings[e.key]!, size: 28, onChanged: (v) => setState(() => _ratings[e.key] = v)),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _comment,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(hintText: 'Share details that would help other seekers (optional)'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only one review per confirmed visit. Reviews are checked for abuse before they appear.',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _complete && !_saving ? () => _submit(visit) : null, child: Text(_saving ? 'Submitting…' : 'Submit review')),
              ],
            ),
    );
  }
}
