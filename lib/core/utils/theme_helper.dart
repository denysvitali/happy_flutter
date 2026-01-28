import 'package:flutter/material.dart';

/// Theme mode enumeration matching React Native's themePreference
enum AppThemeMode {
  adaptive('adaptive', 'Follow system'),
  light('light', 'Always light'),
  dark('dark', 'Always dark');

  final String value;
  final String description;

  const AppThemeMode(this.value, this.description);

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
  AppThemeMode get appThemeMode {
    final settings = this.readExtension<Settings?>();
    if (settings == null) {
      // Try to read from provider directly if extension didn't work
      try {
        final notifier = this.read<Settings?>(/* This would need provider ref */);
        return AppThemeMode.fromString(notifier?.themeMode ?? 'system');
      } catch (_) {
        return AppThemeMode.adaptive;
      }
    }
    return AppThemeMode.fromString(settings.themeMode);
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
        MediaQuery.platformBrightnessOf(_getContext()),
    };

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: brightness,
        systemNavigationBarColor:
            brightness == Brightness.dark ? Colors.black : Colors.white,
        systemNavigationBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
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
      systemNavigationBarColor:
          brightness == Brightness.dark ? Colors.black : Colors.white,
      systemNavigationBarIconBrightness:
          brightness == Brightness.dark ? Brightness.light : Brightness.dark,
    );
  }

  static BuildContext _getContext() {
    // This is a workaround - in practice, the calling code will
    // pass the context directly
    throw UnimplementedError(
        'Use applySystemChromeWithContext(context) instead');
  }

  /// Apply SystemChrome with explicit context
  void applySystemChromeWithContext(BuildContext context) {
    final overlayStyle = getOverlayStyle(context);
    SystemChrome.setSystemUIOverlayStyle(overlayStyle);
  }
}

/// Theme helper for building theme data based on mode
class ThemeHelper {
  /// Build light theme data
  static ThemeData buildLightTheme({Color? seedColor}) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor ?? Colors.blue,
        primary: seedColor ?? Colors.blue,
        secondary: Colors.blueAccent,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      brightness: Brightness.light,
    );
  }

  /// Build dark theme data
  static ThemeData buildDarkTheme({Color? seedColor}) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor ?? Colors.blue,
        primary: seedColor ?? Colors.blue,
        secondary: Colors.blueAccent,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      brightness: Brightness.dark,
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
          'Use buildAdaptiveTheme instead for adaptive mode'),
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
