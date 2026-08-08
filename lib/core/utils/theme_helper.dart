import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/providers/settings_notifier.dart';
import 'package:happy_flutter/core/theme/app_color_scheme.dart';
import 'package:happy_flutter/core/theme/app_terminal_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/theme/code_viewer_theme.dart';
import 'package:happy_flutter/core/theme/diff_theme.dart';
import 'package:happy_flutter/core/theme/syntax_theme.dart';

/// Theme mode enumeration matching React Native's themePreference
enum AppThemeMode {
  adaptive('adaptive', 'Follow system'),
  light('light', 'Always light'),
  dark('dark', 'Always dark');

  const AppThemeMode(this.value, this.description);

  final String value;
  final String description;

  /// Parse a string value to AppThemeMode
  static AppThemeMode fromString(String value) {
    return switch (value) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => AppThemeMode.adaptive,
    };
  }
}

/// Extension on BuildContext for theme-aware operations
extension ThemeContextExtension on BuildContext {
  /// Get the current app theme mode from settings provider
  AppThemeMode get appThemeMode {
    final container = ProviderScope.containerOf(this);
    final themeModeString = container.read(settingsNotifierProvider).themeMode;
    return AppThemeMode.fromString(themeModeString);
  }

  /// Check if the app should use dark theme
  bool get isDarkMode {
    final mode = appThemeMode;
    return switch (mode) {
      AppThemeMode.dark => true,
      AppThemeMode.light => false,
      AppThemeMode.adaptive =>
        MediaQuery.platformBrightnessOf(this) == Brightness.dark,
    };
  }

  /// Get the effective brightness for system UI
  Brightness get effectiveBrightness {
    final mode = appThemeMode;
    return switch (mode) {
      AppThemeMode.dark => Brightness.dark,
      AppThemeMode.light => Brightness.light,
      AppThemeMode.adaptive => MediaQuery.platformBrightnessOf(this),
    };
  }
}

/// Extension on AppThemeMode for applying system chrome styles
extension ThemeModeExtension on AppThemeMode {
  /// Apply SystemChrome settings for this theme mode
  void applySystemChrome() {
    final brightness = switch (this) {
      AppThemeMode.dark => Brightness.dark,
      AppThemeMode.light => Brightness.light,
      AppThemeMode.adaptive =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: brightness,
        systemNavigationBarColor: brightness == Brightness.dark
            ? _kDarkBackground
            : _kLightBackground,
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }

  /// Get the appropriate overlay style for a given context
  SystemUiOverlayStyle getOverlayStyle(BuildContext context) {
    final brightness = switch (this) {
      AppThemeMode.dark => Brightness.dark,
      AppThemeMode.light => Brightness.light,
      AppThemeMode.adaptive => MediaQuery.platformBrightnessOf(context),
    };

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
      statusBarBrightness: brightness,
      systemNavigationBarColor: brightness == Brightness.dark
          ? Colors.black
          : Colors.white,
      systemNavigationBarIconBrightness: brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
    );
  }

  /// Apply SystemChrome with explicit context
  void applySystemChromeWithContext(BuildContext context) {
    final overlayStyle = getOverlayStyle(context);
    SystemChrome.setSystemUIOverlayStyle(overlayStyle);
  }
}

// ─── Colour constants ────────────────────────────────────────────────────────

/// Primary brand blue, matching the React Native app.
const _kSeedColor = Color(0xFF2563EB);

// Light-theme surface shades
const _kLightBackground = Color(0xFFF8FAFF);
const _kLightSurface = Color(0xFFFFFFFF);
const _kLightSurfaceVariant = Color(0xFFEEF2FF);

// Dark-theme surface shades
const _kDarkBackground = Color(0xFF0F1117);
const _kDarkSurface = Color(0xFF1A1D27);
const _kDarkSurfaceVariant = Color(0xFF252836);

// ── Text hierarchy (mirrors AppColorScheme text fields) ───────────────────────
// Keep in sync with lib/core/theme/app_color_scheme.dart factories.

// Light text
const _kLightTextPrimary = Color(0xFF0F172A);
const _kLightTextSecondary = Color(0xFF1E293B);
const _kLightTextMuted = Color(0xFF475569);
const _kLightTextSubtle = Color(0xFF64748B);

// Dark text
const _kDarkTextSecondary = Color(0xFFE2E8F0);
const _kDarkTextMuted = Color(0xFFCBD5E1);
const _kDarkTextSubtle = Color(0xFF94A3B8);

