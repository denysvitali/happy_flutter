import 'package:flutter/material.dart';

/// Deterministic identity hue for a workspace folder key.
///
/// With dozens of workspaces the pulse list becomes a wall of identical
/// grey folders. A stable per-workspace hue — applied to the folder tile
/// and echoed as a micro-marker on focus-queue rows — lets recognition do
/// what reading cannot: after a day of use, "the purple ones are
/// happy_flutter" is pre-attentive.
///
/// The mapping is pure: same key, same hue on every launch, in light and
/// dark mode. FNV-1a spreads arbitrary keys evenly across the wheel, so
/// no extra scrambling is needed.
Color workspaceIdentityColor(BuildContext context, String key) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  // FNV-1a 32-bit — stable across runs, cheap, well distributed.
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  final hue = (hash % 3600) / 10.0;
  // Saturation/lightness tuned so the color reads as an accent on both
  // surface containers without ever competing with lane semantics
  // (blocked amber / error red / primary unread).
  return HSLColor.fromAHSL(
    1,
    hue,
    dark ? 0.52 : 0.60,
    dark ? 0.74 : 0.42,
  ).toColor();
}

/// Soft container tint for [color] that keeps its icon legible.
Color workspaceIdentityContainer(BuildContext context, Color color) {
  final cs = Theme.of(context).colorScheme;
  return Color.alphaBlend(
    color.withValues(alpha: 0.16),
    cs.surfaceContainerLow,
  );
}
