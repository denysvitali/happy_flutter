import 'package:flutter/material.dart';

/// Size-aware network image for avatar surfaces.
///
/// Uses Flutter's built-in [Image.network] instead of a disk cache plugin.
/// The app already caps Flutter's decoded image cache in `main.dart`; keeping
/// avatars on that path avoids pulling a SQLite-backed cache into the app.
class NetworkAvatarImage extends StatelessWidget {
  const NetworkAvatarImage({
    required this.url,
    required this.size,
    required this.fallback,
    super.key,
    this.square = false,
    this.placeholder,
  });

  final String url;
  final double size;
  final bool square;
  final Widget fallback;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final radius = square ? 0.0 : size / 2;
    final loading = placeholder ??
        ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        );

    return ClipRRect(
      clipBehavior: Clip.hardEdge,
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
          errorBuilder: (context, error, stackTrace) => fallback,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return loading;
          },
        ),
      ),
    );
  }
}
