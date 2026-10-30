import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/session.dart';
import '../theme/app_colors.dart';
import 'avatars/avatar_palette.dart';

/// Friendly, deterministic identity for an agent session.
///
/// Every session gets one accent [color] (from the shared
/// [kAvatarHues] palette, so it matches every other avatar surface in
/// the app) and one blob [shape]. The roster, the chat header, and any
/// other surface that wants "this is the same teammate" should derive
/// colour from here instead of from the provider.
///
/// Colour carries identity; the provider (Claude, Codex, ...) is a small
/// badge on the avatar, never the main colour.
@immutable
class AgentIdentity {
  const AgentIdentity({
    required this.seed,
    required this.color,
    required this.onColor,
    required this.ink,
    required this.tint,
    required this.shape,
    required this.brightness,
    this.flavor,
  });

  /// Stable seed the identity was derived from (the session id).
  final String seed;

  /// Solid accent fill. Vivid, but tuned per [brightness] so it keeps at
  /// least 3:1 graphical contrast against the theme surface (see
  /// [agentAccentForHue]).
  final Color color;

  /// Ink for marks drawn on top of [color] (avatar eyes, initials, a
  /// filled button label).
  final Color onColor;

  /// Identity-tinted text colour for use on the normal theme surface
  /// (e.g. a name or a "working" label). Meets 4.5:1 on the surface.
  final Color ink;

  /// Very soft wash of the accent for selected rows / container fills.
  final Color tint;

  /// Blob silhouette used by [AgentAvatar].
  final AgentShape shape;

  /// Brightness the colours were tuned for.
  final Brightness brightness;

  /// Provider flavor (`claude`, `codex`, `grok`, ...), if known.
  final String? flavor;

  /// Convenience builder for the avatar widget.
  Widget avatar({
    double size = 40,
    bool showProviderBadge = true,
    bool dimmed = false,
    Key? key,
  }) => AgentAvatar(
    identity: this,
    size: size,
    showProviderBadge: showProviderBadge,
    dimmed: dimmed,
    key: key,
  );
}

/// Blob silhouettes, picked by hash so neighbouring sessions differ in
/// shape as well as colour (useful for colour-blind users).
enum AgentShape { circle, drop, cloud, squircle, flower, pebble }

/// Identity for [session] in the given theme [brightness].
AgentIdentity agentIdentityFor(Session session, Brightness brightness) =>
    agentIdentityForSeed(
      session.id,
      brightness: brightness,
      flavor: session.metadata?.flavor,
    );

/// Identity for an arbitrary [seed] (use the session id for sessions).
AgentIdentity agentIdentityForSeed(
  String seed, {
  required Brightness brightness,
  String? flavor,
}) {
  final hue = avatarHue(seed);
  final color = agentAccentForHue(hue, brightness);
  final shapeIndex = avatarHashVariant(seed, 7) % AgentShape.values.length;
  return AgentIdentity(
    seed: seed,
    color: color,
    onColor: avatarForegroundColor(color),
    ink: avatarInkOnSurfaceForHue(hue, brightness),
    tint: color.withValues(
      alpha: brightness == Brightness.dark
          ? AppOpacity.soft
          : AppOpacity.subtle,
    ),
    shape: AgentShape.values[shapeIndex],
    brightness: brightness,
    flavor: flavor,
  );
}

/// The vivid accent for [hue], tuned per [brightness].
///
/// Dark themes lift every hue so the blob glows on the dark surface. Light
/// themes start vivid and step the lightness down until the fill reaches
/// 3:1 against white (WCAG non-text contrast), so greens, cyans and
/// yellows keep their silhouette on a light list.
Color agentAccentForHue(double hue, Brightness brightness) {
  final yellowish = hue >= 35 && hue <= 110;
  if (brightness == Brightness.dark) {
    return HSLColor.fromAHSL(1, hue, 0.66, yellowish ? 0.52 : 0.60).toColor();
  }
  var lightness = yellowish ? 0.40 : 0.50;
  var color = HSLColor.fromAHSL(1, hue, 0.72, lightness).toColor();
  while (avatarContrast(color, Colors.white) < _lightFillContrast &&
      lightness > 0.2) {
    lightness -= 0.02;
    color = HSLColor.fromAHSL(1, hue, 0.72, lightness).toColor();
  }
  return color;
}

/// Minimum fill contrast against white in light themes (a little above
/// 3:1 so tinted light surfaces still clear it).
const double _lightFillContrast = 3.2;

/// Friendly blob avatar: solid identity colour, two small eyes, and an
/// optional provider badge in the corner.
class AgentAvatar extends StatelessWidget {
  const AgentAvatar({
    required this.identity,
    super.key,
    this.size = 40,
    this.showProviderBadge = true,
    this.dimmed = false,
    this.providerBadge,
  });

  final AgentIdentity identity;
  final double size;
  final bool showProviderBadge;

  /// Desaturates the blob (archived / offline teammates).
  final bool dimmed;

