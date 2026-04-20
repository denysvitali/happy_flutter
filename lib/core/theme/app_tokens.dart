/// Design tokens for the Happy Flutter app.
///
/// All spacing, radius, duration, curve, elevation, and shadow
/// constants are centralized here as static const values so that
/// every component references a single source of truth.
library;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

// ─── Spacing ─────────────────────────────────────────────────────────────────

/// Spacing scale (logical pixels).
///
/// Usage: `SizedBox(height: AppSpacing.md)`
abstract final class AppSpacing {
  /// 2 px – micro gap, hairline nudge.
  static const double xxs = 2;

  /// 3 px – tiny gap, inline spacing.
  static const double xxxs = 3;

  /// 4 px – hairline gap, icon-to-label nudge.
  static const double xs = 4;

  /// 5 px – inline compact spacing.
  static const double xxs2 = 5;

  /// 6 px – between xs and sm.
  static const double xsm = 6;

  /// 8 px – tight internal padding.
  static const double sm = 8;

  /// 10 px – compact element padding.
  static const double smd = 10;

  /// 12 px – compact section padding.
  static const double md = 12;

  /// 16 px – standard content padding.
  static const double lg = 16;

  /// 20 px – comfortable section spacing.
  static const double xl = 20;

  /// 24 px – generous section gap.
  static const double xxl = 24;

  /// 32 px – large layout spacing.
  static const double xxxl = 32;
}

// ─── Border radius ───────────────────────────────────────────────────────────

/// Corner-radius scale.
///
/// Usage: `BorderRadius.circular(AppRadius.md)`
abstract final class AppRadius {
  /// 1 px – barely visible rounding, hairline corners.
  static const double hairline = 1;

  /// 2 px – minimal rounding, hairline corners.
  static const double xxs = 2;

  /// 3 px – tiny rounding, inline elements.
  static const double xxxs = 3;

  /// 4 px – subtle rounding (chips, tags).
  static const double xs = 4;

  /// 5 px – inline compact rounding.
  static const double xxs2 = 5;

  /// 6 px – grouped message corners, compact elements.
  static const double xsm = 6;

  /// 8 px – small components (badges, small chips).
  static const double sm = 8;

  /// 10 px – input fields, search boxes.
  static const double smd = 10;

  /// 12 px – medium components (inputs, list tiles).
  static const double md = 12;

  /// 16 px – cards and larger containers.
  static const double lg = 16;

  /// 20 px – bottom sheets, dialogs, message bubbles.
  static const double xl = 20;

  /// 24 px – large containers, modals.
  static const double xxl = 24;

  /// 100 px – fully-pill / stadium shape.
  static const double pill = 100;
}

// ─── Font sizes ──────────────────────────────────────────────────────────────

/// Raw font size tokens for cases where [AppTypography] text styles
/// are too opinionated (e.g. code blocks, tool views, badges).
///
/// Prefer [AppTypography] for body/label/title text. Use [AppFontSize]
/// only when you need a bare size without the full TextStyle.
abstract final class AppFontSize {
  /// 10 px – micro labels, status badges.
  static const double xxs = 10;

  /// 11 px – compact labels, timestamps.
  static const double xs = 11;

  /// 12 px – body small, secondary text.
  static const double sm = 12;

  /// 13 px – code blocks, tool output.
  static const double md = 13;

  /// 14 px – body medium, primary text.
  static const double base = 14;

  /// 16 px – body large, titles.
  static const double lg = 16;
}

// ─── Durations ───────────────────────────────────────────────────────────────

/// Animation duration constants.
///
/// Usage: `AnimationController(duration: AppDuration.normal)`
abstract final class AppDuration {
  /// 150 ms – micro-interactions (ripple, hover).
  static const Duration fast = Duration(milliseconds: 150);

  /// 250 ms – standard transitions.
  static const Duration normal = Duration(milliseconds: 250);

  /// 350 ms – richer transitions (page slide, sheet).
  static const Duration slow = Duration(milliseconds: 350);

  /// 500 ms – elaborate animations (onboarding).
  static const Duration slower = Duration(milliseconds: 500);
}

// ─── Line height ─────────────────────────────────────────────────────────────

/// Text line-height multipliers.
abstract final class AppLineHeight {
  /// 1.0 – condensed, headlines.
  static const double tight = 1.0;

  /// 1.4 – default body text.
  static const double normal = 1.4;

  /// 1.5 – comfortable reading.
  static const double relaxed = 1.5;

  /// 1.6 – loose, accessibility-friendly.
  static const double loose = 1.6;
}

// ─── Touch targets ───────────────────────────────────────────────────────────

/// Minimum interactive touch target sizes (WCAG 2.5.5 guidance).
abstract final class AppTouchTarget {
  /// 44 px – minimum tap target per Apple HIG / WCAG.
  static const double min = 44;

  /// 48 px – comfortable tap target per Material guidelines.
  static const double comfortable = 48;
}

// ─── Curves ──────────────────────────────────────────────────────────────────

/// Canonical animation curves.
///
/// Usage: `CurvedAnimation(curve: AppCurve.enter)`
abstract final class AppCurve {
  /// Symmetric ease-in-out – general purpose.
  static const Curve standard = Curves.easeInOut;

  /// Ease-out – entering elements decelerate into position.
  static const Curve enter = Curves.easeOut;

  /// Ease-in – exiting elements accelerate out of view.
  static const Curve exit = Curves.easeIn;

  /// Elastic overshoot – playful spring effect.
  static const Curve spring = Curves.elasticOut;
}

// ─── Elevation ───────────────────────────────────────────────────────────────