// ── Interactive ───────────────────────────────────────────────────────────────
/// Error / danger border color (mirrors AppColorScheme.errorBorder).
const _kErrorBorder = Color(0xFFEF4444);

/// Disabled filled-button fill (mirrors AppColorScheme.disabledFill).
const _kDisabledFill = Color(0xFF94A3B8);

// ── Overlay ───────────────────────────────────────────────────────────────────
// Snack-bar backgrounds (mirror AppColorScheme.snackBarBackground).
const _kSnackBarDark = Color(0xFF334155);
const _kSnackBarLight = Color(0xFF1E293B);

// ─── Text themes ─────────────────────────────────────────────────────────────

const _kInterFontFamily = 'Inter';
const _kInterRegularFontFamily = 'Inter_regular';
const _kInterMediumFontFamily = 'Inter_500';
const _kInterSemiBoldFontFamily = 'Inter_600';
const _kInterBoldFontFamily = 'Inter_700';

String _interFamilyFor(FontWeight? fontWeight) {
  return switch (fontWeight) {
    FontWeight.w500 => _kInterMediumFontFamily,
    FontWeight.w600 => _kInterSemiBoldFontFamily,
    FontWeight.w700 => _kInterBoldFontFamily,
    _ => _kInterRegularFontFamily,
  };
}

TextStyle _inter({
  double? fontSize,
  FontWeight? fontWeight,
  double? letterSpacing,
  Color? color,
}) {
  return TextStyle(
    fontFamily: _interFamilyFor(fontWeight),
    fontFamilyFallback: const [_kInterFontFamily],
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    color: color,
  );
}

/// Body / UI text: Inter
TextTheme _buildTextTheme({required bool dark}) {
  final base = dark ? ThemeData.dark() : ThemeData.light();
  return base.textTheme
      .apply(fontFamily: _kInterFontFamily)
      .copyWith(
        // Titles — Inter
        displayLarge: _inter(
          fontSize: 57,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.5,
          color: dark ? Colors.white : _kLightTextPrimary,
        ),
        displayMedium: _inter(
          fontSize: 45,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.25,
          color: dark ? Colors.white : _kLightTextPrimary,
        ),
        displaySmall: _inter(
          fontSize: 36,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.15,
          color: dark ? Colors.white : _kLightTextPrimary,
        ),
        headlineLarge: _inter(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: dark ? Colors.white : _kLightTextPrimary,
        ),
        headlineMedium: _inter(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: dark ? Colors.white : _kLightTextPrimary,
        ),
        headlineSmall: _inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: dark ? Colors.white : _kLightTextPrimary,
        ),
        titleLarge: _inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: dark ? Colors.white : _kLightTextPrimary,
        ),
        titleMedium: _inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: dark ? Colors.white : _kLightTextPrimary,
        ),
        titleSmall: _inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: dark ? _kDarkTextMuted : _kLightTextSecondary,
        ),
        // Body — Inter
        bodyLarge: _inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.15,
          color: dark ? _kDarkTextSecondary : _kLightTextSecondary,
        ),
        bodyMedium: _inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          color: dark ? _kDarkTextSecondary : _kLightTextSecondary,
        ),
        bodySmall: _inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          color: dark ? _kDarkTextSubtle : _kLightTextSubtle,
        ),
        labelLarge: _inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
        labelMedium: _inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        labelSmall: _inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      );
}

// ─── Component themes ─────────────────────────────────────────────────────

AppBarTheme _buildAppBarTheme({required bool dark}) {
  return AppBarTheme(
    elevation: 0,
    scrolledUnderElevation: 1,
    backgroundColor: dark
        ? _kDarkSurface.withAlpha(230)
        : _kLightSurface.withAlpha(230),
    foregroundColor: dark ? Colors.white : _kLightTextPrimary,
    centerTitle: false,
    titleTextStyle: _inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: dark ? Colors.white : _kLightTextPrimary,
    ),
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    ),
  );
}

CardThemeData _buildCardTheme({required bool dark}) {
  // Richer shadow via AppShadow.card preset instead of raw elevation.
  return CardThemeData(
    elevation: AppElevation.none,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(
        color: dark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(12),
      ),
    ),
    color: dark ? _kDarkSurface : _kLightSurface,
    surfaceTintColor: Colors.transparent,
    margin: EdgeInsets.zero,
  );
}

/// Returns the [BoxShadow] list appropriate for a card in the given theme.
///
/// Use this when you need a [BoxDecoration] with the card shadow preset,
/// e.g. in a custom widget that cannot use [Card]:
/// ```dart
/// BoxDecoration(boxShadow: cardBoxShadow(dark: isDark))
/// ```
List<BoxShadow> cardBoxShadow({required bool dark}) {
  if (dark) return const [];
  return AppShadow.card;
}

