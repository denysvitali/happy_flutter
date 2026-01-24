import 'package:flutter/material.dart';
import 'avatar.dart';

/// Pixelated-style avatar with blocky appearance
class AvatarPixelated extends BaseAvatar {
  const AvatarPixelated({
    super.key,
    required super.id,
    super.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final color = generateColor(id);
    final initials = generateInitials(id);

    // Create a 5x5 pixel grid
    final gridSize = 5;
    final pixelSize = size / gridSize;
    final hash = id.codeUnits.fold(0, (acc, char) => acc + char);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: List.generate(gridSize * gridSize, (index) {
          final row = index ~/ gridSize;
          final col = index % gridSize;
          final pixelHash = (hash + row * 7 + col * 13) % 100;
          final shouldFill = pixelHash > 40;

          return Positioned(
            left: col * pixelSize,
            top: row * pixelSize,
            child: Container(
              width: pixelSize - 1,
              height: pixelSize - 1,
              decoration: BoxDecoration(
                color: shouldFill ? color : Colors.transparent,
              ),
            ),
          );
        }),
      ),
    );
  }
}