/// Material elevation levels.
///
/// Usage: `Card(elevation: AppElevation.low)`
abstract final class AppElevation {
  /// 0 – flat / no shadow.
  static const double none = 0;

  /// 1 – subtle lift (app bar scroll).
  static const double low = 1;

  /// 4 – card / sheet resting state.
  static const double mid = 4;

  /// 8 – floating action, modals.
  static const double high = 8;
}

// ─── Shadows ─────────────────────────────────────────────────────────────────

/// Pre-composed [BoxShadow] presets.
///
/// Apply via the `boxShadow` property of a [BoxDecoration]:
/// ```dart
/// BoxDecoration(boxShadow: AppShadow.card)
/// ```
abstract final class AppShadow {
  /// Gentle shadow for cards and list items.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A000000), // 4 % black
      blurRadius: 8,
      spreadRadius: 0,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x06000000), // 2 % black
      blurRadius: 2,
      spreadRadius: 0,
      offset: Offset(0, 1),
    ),
  ];

  /// Medium shadow for floating panels, menus, and drawers.
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x14000000), // 8 % black
      blurRadius: 16,
      spreadRadius: -2,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x0A000000), // 4 % black
      blurRadius: 6,
      spreadRadius: 0,
      offset: Offset(0, 2),
    ),
  ];

  /// Strong shadow for modal dialogs and bottom sheets.
  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x1F000000), // 12 % black
      blurRadius: 32,
      spreadRadius: -4,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x14000000), // 8 % black
      blurRadius: 12,
      spreadRadius: -2,
      offset: Offset(0, 4),
    ),
  ];
}

// ─── Borders ────────────────────────────────────────────────────────────────

/// Border width constants.
///
/// Usage: `Border.all(width: AppBorder.thin)`
abstract final class AppBorder {
  /// 0.5 px – hairline border.
  static const double hairline = 0.5;

  /// 1.0 px – standard border.
  static const double thin = 1.0;

  /// 2.0 px – emphasis border (focus, active).
  static const double thick = 2.0;
}

// ─── Responsive breakpoints ─────────────────────────────────────────────────

/// Screen width breakpoints for adaptive layouts.
///
/// Usage: `MediaQuery.sizeOf(context).width > AppBreakpoint.tablet`
abstract final class AppBreakpoint {
  /// 600 px – phone → tablet transition.
  static const double tablet = 600;

  /// 960 px – tablet → desktop transition.
  static const double desktop = 960;

  /// 250 px – minimum sidebar width.
  static const double sidebarMin = 250;

  /// 360 px – maximum sidebar width.
  static const double sidebarMax = 360;
}

// ─── Spring physics ────────────────────────────────────────────────────────

/// Pre-tuned spring physics configurations.
///
/// Each preset is a [SpringDescription] ready for use with
/// [SpringSimulation] or [AnimationController] via [SpringDescription]:
/// ```dart
/// controller.animateWith(AppSpring.standard);
/// ```
///
/// Tuned for feel rather than physics accuracy — values produce
/// the desired motion character (snappy, bouncy, gentle) when used
/// with Flutter's [SpringSimulation].
abstract final class AppSpring {
  /// Snappy spring — quick response, minimal overshoot.
  ///
  /// Use for: toggles, checkboxes, small chip animations.
  /// Feel: immediate, crisp snap into place.
  static const SpringDescription snappy = SpringDescription(
    mass: 1.0,
    stiffness: 500.0,
    damping: 26.0,
  );

  /// Standard spring — balanced response with light overshoot.
  ///
  /// Use for: cards, list item expand/collapse, toolbar reveals.
  /// Feel: responsive with a satisfying settle.
  static const SpringDescription standard = SpringDescription(
    mass: 1.0,
    stiffness: 300.0,
    damping: 22.0,
  );

  /// Gentle spring — slower response, smooth settle.
  ///
  /// Use for: bottom sheets, panels, modal-scale elements.
  /// Feel: slow and controlled, no bounce.
  static const SpringDescription gentle = SpringDescription(
    mass: 1.0,
    stiffness: 180.0,
    damping: 20.0,
  );

  /// Bouncy spring — pronounced overshoot and rebound.
  ///
  /// Use for: FAB appearance, toast entry, playful confirmations.
  /// Feel: energetic, fun, attention-grabbing.
  static const SpringDescription bouncy = SpringDescription(
    mass: 1.0,
    stiffness: 400.0,
    damping: 14.0,
  );

  /// Critically-damped spring — fastest settle with zero overshoot.
  ///
  /// Use for: scroll-linked animations, physics-driven motion.
  /// Feel: as fast as possible without overshooting.
  static const SpringDescription criticallyDamped = SpringDescription(
    mass: 1.0,
    stiffness: 300.0,
    damping: 30.0,
  );
}

// ─── Screen padding ───────────────────────────────────────────────────────

/// Standard screen padding presets.
///
/// Usage: `padding: AppScreenPadding.standard`
abstract final class AppScreenPadding {
  /// 16 px all sides – standard content padding.
  static const EdgeInsets standard = EdgeInsets.all(AppSpacing.lg);

  /// 12 px all sides – compact content padding.
  static const EdgeInsets compact = EdgeInsets.all(AppSpacing.md);

  /// 20 px horizontal, 16 px vertical – settings screens.
  static const EdgeInsets settings = EdgeInsets.symmetric(
    horizontal: AppSpacing.xl,
    vertical: AppSpacing.lg,
  );

  /// 16 px horizontal, 12 px vertical – list items.
  static const EdgeInsets listItem = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );
}
