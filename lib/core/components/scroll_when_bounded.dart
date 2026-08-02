import 'package:flutter/material.dart';

/// Makes [child] scrollable, but only when the incoming constraints give it
/// a bounded height.
///
/// Centred placeholders (empty states, error states) overflow at large
/// system text scales when they are handed a fixed viewport. Wrapping them
/// in a [SingleChildScrollView] fixes that — but the same widgets are also
/// dropped straight into `ListView` children and `Column`s inside other
/// scroll views, where an unconditional viewport would throw
/// "Vertical viewport was given unbounded height" and nest two scrollables.
///
/// This helper keeps both cases correct: it scrolls where scrolling is
/// possible and stays inert everywhere else. It never clamps or caps the
/// user's `textScaler` — the content grows and the viewport scrolls.
/// The `minHeight` + [Center] pair keeps the content vertically centred while
/// it fits — identical pixels to the plain centred layout — and only starts
/// scrolling once the enlarged text is taller than the viewport.
Widget scrollWhenBounded(Widget child) {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (!constraints.hasBoundedHeight) return child;
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      );
    },
  );
}
