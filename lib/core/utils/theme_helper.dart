import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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
  /// Get the current app theme mode from settings
  /// Note: This is a stub - actual theme mode should be read from provider
  AppThemeMode get appThemeMode => AppThemeMode.adaptive;

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
        MediaQuery.platformBrightnessOf(_getContext()),
    };

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
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

  static BuildContext _getContext() {
    // This is a workaround - in practice, the calling code will
    // pass the context directly
    throw UnimplementedError(
      'Use applySystemChromeWithContext(context) instead',
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

// ─── Text themes ─────────────────────────────────────────────────────────────

/// Body / UI text: Inter
TextTheme _buildTextTheme({required bool dark}) {
  final base = dark ? ThemeData.dark() : ThemeData.light();
  return GoogleFonts.interTextTheme(base.textTheme).copyWith(
    // Titles — DM Sans
    displayLarge: GoogleFonts.dmSans(
      fontSize: 57,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
      color: dark ? Colors.white : const Color(0xFF0F172A),
    ),
    displayMedium: GoogleFonts.dmSans(
      fontSize: 45,
      fontWeight: FontWeight.w400,
      color: dark ? Colors.white : const Color(0xFF0F172A),
    ),
    displaySmall: GoogleFonts.dmSans(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      color: dark ? Colors.white : const Color(0xFF0F172A),
    ),
    headlineLarge: GoogleFonts.dmSans(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: dark ? Colors.white : const Color(0xFF0F172A),
    ),
    headlineMedium: GoogleFonts.dmSans(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: dark ? Colors.white : const Color(0xFF0F172A),
    ),
    headlineSmall: GoogleFonts.dmSans(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: dark ? Colors.white : const Color(0xFF0F172A),
    ),
    titleLarge: GoogleFonts.dmSans(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: dark ? Colors.white : const Color(0xFF0F172A),
    ),
    titleMedium: GoogleFonts.dmSans(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      color: dark ? Colors.white : const Color(0xFF0F172A),
    ),
    titleSmall: GoogleFonts.dmSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: dark
          ? const Color(0xFFCBD5E1)
          : const Color(0xFF334155),
    ),
    // Body — Inter
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
      color: dark
          ? const Color(0xFFE2E8F0)
          : const Color(0xFF1E293B),
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      color: dark
          ? const Color(0xFFE2E8F0)
          : const Color(0xFF1E293B),
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      color: dark
          ? const Color(0xFF94A3B8)
          : const Color(0xFF64748B),
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    labelSmall: GoogleFonts.inter(
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
    backgroundColor:
        dark ? _kDarkSurface.withAlpha(230) : _kLightSurface.withAlpha(230),
    foregroundColor: dark ? Colors.white : const Color(0xFF0F172A),
    centerTitle: false,
    titleTextStyle: GoogleFonts.dmSans(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: dark ? Colors.white : const Color(0xFF0F172A),
    ),
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    ),
  );
}

CardThemeData _buildCardTheme({required bool dark}) {
  return CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: dark
            ? Colors.white.withAlpha(18)
            : Colors.black.withAlpha(12),
      ),
    ),
    color: dark ? _kDarkSurface : _kLightSurface,
    surfaceTintColor: Colors.transparent,
    margin: EdgeInsets.zero,
  );
}

InputDecorationTheme _buildInputDecorationTheme({required bool dark}) {
  final borderColor = dark
      ? Colors.white.withAlpha(30)
      : Colors.black.withAlpha(20);
  final focusColor = _kSeedColor;
  const radius = BorderRadius.all(Radius.circular(12));

  return InputDecorationTheme(
    filled: true,
    fillColor: dark ? _kDarkSurfaceVariant : _kLightSurfaceVariant,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 14,
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
      borderSide: BorderSide(color: focusColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: Color(0xFFEF4444)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide:
          const BorderSide(color: Color(0xFFEF4444), width: 2),
    ),
    hintStyle: GoogleFonts.inter(
      fontSize: 14,
      color: dark
          ? const Color(0xFF64748B)
          : const Color(0xFF94A3B8),
    ),
  );
}

ChipThemeData _buildChipTheme({required bool dark}) {
  return ChipThemeData(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    labelStyle: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    side: BorderSide(
      color: dark
          ? Colors.white.withAlpha(25)
          : Colors.black.withAlpha(18),
    ),
    backgroundColor:
        dark ? _kDarkSurfaceVariant : _kLightSurfaceVariant,
  );
}

