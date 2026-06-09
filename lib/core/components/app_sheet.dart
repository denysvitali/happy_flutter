import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';

/// Blur strength applied to the frosted sheet surface.
const double _kSheetBlurSigma = 24;

/// Shows a modal bottom sheet with the app's frosted-glass treatment:
/// a translucent blurred surface, rounded top corners, a drag handle,
/// and a light haptic tick on open.
///
/// Drop-in replacement for [showModalBottomSheet] at chat/settings
/// call sites so every sheet shares one visual language.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  Color? barrierColor,
}) {
  HapticFeedback.lightImpact();
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: _kSheetBlurSigma,
          sigmaY: _kSheetBlurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Translucent fill over the blur creates the frosted look
            // while keeping content underneath faintly visible.
            color: cs.surface.withValues(alpha: 0.88),
            border: Border(
              top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.3),
                width: AppBorder.hairline,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetDragHandle(),
              Flexible(child: Builder(builder: builder)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.xs,
      ),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: cs.onSurfaceVariant.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}
