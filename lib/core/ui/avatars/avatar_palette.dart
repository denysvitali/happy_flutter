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
Color avatarBackgroundColor(String id, Brightness brightness) {
  final hue = avatarHue(id);
  return brightness == Brightness.dark
      ? HSLColor.fromAHSL(1, hue, 0.46, 0.38).toColor()
      : HSLColor.fromAHSL(1, hue, 0.58, 0.42).toColor();
}

/// Companion colour for gradients and secondary strokes.
Color avatarAccentColor(String id, Brightness brightness) {
  final hue = (avatarHue(id) + 38) % 360;
  return brightness == Brightness.dark
      ? HSLColor.fromAHSL(1, hue, 0.50, 0.30).toColor()
      : HSLColor.fromAHSL(1, hue, 0.62, 0.52).toColor();
}

/// Identity-tinted ink for text drawn on a theme surface (rather than on
/// the generated fill). Lightened in dark themes so it keeps contrast
/// against a dark card.
Color avatarInkOnSurface(String id, Brightness brightness) {
  final hue = avatarHue(id);
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
