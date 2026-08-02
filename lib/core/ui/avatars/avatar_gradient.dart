import 'package:flutter/material.dart';
import 'avatar.dart';

/// Gradient-style avatar with colorful background
class AvatarGradient extends BaseAvatar {
  const AvatarGradient({
    required super.id, super.key,
    super.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryColor = generateColor(id, brightness);
    final secondaryColor = generateSecondaryColor(id, brightness);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          generateInitials(id),
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
            color: generateOnColor(primaryColor),
          ),
        ),
      ),
    );
  }
}