InputDecorationTheme _buildInputDecorationTheme({required bool dark}) {
  final borderColor = dark
      ? Colors.white.withAlpha(30)
      : Colors.black.withAlpha(20);
  // 2 px primary-color focus ring with a 15 % opacity fill tint.
  const focusColor = _kSeedColor;
  final focusFill = focusColor.withAlpha(38); // ~0.15 opacity
  final radius = BorderRadius.circular(AppRadius.md);

  return InputDecorationTheme(
    filled: true,
    fillColor: dark ? _kDarkSurfaceVariant : _kLightSurfaceVariant,
    contentPadding: EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.lg,
    ),
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: focusColor, width: AppBorder.thick),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: _kErrorBorder),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(
        color: _kErrorBorder,
        width: AppBorder.thick,
      ),
    ),
    hintStyle: _inter(
      fontSize: 14,
      color: dark ? _kDarkTextSubtle : _kLightTextSubtle,
    ),
    // Subtle primary-tinted fill when focused (applied by widget via
    // focusedBorder fill workaround; see focusFill below).
    // Flutter's InputDecorationTheme does not directly support a
    // separate focusedFillColor, so we expose focusFill as a helper
    // colour used by custom form-field wrappers.
    prefixIconColor: WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? focusFill
          : (dark ? _kDarkTextSubtle : _kLightTextSubtle),
    ),
  );
}

ChipThemeData _buildChipTheme({required bool dark}) {
  // 8 px radius, tighter label (11 px), improved horizontal padding.
  return ChipThemeData(
    padding: EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs / 2, // 2 px vertical
    ),
    labelPadding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    labelStyle: _inter(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    side: BorderSide(
      color: dark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(18),
    ),
    backgroundColor: dark ? _kDarkSurfaceVariant : _kLightSurfaceVariant,
  );
}

IconButtonThemeData _buildIconButtonTheme() => const IconButtonThemeData(
  style: ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size.square(AppTouchTarget.min)),
  ),
);

TextButtonThemeData _buildTextButtonTheme() => const TextButtonThemeData(
  style: ButtonStyle(
    minimumSize: WidgetStatePropertyAll(
      Size(AppTouchTarget.min, AppTouchTarget.min),
    ),
  ),
);

ElevatedButtonThemeData _buildElevatedButtonTheme() {
  return ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _kSeedColor,
      foregroundColor: Colors.white,
      elevation: AppElevation.none,
      minimumSize: const Size(AppTouchTarget.min, AppTouchTarget.min),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      textStyle: _inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    ),
  );
}

/// Lighter top-to-base gradient stop for primary filled buttons.
///
/// The gradient runs from [_kFilledButtonTop] (5 % lightened via alpha
/// blend with white) down to [_kSeedColor].
const _kFilledButtonTop = Color(0xFF4B80F0); // ~15 % lighter than seed

FilledButtonThemeData _buildFilledButtonTheme() {
  // FilledButton.styleFrom doesn't support gradients directly.
  // We use a custom ButtonStyle with a WidgetStateProperty for
  // backgroundBuilder so the gradient is applied as a decoration
  // painted behind the label while foreground stays white.
  return FilledButtonThemeData(
    style: ButtonStyle(
      foregroundColor: const WidgetStatePropertyAll(Colors.white),
      // White state-layer at M3 pressed opacity (16 %) over the gradient.
      overlayColor: AppMotion.overlayFor(Colors.white),
      elevation: const WidgetStatePropertyAll(AppElevation.none),
      minimumSize: const WidgetStatePropertyAll(
        Size(AppTouchTarget.min, AppTouchTarget.min),
      ),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        _inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ),
      // Gradient via backgroundBuilder (Flutter ≥ 3.13).
      backgroundBuilder: (context, states, child) {
        final disabled = states.contains(WidgetState.disabled);
        return Ink(
          decoration: BoxDecoration(
            gradient: disabled
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_kFilledButtonTop, _kSeedColor],
                  ),
            color: disabled ? _kDisabledFill : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: child,
        );
      },
    ),
  );
}

