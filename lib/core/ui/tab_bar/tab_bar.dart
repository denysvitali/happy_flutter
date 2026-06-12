import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter/services.dart';

import '../../../platform_io.dart'
    if (dart.library.js_interop) '../../../platform_stub.dart';
import '../../i18n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

/// Tab type for the app
enum AppTab {
  sessions,
  providers,
  settings,
}

// ─── AppTabInfo ──────────────────────────────────────────────────────────────

/// Tab information data class
@immutable
class AppTabInfo {
  const AppTabInfo({
    required this.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final AppTab key;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

// ─── _TabIndicator ───────────────────────────────────────────────────────────

/// Animated pill-shaped indicator that slides between tab positions.
///
/// [tabCount] is the total number of tabs; [activeIndex] is the currently
/// selected one. The pill is drawn behind the active icon+label.
class _TabIndicator extends StatelessWidget {
  const _TabIndicator({
    required this.activeIndex,
    required this.tabCount,
  });

  final int activeIndex;
  final int tabCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / tabCount;
        final pillWidth = tabWidth * 0.72;
        final leftOffset =
            activeIndex * tabWidth + (tabWidth - pillWidth) / 2;

        return Stack(
          children: [
            AnimatedPositioned(
              duration: AppDuration.fast,
              curve: AppCurve.standard,
              left: leftOffset,
              top: 0,
              bottom: 0,
              width: pillWidth,
              child: Container(
                height: AppTouchTarget.min - 4,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── _TabItem ────────────────────────────────────────────────────────────────

/// A single tab button: icon stacked above label.
class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.label,
    required this.onTap,
  });

  final AppTabInfo tab;
  final bool isActive;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final activeColor = colorScheme.primary;
    final inactiveColor = colorScheme.onSurface
        .withValues(alpha: AppOpacity.half);
    final itemColor = isActive ? activeColor : inactiveColor;

    return Expanded(
      child: Semantics(
        selected: isActive,
        button: true,
        label: label,
        child: Tooltip(
          message: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: SizedBox(
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isActive ? tab.activeIcon : tab.icon,
                    size: AppSpacing.xxxl - AppSpacing.lg,
                    color: itemColor,
                  ),
                  const SizedBox(height: AppSpacing.xsm),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: itemColor,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── _kAppTabs ───────────────────────────────────────────────────────────────

/// Canonical tab definition list shared by [TabBar] and [CompactTabBar].
const _kAppTabs = <AppTabInfo>[
  AppTabInfo(
    key: AppTab.sessions,
    icon: Icons.chat_bubble_outline,
    activeIcon: Icons.chat_bubble,
    label: 'Sessions',
  ),
  AppTabInfo(
    key: AppTab.providers,
    icon: Icons.cloud_outlined,
    activeIcon: Icons.cloud,
    label: 'Providers',
  ),
  AppTabInfo(
    key: AppTab.settings,
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    label: 'Settings',
  ),
];

// ─── TabBar ──────────────────────────────────────────────────────────────────

/// Bottom/app tab bar widget
class TabBar extends StatefulWidget {
  const TabBar({
    required this.activeTab,
    required this.onTabPress,
    this.height = 60,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.indicatorColor,
    super.key,
  });

  final AppTab activeTab;
  final void Function(AppTab tab) onTabPress;
  final double height;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final Color? indicatorColor;

  /// Default height matches iOS tab bar standards.
  static const double defaultHeight = AppTouchTarget.comfortable + 12;

  @override
  State<TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<TabBar> {
  int get _activeIndex =>
      _kAppTabs.indexWhere((t) => t.key == widget.activeTab);

  String _labelForTab(AppTab tab, AppLocalizations l10n) {
    return switch (tab) {
      AppTab.sessions => l10n.sessionHistoryTitle,
      AppTab.providers => l10n.tabsProviders,
      AppTab.settings => l10n.tabsSettings,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final onIOS = !kIsWeb && isIOS;

    final bgColor =
        widget.backgroundColor ?? colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        // Subtle top border instead of a hard shadow line
        border: Border(
          top: BorderSide(
            color: colorScheme.onSurface.withValues(
                alpha: AppOpacity.faint),
          ),
        ),
        // Frosted glass elevation on iOS; clean card on Android
        boxShadow: onIOS ? AppShadow.floating : AppShadow.card,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              // Animated pill indicator layer (behind the items)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm + AppSpacing.xs,
                  ),
                  child: _TabIndicator(
                    activeIndex: _activeIndex,
                    tabCount: _kAppTabs.length,
                  ),
                ),
              ),
              // Tab items row (above indicator)
              Row(
                children: _kAppTabs.map((tab) {
                  final isActive = widget.activeTab == tab.key;
                  return _TabItem(
                    tab: tab,
                    isActive: isActive,
                    label: _labelForTab(tab.key, l10n),
                    onTap: () => widget.onTabPress(tab.key),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CompactTabBar ───────────────────────────────────────────────────────────

/// Icon-only compact tab bar, designed for tablet rail/sidebar use.
///
/// Each icon has a 44 px minimum tap target. Active icons use the primary
/// color; inactive icons use onSurface at 40 % opacity.
class CompactTabBar extends StatelessWidget {
  const CompactTabBar({
    required this.activeTab,
    required this.onTabPress,
    this.iconSize = 24,
    this.selectedColor,
    this.unselectedColor,
    super.key,
  });

  final AppTab activeTab;
  final void Function(AppTab tab) onTabPress;
  final double iconSize;
  final Color? selectedColor;
  final Color? unselectedColor;

  String _labelForTab(AppTab tab, AppLocalizations l10n) {
    return switch (tab) {
      AppTab.sessions => l10n.sessionHistoryTitle,
      AppTab.providers => l10n.tabsProviders,
      AppTab.settings => l10n.tabsSettings,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final active = selectedColor ?? colorScheme.primary;
    final inactive = unselectedColor ??
        colorScheme.onSurface.withValues(alpha: 0.4);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _kAppTabs.map((tab) {
        final isActive = activeTab == tab.key;
        return SizedBox(
          width: AppTouchTarget.min,
          height: AppTouchTarget.min,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              isActive ? tab.activeIcon : tab.icon,
              size: iconSize,
              color: isActive ? active : inactive,
            ),
            onPressed: () => onTabPress(tab.key),
            tooltip: _labelForTab(tab.key, l10n),
          ),
        );
      }).toList(),
    );
  }
}

// ─── SegmentTabBar ───────────────────────────────────────────────────────────

/// iOS-style segmented control tab bar with animated active segment.
///
/// The container is a rounded pill with a `surfaceContainerHighest`
/// background. The active segment slides as a white/surface pill with a
/// subtle shadow and a 200 ms easeInOut animation.
class SegmentTabBar extends StatelessWidget {
  const SegmentTabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabPress,
    this.padding = const EdgeInsets.all(4),
    this.selectedTextStyle,
    this.unselectedTextStyle,
    super.key,
  });

  final List<String> tabs;
  final int selectedIndex;
  final void Function(int index) onTabPress;
  final EdgeInsetsGeometry padding;
  final TextStyle? selectedTextStyle;
  final TextStyle? unselectedTextStyle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Resolve inner padding to calculate usable width
          final resolvedPadding =
              padding.resolve(Directionality.of(context));
          final innerWidth = constraints.maxWidth -
              resolvedPadding.left -
              resolvedPadding.right;
          final segmentWidth = innerWidth / tabs.length;

          return Stack(
            children: [
              // Sliding active segment pill
              AnimatedPositioned(
                duration: AppDuration.fast,
                curve: AppCurve.standard,
                left: selectedIndex * segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  margin: const EdgeInsets.all(AppSpacing.xxs),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: AppSpacing.xs + AppSpacing.xs,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              // Label row (above the pill)
              Row(
                children: tabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final isSelected = selectedIndex == index;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTabPress(index),
                    child: SizedBox(
                      width: segmentWidth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xsm + AppSpacing.xs,
                        ),
                        child: Text(
                          entry.value,
                          textAlign: TextAlign.center,
                          style: isSelected
                              ? (selectedTextStyle ??
                                  const TextStyle(
                                    fontSize: AppFontSize.md,
                                    fontWeight: FontWeight.w600,
                                    height: AppLineHeight.tight,
                                  ))
                              : (unselectedTextStyle ??
                                  TextStyle(
                                    fontSize: AppFontSize.md,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface
                                        .withValues(
                                            alpha: AppOpacity.high),
                                    height: AppLineHeight.tight,
                                  )),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
