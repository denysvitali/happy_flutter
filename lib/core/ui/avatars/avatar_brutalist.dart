import 'package:flutter/material.dart';
import 'avatar.dart';
import 'avatar_palette.dart';

/// Brutalist-style avatar with bold borders and high contrast
class AvatarBrutalist extends BaseAvatar {
  const AvatarBrutalist({
    required super.id, super.key,
    super.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = generateColor(id, theme.brightness);
    // The initials sit on the card surface, not on the identity fill, so
    // they need the on-surface ink variant to stay readable in both themes.
    final ink = avatarInkOnSurface(id, theme.brightness);
    final initials = generateInitials(id);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(
          color: color,
          width: 3,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            offset: const Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        clipBehavior: Clip.hardEdge,
        borderRadius: BorderRadius.circular(size / 2 - 3),
        child: Container(
          color: color.withValues(alpha: 0.1),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.35,
                fontWeight: FontWeight.bold,
                color: ink,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
