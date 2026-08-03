import 'package:flutter/material.dart';
import 'avatar.dart';
import 'avatar_palette.dart';

/// Gradient-style avatar with colorful background
class AvatarGradient extends BaseAvatar {
  const AvatarGradient({
    required super.id, super.key,
    super.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // The initials sit on top of the whole sweep, so the ink is chosen
    // against the worst point of the gradient — not just its start.
    final ink = avatarGradientInk(id, brightness);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ink.start, ink.end],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          generateInitials(id),
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
            color: ink.foreground,
          ),
        ),
      ),
    );
  }
}