OutlinedButtonThemeData _buildOutlinedButtonTheme({required bool dark}) {
  // Ghost style: transparent background with a primary-tinted M3
  // state layer; foreground and border colour are the seed color.
  return OutlinedButtonThemeData(
    style: ButtonStyle(
      foregroundColor: const WidgetStatePropertyAll(_kSeedColor),
      // Background fills with the M3 state-layer colour directly —
      // AppMotion.stateOverlay returns null when idle so the button
      // stays fully transparent at rest.
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => AppMotion.stateOverlay(_kSeedColor, states),
      ),
      // Ripple overlay uses the canonical M3 seed-color state layer.
      overlayColor: AppMotion.overlayFor(_kSeedColor),
      side: WidgetStateProperty.resolveWith((states) {
        final alpha = states.contains(WidgetState.focused) ? 255 : 120;
        return BorderSide(
          color: _kSeedColor.withAlpha(alpha),
          width: states.contains(WidgetState.focused)
              ? AppBorder.thick
              : AppBorder.thin,
        );
      }),
      elevation: const WidgetStatePropertyAll(AppElevation.none),
      minimumSize: const WidgetStatePropertyAll(
        Size(AppTouchTarget.min, AppTouchTarget.min),
      ),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        _inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ),
    ),
  );
}

ListTileThemeData _buildListTileTheme({required bool dark}) {
  return ListTileThemeData(
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: 2,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    titleTextStyle: _inter(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: dark ? _kDarkTextSecondary : _kLightTextSecondary,
    ),
    subtitleTextStyle: _inter(
      fontSize: 13,
      color: dark ? _kDarkTextSubtle : _kLightTextSubtle,
    ),
  );
}

NavigationBarThemeData _buildNavigationBarTheme({required bool dark}) {
  return NavigationBarThemeData(
    elevation: 0,
    backgroundColor: dark ? _kDarkSurface : _kLightSurface,
    surfaceTintColor: Colors.transparent,
    indicatorColor: _kSeedColor.withAlpha(30),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return _inter(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: selected
            ? _kSeedColor
            : (dark ? _kDarkTextSubtle : _kLightTextSubtle),
      );
    }),
  );
}

DividerThemeData _buildDividerTheme({required bool dark}) {
  return DividerThemeData(
    color: dark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
    thickness: AppBorder.hairline,
    space: AppBorder.hairline,
  );
}

BottomSheetThemeData _buildBottomSheetTheme({required bool dark}) {
  return BottomSheetThemeData(
    backgroundColor: dark ? _kDarkSurface : _kLightSurface,
    surfaceTintColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    showDragHandle: true,
    dragHandleColor: dark
        ? Colors.white.withAlpha(50)
        : Colors.black.withAlpha(30),
  );
}

DialogThemeData _buildDialogTheme({required bool dark}) {
  return DialogThemeData(
    backgroundColor: dark ? _kDarkSurface : _kLightSurface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
    ),
    titleTextStyle: _inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: dark ? Colors.white : _kLightTextPrimary,
    ),
    contentTextStyle: _inter(
      fontSize: 14,
      color: dark ? _kDarkTextMuted : _kLightTextMuted,
    ),
  );
}

SnackBarThemeData _buildSnackBarTheme({required bool dark}) {
  return SnackBarThemeData(
    backgroundColor: dark ? _kSnackBarDark : _kSnackBarLight,
    contentTextStyle: _inter(fontSize: 14, color: Colors.white),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    behavior: SnackBarBehavior.floating,
    elevation: 4,
  );
}

// ─── ThemeHelper ─────────────────────────────────────────────────────────────

/// Theme helper for building theme data based on mode
class ThemeHelper {
  // Cache built themes per seed color. Theme construction builds text styles
  // and ~12 component themes — expensive enough that
  // repeating it on every MaterialApp rebuild is wasteful when the seed has
  // not changed.
  static final Map<Color, ThemeData> _lightCache = <Color, ThemeData>{};
  static final Map<Color, ThemeData> _darkCache = <Color, ThemeData>{};

