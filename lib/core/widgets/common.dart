import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../theme/app_theme.dart';

/// Shows a network URL or a local file path (owner uploads before sync),
/// with a branded placeholder when the image is missing or fails.
class AppImage extends StatelessWidget {
  const AppImage(this.src, {super.key, this.fit = BoxFit.cover, this.fallbackIcon = Icons.home_work_outlined, this.color});

  final String? src;
  final BoxFit fit;
  final IconData fallbackIcon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(icon: fallbackIcon, color: color ?? Theme.of(context).colorScheme.primary);
    final s = src;
    if (s == null || s.isEmpty) return placeholder;
    if (s.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: s,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      );
    }
    return Image.file(File(s), fit: fit, errorBuilder: (_, _, _) => placeholder);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.35)]),
    ),
    child: Center(child: Icon(icon, color: color.withValues(alpha: 0.7), size: 36)),
  );
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.color, this.icon, this.solid = false, this.dense = false});

  final String label;
  final Color color;
  final IconData? icon;
  final bool solid;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final fg = solid ? Colors.white : color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(color: solid ? color : color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: dense ? 11 : 13, color: fg), const SizedBox(width: 3)],
          Text(
            label,
            style: TextStyle(color: fg, fontSize: dense ? 10.5 : 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class VerifiedPill extends StatelessWidget {
  const VerifiedPill({super.key, this.dense = false, this.label = 'Verified'});
  final bool dense;
  final String label;
  @override
  Widget build(BuildContext context) => Pill(label, color: AppColors.verified, icon: Icons.verified_rounded, dense: dense);
}

class FeaturedPill extends StatelessWidget {
  const FeaturedPill({super.key, this.dense = false});
  final bool dense;
  @override
  Widget build(BuildContext context) => Pill('Featured', color: AppColors.featured, icon: Icons.bolt_rounded, solid: true, dense: dense);
}

class TypePill extends StatelessWidget {
  const TypePill(this.type, {super.key, this.dense = false});
  final PropertyType type;
  final bool dense;
  @override
  Widget build(BuildContext context) => Pill(type.name, color: type.color, icon: type.icon, dense: dense);
}

class RatingLabel extends StatelessWidget {
  const RatingLabel(this.rating, {super.key, this.count, this.size = 13});
  final double rating;
  final int? count;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) {
      return Text(
        'New',
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.outline),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: size + 3, color: AppColors.accent),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w700),
        ),
        if (count != null)
          Text(
            ' ($count)',
            style: TextStyle(fontSize: size, color: Theme.of(context).colorScheme.outline),
          ),
      ],
    );
  }
}

class StarRatingInput extends StatelessWidget {
  const StarRatingInput({super.key, required this.value, required this.onChanged, this.size = 32});
  final double value;
  final ValueChanged<double> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) {
      final filled = i < value;
      return IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        iconSize: size,
        onPressed: () => onChanged(i + 1.0),
        icon: Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.accent),
      );
    }),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 8)});
  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
        ?trailing,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: scheme.primaryContainer,
              child: Icon(icon, size: 38, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.outline),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar(this.user, {super.key, this.radius = 22});
  final AppUser? user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photo = user?.photoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: photo == null ? null : (photo.startsWith('http') ? CachedNetworkImageProvider(photo) : FileImage(File(photo)) as ImageProvider),
      child: Text(
        user?.initials ?? '?',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: radius * 0.7, color: scheme.onPrimaryContainer),
      ),
    );
  }
}

Color listingStatusColor(ListingStatus s) => switch (s) {
  ListingStatus.live => AppColors.success,
  ListingStatus.pendingReview => AppColors.warning,
  ListingStatus.draft => Colors.blueGrey,
  ListingStatus.rejected || ListingStatus.suspended => AppColors.danger,
  ListingStatus.paused || ListingStatus.expired => Colors.grey,
  ListingStatus.full || ListingStatus.rented || ListingStatus.sold => AppColors.verified,
};

Color visitStatusColor(VisitStatus s) => switch (s) {
  VisitStatus.requested || VisitStatus.rescheduled => AppColors.warning,
  VisitStatus.accepted || VisitStatus.onTheWay || VisitStatus.arrived => AppColors.verified,
  VisitStatus.completed => AppColors.success,
  _ => Colors.grey,
};

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? AppColors.danger : null));
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String confirm = 'Confirm', bool destructive = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(64, 40))
              : FilledButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}
