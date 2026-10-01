import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../shell/app_shell.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final mode = ref.watch(appModeProvider);
    final config = ref.watch(configProvider);
    if (user == null) return const SizedBox.shrink();
    final city = user.cityId == null ? null : config.city(user.cityId!);
    final isOwner = mode == AppMode.owner;
    final scheme = Theme.of(context).colorScheme;

    void switchMode() {
      final next = isOwner ? AppMode.seeker : AppMode.owner;
      ref.read(appModeProvider.notifier).set(next);
      context.go(next == AppMode.owner ? '/owner' : '/explore');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), actions: const [NotificationBell()]),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                UserAvatar(user, radius: 34),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      Text(user.phone, style: TextStyle(color: scheme.outline)),
                      if (city != null) Text('${config.country(city.countryId).flag}  ${city.name}', style: TextStyle(color: scheme.outline)),
                    ],
                  ),
                ),
                IconButton.filledTonal(onPressed: () => context.push('/edit-profile'), icon: const Icon(Icons.edit_outlined)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: scheme.primaryContainer,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Icon(isOwner ? Icons.travel_explore_rounded : Icons.real_estate_agent_rounded, color: scheme.onPrimaryContainer, size: 30),
                title: Text(
                  isOwner ? 'Switch to Seeker mode' : 'Switch to Owner mode',
                  style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer),
                ),
                subtitle: Text(
                  isOwner ? 'Search the map for places' : 'List and manage your properties',
                  style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: 0.8)),
                ),
                trailing: Icon(Icons.swap_horiz_rounded, color: scheme.onPrimaryContainer),
                onTap: switchMode,
              ),
            ),
          ),
          if (isOwner) ...[
            const SectionTitle('Owner'),
            _Tile(
              icon: Icons.verified_user_outlined,
              title: 'Verification & documents',
              trailing: Pill(user.ownerStatus.label, color: user.ownerStatus == OwnerStatus.approved ? AppColors.success : AppColors.warning, dense: true),
              onTap: () => context.push('/owner-verification'),
            ),
            _Tile(icon: Icons.insights_outlined, title: 'Performance', onTap: () => context.push('/owner-performance')),
            _Tile(
              icon: Icons.workspace_premium_outlined,
              title: 'Plans & payments',
              subtitle: 'Free plan · ${config.freeListingLimit} live listings',
              onTap: () => _comingSoon(context, 'Listing plans, featured listings and invoices'),
            ),
          ] else ...[
            const SectionTitle('Seeker'),
            _Tile(icon: Icons.bookmarks_outlined, title: 'Saved searches & alerts', onTap: () => context.push('/saved-searches')),
            _Tile(icon: Icons.place_outlined, title: 'Saved places', subtitle: 'Home, work, university…', onTap: () => context.push('/saved-places')),
            _Tile(icon: Icons.credit_card_outlined, title: 'Payment methods', onTap: () => _comingSoon(context, 'Payment methods and booking tokens')),
          ],
          const SectionTitle('Account'),
          _Tile(icon: Icons.person_outline_rounded, title: 'Personal information', onTap: () => context.push('/edit-profile')),
          _Tile(icon: Icons.language_rounded, title: 'Language', subtitle: 'English', onTap: () => _language(context)),
          _Tile(
            icon: Icons.card_giftcard_rounded,
            title: 'Refer a friend',
            subtitle: 'Your code: ${user.referralCode}',
            onTap: () => SharePlus.instance.share(
              ShareParams(text: 'Find hostels, flats and shops near you on StayFinder. Use my code ${user.referralCode} for free featured days!'),
            ),
          ),
          _Tile(
            icon: Icons.lock_outline_rounded,
            title: 'Privacy & security',
            onTap: () => showModalBottomSheet(context: context, builder: (_) => const _PrivacySheet()),
          ),
          _Tile(icon: Icons.support_agent_rounded, title: 'Help & support', onTap: () => context.push('/support')),
          const Divider(height: 32),
          _Tile(
            icon: Icons.logout_rounded,
            title: 'Log out',
            onTap: () async {
              if (await confirmDialog(context, title: 'Log out?', message: 'You can log back in with your mobile number.', confirm: 'Log out')) {
                await ref.read(authRepositoryProvider).logout();
              }
            },
          ),
          _Tile(
            icon: Icons.delete_forever_outlined,
            title: 'Delete account',
            color: AppColors.danger,
            onTap: () async {
              final ok = await confirmDialog(
                context,
                title: 'Delete your account?',
                message: 'Your profile, favourites and chats will be removed. Your listings will be taken down. Some records are kept as required by law.',
                confirm: 'Delete',
                destructive: true,
              );
              if (!ok) return;
              try {
                await ref.read(authRepositoryProvider).deleteAccount();
              } catch (e) {
                if (context.mounted) showSnack(context, e.toString(), error: true);
              }
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('StayFinder v1.0.0', style: TextStyle(color: scheme.outline, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _comingSoon(BuildContext context, String what) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Coming in Phase 2'),
        content: Text('$what will be available once payments are connected.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  void _language(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (code, name) in const [('en', 'English'), ('ur', 'اردو  Urdu'), ('ar', 'العربية  Arabic'), ('hi', 'हिन्दी  Hindi'), ('es', 'Español')])
              ListTile(
                title: Text(name),
                trailing: code == 'en' ? const Icon(Icons.check_rounded) : const Text('Soon', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(ctx),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, this.subtitle, this.trailing, this.onTap, this.color});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color),
    title: Text(
      title,
      style: TextStyle(fontWeight: FontWeight.w600, color: color),
    ),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _PrivacySheet extends StatelessWidget {
  const _PrivacySheet();
  @override
  Widget build(BuildContext context) => const SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your privacy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 12),
          _Point(Icons.phone_locked_outlined, 'Your phone number and email are never shown to other users.'),
          _Point(
            Icons.location_off_outlined,
            'Your live location is shared with an owner only when you turn it on for a trip, and stops on arrival or cancel.',
          ),
          _Point(Icons.folder_off_outlined, 'Ownership documents are visible only to the StayFinder verification team.'),
          _Point(
            Icons.devices_other_outlined,
            'Logging out ends this session. Deleting your account removes your data except what the law requires us to keep.',
          ),
        ],
      ),
    ),
  );
}

class _Point extends StatelessWidget {
  const _Point(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