  /// Build light theme data
  static ThemeData buildLightTheme({Color? seedColor}) {
    const seed = _kSeedColor;
    final effectiveSeed = seedColor ?? seed;
    final cached = _lightCache[effectiveSeed];
    if (cached != null) return cached;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: effectiveSeed,
          brightness: Brightness.light,
        ).copyWith(
          primary: effectiveSeed,
          onPrimary: Colors.white,
          surface: _kLightSurface,
          surfaceContainerHighest: _kLightSurfaceVariant,
          onSurface: _kLightTextSecondary,
          onSurfaceVariant: _kLightTextMuted,
          outline: Colors.black.withAlpha(20),
          outlineVariant: Colors.black.withAlpha(12),
        );

    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      iconButtonTheme: _buildIconButtonTheme(),
      textButtonTheme: _buildTextButtonTheme(),
      scaffoldBackgroundColor: _kLightBackground,
      textTheme: _buildTextTheme(dark: false),
      appBarTheme: _buildAppBarTheme(dark: false),
      cardTheme: _buildCardTheme(dark: false),
      inputDecorationTheme: _buildInputDecorationTheme(dark: false),
      chipTheme: _buildChipTheme(dark: false),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      filledButtonTheme: _buildFilledButtonTheme(),
      outlinedButtonTheme: _buildOutlinedButtonTheme(dark: false),
      listTileTheme: _buildListTileTheme(dark: false),
      navigationBarTheme: _buildNavigationBarTheme(dark: false),
      dividerTheme: _buildDividerTheme(dark: false),
      bottomSheetTheme: _buildBottomSheetTheme(dark: false),
      dialogTheme: _buildDialogTheme(dark: false),
      snackBarTheme: _buildSnackBarTheme(dark: false),
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppColorScheme.light(),
        AppTerminalColors.dark,
        SyntaxTheme.light,
        CodeViewerTheme.light,
        DiffTheme.light,
      ],
    );
    _lightCache[effectiveSeed] = theme;
    return theme;
  }

  /// Build dark theme data
  static ThemeData buildDarkTheme({Color? seedColor}) {
    const seed = _kSeedColor;
    final effectiveSeed = seedColor ?? seed;
    final cached = _darkCache[effectiveSeed];
    if (cached != null) return cached;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: effectiveSeed,
          brightness: Brightness.dark,
        ).copyWith(
          surface: _kDarkSurface,
          surfaceContainerLowest: _kDarkBackground,
          surfaceContainerLow: const Color(0xFF161922),
          surfaceContainer: _kDarkSurface,
          surfaceContainerHigh: const Color(0xFF1F222E),
          surfaceContainerHighest: _kDarkSurfaceVariant,
          onSurface: _kDarkTextSecondary,
          onSurfaceVariant: _kDarkTextSubtle,
          outline: Colors.white.withAlpha(25),
          outlineVariant: Colors.white.withAlpha(15),
        );

    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      iconButtonTheme: _buildIconButtonTheme(),
      textButtonTheme: _buildTextButtonTheme(),
      scaffoldBackgroundColor: _kDarkBackground,
      textTheme: _buildTextTheme(dark: true),
      appBarTheme: _buildAppBarTheme(dark: true),
      cardTheme: _buildCardTheme(dark: true),
      inputDecorationTheme: _buildInputDecorationTheme(dark: true),
      chipTheme: _buildChipTheme(dark: true),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      filledButtonTheme: _buildFilledButtonTheme(),
      outlinedButtonTheme: _buildOutlinedButtonTheme(dark: true),
      listTileTheme: _buildListTileTheme(dark: true),
      navigationBarTheme: _buildNavigationBarTheme(dark: true),
      dividerTheme: _buildDividerTheme(dark: true),
      bottomSheetTheme: _buildBottomSheetTheme(dark: true),
      dialogTheme: _buildDialogTheme(dark: true),
      snackBarTheme: _buildSnackBarTheme(dark: true),
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppColorScheme.dark(),
        AppTerminalColors.dark,
        SyntaxTheme.dark,
        CodeViewerTheme.dark,
        DiffTheme.dark,
      ],
    );
    _darkCache[effectiveSeed] = theme;
    return theme;
  }

  /// Build theme data based on mode
  static ThemeData buildTheme(AppThemeMode mode, {Color? seedColor}) {
    return switch (mode) {
      AppThemeMode.dark => buildDarkTheme(seedColor: seedColor),
      AppThemeMode.light => buildLightTheme(seedColor: seedColor),
      AppThemeMode.adaptive => _buildAdaptiveThemeNoContext(
        seedColor: seedColor,
      ),
    };
  }

  /// Build adaptive theme without requiring BuildContext
  static ThemeData _buildAdaptiveThemeNoContext({Color? seedColor}) {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark
        ? buildDarkTheme(seedColor: seedColor)
        : buildLightTheme(seedColor: seedColor);
  }

  /// Build theme data for adaptive mode using platform brightness
  static ThemeData buildAdaptiveTheme({
    required BuildContext context,
    Color? seedColor,
  }) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return brightness == Brightness.dark
        ? buildDarkTheme(seedColor: seedColor)
        : buildLightTheme(seedColor: seedColor);
  }

  /// Get the effective theme mode from settings string
  static AppThemeMode getThemeMode(String settingsValue) {
    return AppThemeMode.fromString(settingsValue);
  }
}
