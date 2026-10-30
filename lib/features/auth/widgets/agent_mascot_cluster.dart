import 'package:flutter/material.dart';

import '../../../core/ui/agent_identity.dart';
import '../../../core/ui/avatars/avatar_palette.dart';

/// A friendly cluster of agent blobs for welcome and empty screens.
///
/// Drawn with the same [AgentAvatar] painter the roster uses, so the
/// first thing a new user sees already looks like their future teammates.
/// No bitmap assets; colours are tuned per theme brightness.
class AgentMascotCluster extends StatelessWidget {
  const AgentMascotCluster({super.key, this.height = 168, this.dimmed = false});

  /// Overall height; width follows at a fixed aspect ratio.
  final double height;

  /// Desaturated variant (e.g. every computer offline).
  final bool dimmed;

  // (hue, shape, x, y, size) in a 1.6 x 1.0 unit box; the hero blob sits
  // in the middle with four smaller teammates around it.
  static const _blobs = <(double, AgentShape, double, double, double)>[
    (212, AgentShape.cloud, 0.62, 0.22, 0.56),
    (150, AgentShape.circle, 0.10, 0.10, 0.30),
    (28, AgentShape.flower, 1.24, 0.02, 0.32),
    (330, AgentShape.drop, 0.24, 0.66, 0.26),
    (268, AgentShape.squircle, 1.30, 0.58, 0.28),
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final width = height * 1.6;
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            for (final (i, (hue, shape, x, y, size)) in _blobs.indexed)
              Positioned(
                left: x * height,
                top: y * height,
                child: AgentAvatar(
                  identity: _identity('mascot-$i', hue, shape, brightness),
                  size: size * height,
                  showProviderBadge: false,
                  dimmed: dimmed,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static AgentIdentity _identity(
    String seed,
    double hue,
    AgentShape shape,
    Brightness brightness,
  ) {
    final color = agentAccentForHue(hue, brightness);
    return AgentIdentity(
      seed: seed,
      color: color,
      onColor: avatarForegroundColor(color),
      ink: avatarInkOnSurfaceForHue(hue, brightness),
      tint: color.withValues(alpha: 0.12),
      shape: shape,
      brightness: brightness,
    );
  }
}
