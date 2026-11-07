import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Surface tint over the blur: enough to keep chips legible while the
/// transcript still reads as motion behind the dock.
const double _dockTint = 0.72;

/// Blur behind the chat's bottom dock (activity bars and composer).
final ui.ImageFilter _dockBlur = ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18);

/// Lays the chat [dock] over the bottom of [body] on frosted glass, so the
/// newest messages stay faintly visible as they scroll under the composer.
///
/// The dock's measured height is published through [inset]; the body must
/// pad its scrollable content (and any bottom-anchored overlays) by that
/// amount so the last message can still scroll fully above the dock.
class FrostedBottomDock extends StatelessWidget {
  const FrostedBottomDock({
    required this.body,
    required this.dock,
    required this.inset,
    super.key,
  });

  final Widget body;
  final Widget dock;
  final ValueNotifier<double> inset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(child: body),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _HeightReporter(
            inset: inset,
            child: ClipRect(
              child: BackdropFilter(
                key: const ValueKey<String>('chat-frosted-dock'),
                filter: _dockBlur,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: _dockTint),
                  ),
                  child: dock,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Publishes its child's laid-out height to [inset] after layout.
class _HeightReporter extends SingleChildRenderObjectWidget {
  const _HeightReporter({required this.inset, super.child});

  final ValueNotifier<double> inset;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeightReporter(inset);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeightReporter renderObject,
  ) {
    renderObject.inset = inset;
  }
}

class _RenderHeightReporter extends RenderProxyBox {
  _RenderHeightReporter(this.inset);

  ValueNotifier<double> inset;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (inset.value == height) return;
    // Listeners rebuild the list padding; never mutate during layout.
    final target = inset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached && identical(target, inset)) target.value = height;
    });
  }
}
