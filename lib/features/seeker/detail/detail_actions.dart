import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/env.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/models.dart';
import '../../../data/providers.dart';

/// Go There (main), Chat, Call (masked), Request Visit (spec 5.6).
class DetailActionBar extends ConsumerWidget {
  const DetailActionBar({super.key, required this.property});
  final Property property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(seekerVisitsProvider).value ?? const [];
    final openVisit = visits.where((v) => v.propertyId == property.id && v.status.isOpen).firstOrNull;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 12,
      color: scheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (openVisit != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.event_available_rounded, size: 18, color: visitStatusColor(openVisit.status)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Visit ${openVisit.status.label.toLowerCase()} · ${Fmt.dateTime(openVisit.effectiveTime)}',
                          style: TextStyle(fontWeight: FontWeight.w600, color: visitStatusColor(openVisit.status)),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  _SmallAction(icon: Icons.chat_bubble_outline_rounded, label: 'Chat', onTap: () => openChat(context, ref, property)),
                  if (kMaskedCallingEnabled) _SmallAction(icon: Icons.call_outlined, label: 'Call', onTap: () => maskedCall(context, ref, property)),
                  _SmallAction(
                    icon: Icons.event_outlined,
                    label: openVisit == null ? 'Visit' : 'Visits',
                    onTap: () => openVisit == null ? showRequestVisitSheet(context, ref, property) : context.go('/visits'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push('/property/${property.id}/go${openVisit != null ? '?visit=${openVisit.id}' : ''}'),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Go There'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: SizedBox(
      width: 58,
      height: 52,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

Future<void> openChat(BuildContext context, WidgetRef ref, Property p) async {
  final me = ref.read(userProvider);
  if (me == null) return;
  final convo = await ref.read(chatRepositoryProvider).openConversation(propertyId: p.id, seekerId: me.id, ownerId: p.ownerId);
  if (context.mounted) context.push('/chat/${convo.id}');
}

/// Masked calling: both parties see only a proxy number. In production the
/// backend allocates a session number (e.g. Twilio Proxy) for this pair.
Future<void> maskedCall(BuildContext context, WidgetRef ref, Property p) async {
  final ok = await confirmDialog(
    context,
    title: 'Call the owner',
    message: 'You will be connected through a StayFinder secure line. Neither of you will see the other\'s real number.',
    confirm: 'Call now',
  );
  if (!ok) return;
  final launched = await launchUrl(Uri(scheme: 'tel', path: '+924211100011'));
  if (!launched && context.mounted) showSnack(context, 'Calling is not available on this device', error: true);
}

Future<void> showRequestVisitSheet(BuildContext context, WidgetRef ref, Property p) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RequestVisitSheet(property: p),
  );
}

class _RequestVisitSheet extends ConsumerStatefulWidget {
  const _RequestVisitSheet({required this.property});
  final Property property;
  @override
  ConsumerState<_RequestVisitSheet> createState() => _RequestVisitSheetState();
}

class _RequestVisitSheetState extends ConsumerState<_RequestVisitSheet> {
  static const _slots = [10, 12, 15, 17, 19];
  late DateTime _day = DateTime.now().add(const Duration(days: 1));
  int _hour = 17;
  final _message = TextEditingController();
  bool _sending = false;
  bool _inquiryOnly = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final me = ref.read(userProvider);
    if (me == null) return;
    setState(() => _sending = true);
    final time = DateTime(_day.year, _day.month, _day.day, _hour);
    try {
      if (_inquiryOnly) {
        await ref
            .read(activityRepositoryProvider)
            .sendInquiry(
              propertyId: widget.property.id,
              seeker: me,
              message: _message.text.trim().isEmpty ? 'I am interested in this place.' : _message.text.trim(),
              preferredVisit: time,
            );
      } else {
        await ref.read(activityRepositoryProvider).requestVisit(propertyId: widget.property.id, seekerId: me.id, time: time, message: _message.text.trim());
      }
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, _inquiryOnly ? 'Inquiry sent to the owner' : 'Visit request sent. You will be notified when the owner responds.');
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => DateTime.now().add(Duration(days: i)));
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Request visit'), icon: Icon(Icons.event_rounded)),
                ButtonSegment(value: true, label: Text("I'm interested"), icon: Icon(Icons.mark_email_unread_outlined)),
              ],
              selected: {_inquiryOnly},
              onSelectionChanged: (s) => setState(() => _inquiryOnly = s.first),
            ),
            const SizedBox(height: 16),
            Text(_inquiryOnly ? 'Preferred visit day' : 'Pick a day', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final d in days)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        showCheckmark: false,
                        selected: DateUtils.isSameDay(d, _day),
                        onSelected: (_) => setState(() => _day = d),
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1], style: const TextStyle(fontSize: 12)),
                            Text('${d.day}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Time', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final h in _slots)
                  ChoiceChip(selected: _hour == h, onSelected: (_) => setState(() => _hour = h), label: Text(Fmt.time(DateTime(2000, 1, 1, h)))),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _message,
              maxLines: 2,
              decoration: InputDecoration(hintText: _inquiryOnly ? 'Is it still available? (optional)' : 'Message for the owner (optional)'),
            ),
            const SizedBox(height: 8),
            Text(
              'The owner can accept, suggest another time or decline. Requests expire after ${ref.watch(configProvider).visitRequestExpiryHours} hours.',
              style: TextStyle(color: scheme.outline, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sending ? null : _send,
                child: Text(_sending ? 'Sending…' : (_inquiryOnly ? 'Send inquiry' : 'Send visit request')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showReportSheet(BuildContext context, WidgetRef ref, {String? propertyId, String? userId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(propertyId: propertyId, userId: userId),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({this.propertyId, this.userId});
  final String? propertyId;
  final String? userId;
  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  ReportReason? _reason;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reasons = widget.userId != null
        ? const [ReportReason.rudeBehaviour, ReportReason.safetyIssue, ReportReason.fakeListing, ReportReason.paymentIssue, ReportReason.other]
        : ReportReason.values;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.userId != null ? 'Report a person' : 'Report a problem with this listing',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final r in reasons) ChoiceChip(label: Text(r.label), selected: _reason == r, onSelected: (_) => setState(() => _reason = r))],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _details,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Tell us what happened'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _reason == null
                    ? null
                    : () async {
                        final me = ref.read(userProvider);
                        if (me == null) return;
                        await ref
                            .read(propertyRepositoryProvider)
                            .report(
                              ListingReport(
                                id: '',
                                reporterId: me.id,
                                propertyId: widget.propertyId,
                                userId: widget.userId,
                                reason: _reason!,
                                details: _details.text.trim(),
                                createdAt: DateTime.now(),
                              ),
                            );
                        if (context.mounted) {
                          Navigator.pop(context);
                          showSnack(context, 'Thanks. Our team will review this within 24 hours.');
                        }
                      },
                child: const Text('Submit report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
