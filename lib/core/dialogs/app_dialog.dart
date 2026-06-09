import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Maximum scrim blur, reached when the dialog is fully presented.
const double _kDialogBlurSigma = 6;

/// Shows a dialog with an animated frosted scrim and a gentle
/// scale-up entrance, replacing the default instant dim + fade.
///
/// The backdrop blur strength and scrim opacity track the route
/// animation, so the background melts away as the dialog scales in
/// from 0.92 with a soft overshoot — the treatment used by iOS
/// alerts. Drop-in replacement for [showDialog].
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(
      context,
    ).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: AppDuration.normal,
    pageBuilder: (ctx, animation, secondaryAnimation) =>
        Builder(builder: builder),
    transitionBuilder: (ctx, animation, _, child) {
      final t = CurvedAnimation(
        parent: animation,
        curve: AppCurve.enter,
        reverseCurve: AppCurve.exit,
      ).value;
      final scale = lerpDouble(0.92, 1.0, Curves.easeOutBack.transform(t))!;
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: _kDialogBlurSigma * t,
          sigmaY: _kDialogBlurSigma * t,
        ),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.35 * t),
          child: Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(scale: scale, child: child),
          ),
        ),
      );
    },
  );
}
