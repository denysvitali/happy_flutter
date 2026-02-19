import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status bar style configuration
enum StatusBarStyle {
  light,
  dark,
  automatic,
}

/// Status bar configuration
class StatusBarConfig {

  const StatusBarConfig({
    this.style = StatusBarStyle.automatic,
    this.animate = true,
    this.overlayStyle,
  });
  final StatusBarStyle style;
  final bool animate;
  final SystemUiOverlayStyle? overlayStyle;

  StatusBarConfig copyWith({
    StatusBarStyle? style,
    bool? animate,
    SystemUiOverlayStyle? overlayStyle,
  }) {
    return StatusBarConfig(
      style: style ?? this.style,
      animate: animate ?? this.animate,
      overlayStyle: overlayStyle ?? this.overlayStyle,
    );
  }
}

/// Theme-aware status bar widget
class StatusBarTheme extends StatefulWidget {

  const StatusBarTheme({
    required this.child,
    this.config = const StatusBarConfig(),
    this.darkMode = false,
    super.key,
  });
  final Widget child;
  final StatusBarConfig config;
  final bool darkMode;

  @override
  State<StatusBarTheme> createState() => _StatusBarThemeState();
}

class _StatusBarThemeState extends State<StatusBarTheme> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateStatusBarStyle();
  }

  @override
  void didUpdateWidget(StatusBarTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.darkMode != widget.darkMode) {
      _updateStatusBarStyle();
    }
  }

  void _updateStatusBarStyle() {
    final style = _computeStyle();
    if (widget.config.animate) {
      // Small delay to allow for smooth transition
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          SystemChrome.setSystemUIOverlayStyle(style);
        }
      });
    } else {
      SystemChrome.setSystemUIOverlayStyle(style);
    }
  }

  SystemUiOverlayStyle _computeStyle() {
    if (widget.config.overlayStyle != null) {
      return widget.config.overlayStyle!;
    }

    final style = widget.config.style;

    switch (style) {
      case StatusBarStyle.light:
        return SystemUiOverlayStyle.light;
      case StatusBarStyle.dark:
        return SystemUiOverlayStyle.dark;
      case StatusBarStyle.automatic:
        return widget.darkMode
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;
    }
  }

  @override
  void dispose() {
    // Reset to default when widget is disposed
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Navigation bar theme configuration
class NavigationBarTheme {

  const NavigationBarTheme({
    this.backgroundColor,
    this.itemColor,
    this.selectedItemColor,
    this.indicatorColor,
    this.systemNavigationBarMode,
    this.systemNavigationBarOverlay,
  });
  final Color? backgroundColor;
  final Color? itemColor;
  final Color? selectedItemColor;
  final Color? indicatorColor;
  final SystemUiMode? systemNavigationBarMode;
  final SystemUiOverlayStyle? systemNavigationBarOverlay;

  NavigationBarTheme copyWith({
    Color? backgroundColor,
    Color? itemColor,
    Color? selectedItemColor,
    Color? indicatorColor,
    SystemUiMode? systemNavigationBarMode,
    SystemUiOverlayStyle? systemNavigationBarOverlay,
  }) {
    return NavigationBarTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      itemColor: itemColor ?? this.itemColor,
      selectedItemColor: selectedItemColor ?? this.selectedItemColor,
      indicatorColor: indicatorColor ?? this.indicatorColor,
      systemNavigationBarMode:
          systemNavigationBarMode ?? this.systemNavigationBarMode,
      systemNavigationBarOverlay:
          systemNavigationBarOverlay ?? this.systemNavigationBarOverlay,
    );
  }
}

/// Widget to configure navigation bar
class NavigationBarThemeWrapper extends StatelessWidget {

  const NavigationBarThemeWrapper({
    required this.child,
    this.theme = const NavigationBarTheme(),
    this.darkMode = false,
    super.key,
  });
  final Widget child;
  final NavigationBarTheme theme;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    // Apply navigation bar configuration
    final overlayStyle = theme.systemNavigationBarOverlay ??
        (darkMode
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark);

    SystemChrome.setSystemUIOverlayStyle(overlayStyle);

    return child;
  }
}

/// Combined status and navigation bar theme wrapper
class SystemBarsTheme extends StatelessWidget {

  const SystemBarsTheme({
    required this.child,
    this.statusBarConfig = const StatusBarConfig(),
    this.navigationBarTheme = const NavigationBarTheme(),
    this.darkMode = false,
    super.key,
  });
  final Widget child;
  final StatusBarConfig statusBarConfig;
  final NavigationBarTheme navigationBarTheme;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return StatusBarTheme(
      config: statusBarConfig,
      darkMode: darkMode,
      child: NavigationBarThemeWrapper(
        theme: navigationBarTheme,
        darkMode: darkMode,
        child: child,
      ),
    );
  }
}

/// Animated status bar color transition
class AnimatedStatusBar extends StatefulWidget {

  const AnimatedStatusBar({
    required this.child,
    required this.targetStyle,
    this.duration = const Duration(milliseconds: 300),
    super.key,
  });
  final Widget child;
  final SystemUiOverlayStyle targetStyle;
  final Duration duration;

  @override
  State<AnimatedStatusBar> createState() => _AnimatedStatusBarState();
}

class _AnimatedStatusBarState extends State<AnimatedStatusBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(AnimatedStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetStyle != widget.targetStyle) {
      // Apply the new style immediately when animation is not used
      SystemChrome.setSystemUIOverlayStyle(widget.targetStyle);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Extension to get system bar brightness from theme brightness
extension SystemBarBrightnessExtension on Brightness {
  SystemUiOverlayStyle get statusBarStyle {
    return this == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
  }

  SystemUiOverlayStyle get navigationBarStyle {
    return this == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
  }
}
