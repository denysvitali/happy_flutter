import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/models/profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Hero-area profile header with gradient backdrop, centered avatar,
/// name in headlineSmall, and bio/subtitle in bodyMedium.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({required this.profile, super.key});

  final Profile? profile;

  static String _initialForName(String value) {
    if (value.isEmpty) return '?';
    return value.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final name = profile?.displayName?.trim();
    final avatarUrl = profile?.avatarUrl;
    final displayName =
        (name == null || name.isEmpty) ? 'Happy' : name;
    final bio =
        profile?.bio ?? 'Secure mobile companion for your sessions';

    // BackdropFilter(ImageFilter.blur) was removed — it is one of
    // Flutter's most expensive operations and the translucent
    // gradient achieves a similar frosted appearance at zero GPU
    // cost.
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withValues(
              alpha: dark ? 0.31 : 0.24,
            ),
            cs.surface.withValues(alpha: dark ? 0.80 : 0.85),
          ],
        ),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: AppOpacity.faint)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: cs.primaryContainer,
            backgroundImage: avatarUrl != null
                ? CachedNetworkImageProvider(
                    avatarUrl,
                    maxWidth: 216,
                    maxHeight: 216,
                  )
                : null,
            child: avatarUrl == null
                ? Text(
                    _initialForName(displayName),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            displayName,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            bio,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
