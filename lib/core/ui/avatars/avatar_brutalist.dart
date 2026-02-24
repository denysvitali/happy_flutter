import 'package:flutter/material.dart';
import 'avatar.dart';

/// Brutalist-style avatar with bold borders and high contrast
class AvatarBrutalist extends BaseAvatar {
  const AvatarBrutalist({
    required super.id, super.key,
    super.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final color = generateColor(id);
    final initials = generateInitials(id);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
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
                color: color,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