  /// Builder for the provider mark inside the badge. When null the badge
  /// is skipped (lib/core cannot depend on feature widgets); session
  /// surfaces pass `HarnessLogo` through `SessionAvatar`.
  final Widget Function(String flavor, double size)? providerBadge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    var fill = identity.color;
    var eyes = identity.onColor;
    if (dimmed) {
      fill = Color.lerp(fill, cs.surfaceContainerHighest, 0.6) ?? fill;
      eyes = avatarForegroundColor(fill);
    }
    final blob = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: _BlobPainter(
          shape: identity.shape,
          fill: fill,
          eyes: eyes,
          tilt: (avatarHashVariant(identity.seed, 13) % 3) - 1,
        ),
      ),
    );
    final flavor = identity.flavor;
    final badgeBuilder = providerBadge;
    if (!showProviderBadge || flavor == null || badgeBuilder == null) {
      return SizedBox.square(dimension: size, child: blob);
    }
    final badge = (size * 0.44).roundToDouble();
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          blob,
          Positioned(
            right: -size * 0.06,
            bottom: -size * 0.06,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: cs.surface,
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 1.5),
              ),
              alignment: Alignment.center,
              child: badgeBuilder(flavor, badge * 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({
    required this.shape,
    required this.fill,
    required this.eyes,
    required this.tilt,
  });

  final AgentShape shape;
  final Color fill;
  final Color eyes;

  /// -1, 0 or 1: small personality tilt of the eyes.
  final int tilt;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()
      ..color = fill
      ..isAntiAlias = true;
    canvas.drawPath(_shapePath(shape, s), paint);

    // Two short rounded "eyes", centred in [agentFaceRect] so every
    // silhouette fully contains the face and corner badges never touch it.
    final eyePaint = Paint()
      ..color = eyes
      ..strokeWidth = s * _eyeStroke
      ..strokeCap = StrokeCap.round;
    final cy = s * 0.46;
    final len = s * 0.10;
    final lean = s * 0.025 * (tilt == 0 ? 1 : tilt);
    for (final cx in [s * 0.41, s * 0.59]) {
      canvas.drawLine(
        Offset(cx - lean, cy + len / 2),
        Offset(cx + lean, cy - len / 2),
        eyePaint,
      );
    }
  }

  static Path _shapePath(AgentShape shape, double s) =>
      agentShapePath(shape, s);

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.shape != shape ||
      old.fill != fill ||
      old.eyes != eyes ||
      old.tilt != tilt;
}

/// Eye stroke width as a fraction of the avatar size.
const double _eyeStroke = 0.085;

/// Bounds of the avatar's face (both eyes including their round caps) for
/// an avatar of [size]. Every [AgentShape] contains this rect, and the
/// corner badges (provider bottom-right, state dot top-right) stay outside
/// it.
Rect agentFaceRect(double size) =>
    Rect.fromLTRB(size * 0.34, size * 0.36, size * 0.66, size * 0.56);

/// Silhouette of [shape] for an avatar of [size].
Path agentShapePath(AgentShape shape, double size) {
  final s = size;
  final c = Offset(s / 2, s / 2);
  switch (shape) {
    case AgentShape.circle:
      return Path()..addOval(Rect.fromCircle(center: c, radius: s * 0.46));
    case AgentShape.squircle:
      return Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: s * 0.86, height: s * 0.86),
          Radius.circular(s * 0.28),
        ),
      );
    case AgentShape.drop:
      // Teardrop: round everywhere except a soft point at the top-left.
      return Path()..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromCenter(center: c, width: s * 0.86, height: s * 0.86),
          topLeft: Radius.circular(s * 0.10),
          topRight: Radius.circular(s * 0.43),
          bottomLeft: Radius.circular(s * 0.43),
          bottomRight: Radius.circular(s * 0.43),
        ),
      );
    case AgentShape.cloud:
      return Path()
        ..addOval(
          Rect.fromCircle(center: Offset(s * 0.32, s * 0.56), radius: s * 0.27),
        )
        ..addOval(
          Rect.fromCircle(center: Offset(s * 0.66, s * 0.58), radius: s * 0.29),
        )
        ..addOval(
          Rect.fromCircle(center: Offset(s * 0.50, s * 0.36), radius: s * 0.28),
        )
        ..fillType = PathFillType.nonZero;
    case AgentShape.flower:
      final path = Path()
        ..addOval(Rect.fromCircle(center: c, radius: s * 0.28));
      for (var i = 0; i < 4; i++) {
        final a = math.pi / 4 + i * math.pi / 2;
        path.addOval(
          Rect.fromCircle(
            center: c + Offset(math.cos(a), math.sin(a)) * (s * 0.2),
            radius: s * 0.24,
          ),
        );
      }
      return path;
    case AgentShape.pebble:
      return Path()..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromCenter(center: c, width: s * 0.92, height: s * 0.74),
          topLeft: Radius.circular(s * 0.42),
          topRight: Radius.circular(s * 0.30),
          bottomLeft: Radius.circular(s * 0.30),
          bottomRight: Radius.circular(s * 0.42),
        ),
      );
  }
}