ElevatedButtonThemeData _buildElevatedButtonTheme() {
  return ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _kSeedColor,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    ),
  );
}

FilledButtonThemeData _buildFilledButtonTheme() {
  return FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: _kSeedColor,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    ),
  );
}

OutlinedButtonThemeData _buildOutlinedButtonTheme({
  required bool dark,
}) {
  return OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _kSeedColor,
      side: const BorderSide(color: _kSeedColor),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    ),
  );
}

ListTileThemeData _buildListTileTheme({required bool dark}) {
  return ListTileThemeData(
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 2,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: dark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
    ),
    subtitleTextStyle: GoogleFonts.inter(
      fontSize: 13,
      color: dark
          ? const Color(0xFF94A3B8)
          : const Color(0xFF64748B),
    ),
  );
}

NavigationBarThemeData _buildNavigationBarTheme({
  required bool dark,
}) {
  return NavigationBarThemeData(
    elevation: 0,
    backgroundColor:
        dark ? _kDarkSurface : _kLightSurface,
    surfaceTintColor: Colors.transparent,
    indicatorColor: _kSeedColor.withAlpha(30),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return GoogleFonts.inter(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: selected
            ? _kSeedColor
            : (dark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B)),
      );
    }),
  );
}

DividerThemeData _buildDividerTheme({required bool dark}) {
  return DividerThemeData(
    color: dark
        ? Colors.white.withAlpha(15)
        : Colors.black.withAlpha(10),
    thickness: 1,
    space: 1,
  );
}

BottomSheetThemeData _buildBottomSheetTheme({required bool dark}) {
  return BottomSheetThemeData(
    backgroundColor: dark ? _kDarkSurface : _kLightSurface,
    surfaceTintColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20),
      ),
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
      borderRadius: BorderRadius.circular(20),
    ),
    titleTextStyle: GoogleFonts.dmSans(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: dark ? Colors.white : const Color(0xFF0F172A),
    ),
    contentTextStyle: GoogleFonts.inter(
      fontSize: 14,
      color: dark
          ? const Color(0xFFCBD5E1)
          : const Color(0xFF475569),
    ),
  );
}

SnackBarThemeData _buildSnackBarTheme({required bool dark}) {
  return SnackBarThemeData(
    backgroundColor:
        dark ? const Color(0xFF1E293B) : const Color(0xFF1E293B),
    contentTextStyle: GoogleFonts.inter(
      fontSize: 14,
      color: Colors.white,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    behavior: SnackBarBehavior.floating,
    elevation: 4,
  );
}

// ─── ThemeHelper ─────────────────────────────────────────────────────────────

/// Theme helper for building theme data based on mode
class ThemeHelper {
  /// Build light theme data
  static ThemeData buildLightTheme({Color? seedColor}) {
    const seed = _kSeedColor;
    final effectiveSeed = seedColor ?? seed;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: effectiveSeed,
      brightness: Brightness.light,
    ).copyWith(
      surface: _kLightSurface,
      surfaceContainerHighest: _kLightSurfaceVariant,
      onSurface: const Color(0xFF1E293B),
      onSurfaceVariant: const Color(0xFF475569),
      outline: Colors.black.withAlpha(20),
      outlineVariant: Colors.black.withAlpha(12),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
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
    );
  }

  /// Build dark theme data
  static ThemeData buildDarkTheme({Color? seedColor}) {
    const seed = _kSeedColor;
    final effectiveSeed = seedColor ?? seed;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: effectiveSeed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: _kDarkSurface,
      surfaceContainerHighest: _kDarkSurfaceVariant,
      onSurface: const Color(0xFFE2E8F0),
      onSurfaceVariant: const Color(0xFF94A3B8),
      outline: Colors.white.withAlpha(25),
      outlineVariant: Colors.white.withAlpha(15),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
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
    );
  }

  /// Build theme data based on mode
  static ThemeData buildTheme(
    AppThemeMode mode, {
    Color? seedColor,
  }) {
    return switch (mode) {
      AppThemeMode.dark => buildDarkTheme(seedColor: seedColor),
      AppThemeMode.light => buildLightTheme(seedColor: seedColor),
      AppThemeMode.adaptive => throw UnimplementedError(
          'Use buildAdaptiveTheme instead for adaptive mode',
        ),
    };
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
