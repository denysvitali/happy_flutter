import 'package:flutter/material.dart';

/// Identity palette + hashing shared by every generated avatar style.
///
/// Session ids are long and differ only in their tail characters, so the
/// additive / `*31` folds the avatar styles used before produced hues one
/// or two degrees apart — every session in a list rendered the same
/// colour. [avatarHash] mixes every byte (FNV-1a) so neighbouring ids
/// land on unrelated palette entries, and [avatarBackgroundColor] maps
/// the hash onto a fixed set of hues tuned per [Brightness] so the same
/// session keeps a recognisable colour in light and dark themes.

/// 32-bit FNV-1a hash of [id]. Stable across platforms (kept inside the
/// 32-bit range so the VM and JavaScript agree).
int avatarHash(String id) {
  var hash = 0x811c9dc5;
  for (final unit in id.codeUnits) {
    hash ^= unit & 0xff;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// Derives a secondary hash from [id] so a style can vary two properties
/// independently without the two tracking each other.
int avatarHashVariant(String id, int salt) {
  final mixed = (avatarHash(id) ^ (salt * 0x9e3779b1)) & 0xffffffff;
  return (mixed ^ (mixed >> 15)) & 0xffffffff;
}

/// Twelve well-separated identity hues. Ordered so that consecutive
/// palette slots are also far apart on the colour wheel — adjacent hash
/// values therefore look different, not merely distinct.
const List<double> kAvatarHues = <double>[
  8, // red
  200, // cyan-blue
  45, // amber
  268, // violet
  145, // green
  330, // pink
  95, // lime
  225, // indigo
  25, // orange
  175, // teal
  300, // magenta
  60, // yellow-green
];

/// Palette slot index for [id].
int avatarPaletteIndex(String id) => avatarHash(id) % kAvatarHues.length;

/// Hue assigned to [id].
double avatarHue(String id) => kAvatarHues[avatarPaletteIndex(id)];

/// Solid identity colour for [id], tuned for [brightness].
///
/// Lightness is capped on both sides so initials rendered with
/// [avatarForegroundColor] keep a comfortable contrast ratio in both
/// themes.
Color avatarBackgroundColor(String id, Brightness brightness) =>
    avatarBackgroundColorForHue(avatarHue(id), brightness);

/// [avatarBackgroundColor] for an explicit [hue].
Color avatarBackgroundColorForHue(double hue, Brightness brightness) {
  return brightness == Brightness.dark
      ? HSLColor.fromAHSL(1, hue, 0.46, 0.38).toColor()
      : HSLColor.fromAHSL(1, hue, 0.58, 0.42).toColor();
}

/// Companion colour for gradients and secondary strokes.
Color avatarAccentColor(String id, Brightness brightness) =>
    avatarAccentColorForHue(avatarHue(id), brightness);

/// [avatarAccentColor] for an explicit [hue].
Color avatarAccentColorForHue(double hue, Brightness brightness) {
  final accentHue = (hue + 38) % 360;
  return brightness == Brightness.dark
      ? HSLColor.fromAHSL(1, accentHue, 0.50, 0.30).toColor()
      : HSLColor.fromAHSL(1, accentHue, 0.62, 0.52).toColor();
}

/// Identity-tinted ink for text drawn on a theme surface (rather than on
/// the generated fill). Lightened in dark themes so it keeps contrast
/// against a dark card.
Color avatarInkOnSurface(String id, Brightness brightness) =>
    avatarInkOnSurfaceForHue(avatarHue(id), brightness);

/// [avatarInkOnSurface] for an explicit [hue].
Color avatarInkOnSurfaceForHue(double hue, Brightness brightness) {
  return brightness == Brightness.dark
      ? HSLColor.fromAHSL(1, hue, 0.62, 0.76).toColor()
      : HSLColor.fromAHSL(1, hue, 0.72, 0.26).toColor();
}

/// Readable ink for text drawn on top of [background].
///
/// The background is generated, not part of the colour scheme, so the
/// foreground has to be derived from it. Picks whichever of black/white
/// has the higher WCAG contrast ratio rather than using Material's fixed
/// 0.15 luminance threshold, which leaves mid-luminance fills just under
/// the 4.5:1 bar.
Color avatarForegroundColor(Color background) {
  final luminance = background.computeLuminance();
  final onWhite = 1.05 / (luminance + 0.05);
  final onBlack = (luminance + 0.05) / 0.05;
  return onWhite >= onBlack ? Colors.white : Colors.black;
}

/// WCAG 2.1 contrast ratio between [a] and [b].
double avatarContrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// How much of the scrim is mixed into a gradient fill that carries
/// initials. Enough to clear 4.5:1 at the worst point of every palette
/// hue in both themes, small enough to keep the identity hue readable.
const double kAvatarGradientScrimAlpha = 0.28;

/// A gradient fill plus the ink that stays readable across all of it.
///
/// A two-stop gradient has no single background colour, so picking the
/// ink against the start stop alone leaves the initials as low as
/// 1.67:1 over the far end. [avatarGradientInk] instead evaluates both
/// stops and their midpoint, tries white-ink-over-a-dark-scrim and
/// black-ink-over-a-light-scrim, and keeps whichever wins the *worst*
/// point of the sweep. The scrim is folded into the returned stops, so
/// callers just paint [start] → [end] and draw with [foreground].
class AvatarGradientInk {
  const AvatarGradientInk({
    required this.start,
    required this.end,
    required this.foreground,
  });

  final Color start;
  final Color end;
  final Color foreground;
}

/// Readable gradient + ink for initials drawn on an [id]'s avatar.
AvatarGradientInk avatarGradientInk(String id, Brightness brightness) =>
    avatarGradientInkForHue(avatarHue(id), brightness);

/// [avatarGradientInk] for an explicit [hue].
AvatarGradientInk avatarGradientInkForHue(double hue, Brightness brightness) {
  final start = avatarBackgroundColorForHue(hue, brightness);
  final end = avatarAccentColorForHue(hue, brightness);

  AvatarGradientInk candidate(Color foreground, Color scrim) {
    Color scrimmed(Color base) => Color.alphaBlend(
      scrim.withValues(alpha: kAvatarGradientScrimAlpha),
      base,
    );
    return AvatarGradientInk(
      start: scrimmed(start),
      end: scrimmed(end),
      foreground: foreground,
    );
  }

  final light = candidate(Colors.white, Colors.black);
  final dark = candidate(Colors.black, Colors.white);
  return _worstContrast(light) >= _worstContrast(dark) ? light : dark;
}

/// Contrast at the least favourable point of [ink]'s sweep.
double _worstContrast(AvatarGradientInk ink) {
  final mid = Color.lerp(ink.start, ink.end, 0.5) ?? ink.start;
  final atStart = avatarContrast(ink.foreground, ink.start);
  final atMid = avatarContrast(ink.foreground, mid);
  final atEnd = avatarContrast(ink.foreground, ink.end);
  var worst = atStart;
  if (atMid < worst) worst = atMid;
  if (atEnd < worst) worst = atEnd;
  return worst;
}
