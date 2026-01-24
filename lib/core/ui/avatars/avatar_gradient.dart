import 'package:flutter/material.dart';
import 'avatar.dart';

/// Gradient-style avatar with colorful background
class AvatarGradient extends BaseAvatar {
  const AvatarGradient({
    super.key,
    required super.id,
    super.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = generateColor(id);
    final secondaryColor = generateSecondaryColor(id);

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
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
