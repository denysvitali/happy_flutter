import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter/services.dart';

import '../../i18n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../ui/tab_bar/tab_bar.dart';

// ─── AppSidebar ──────────────────────────────────────────────────────────────

/// Collapsible vertical sidebar for tablet/desktop layouts (≥600 px).
///
/// When [isCollapsed] is `true` only icons are shown (56 px wide).
/// When expanded the sidebar shows icons + labels (200 px wide).
/// The toggle button at the bottom animates the transition using
/// [AppDuration.normal] and [AppCurve.standard].
class AppSidebar extends StatefulWidget {
  const AppSidebar({
    required this.activeTab,
    required this.onTabPress,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    super.key,
    this.badgeCounts = const <AppTab, int>{},
    this.showCollapseToggle = true,
  });

  /// Currently active navigation tab.
  final AppTab activeTab;

  /// Called when the user taps a navigation item.
  final void Function(AppTab tab) onTabPress;

  /// Whether the sidebar is in collapsed (icon-only) mode.
  final bool isCollapsed;

  /// Called when the user taps the expand/collapse toggle button.
  final VoidCallback onToggleCollapsed;

  /// Optional operational counts surfaced beside destinations.
  final Map<AppTab, int> badgeCounts;

  /// Whether the pane can expand at the current viewport width.
  final bool showCollapseToggle;

  /// Width when fully expanded.
  static const double expandedWidth = 200;

  /// Width when collapsed (icon-only).
  static const double collapsedWidth = 56;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  String _labelForTab(AppTab tab, AppLocalizations l10n) {
    return switch (tab) {
      AppTab.sessions => l10n.sessionHistoryTitle,
      AppTab.loops => l10n.tabsLoops,
      AppTab.providers => l10n.tabsProviders,
      AppTab.settings => l10n.tabsSettings,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final targetWidth = widget.isCollapsed
        ? AppSidebar.collapsedWidth
        : AppSidebar.expandedWidth;

    return AnimatedContainer(
      duration: AppMotion.duration(context, AppDuration.normal),
      curve: AppCurve.standard,
      width: targetWidth,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            right: BorderSide(
              color: cs.onSurface.withValues(alpha: AppOpacity.faint),
            ),
          ),
        ),
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              // Navigation items
              ...(appTabs.map(
                (tab) => _SidebarItem(
                  tab: tab,
                  label: _labelForTab(tab.key, context.l10n),
                  isActive: widget.activeTab == tab.key,
                  isCollapsed: widget.isCollapsed,
                  badgeCount: widget.badgeCounts[tab.key] ?? 0,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onTabPress(tab.key);
                  },
                ),
              )),
              const Spacer(),
              // Collapse/expand toggle
              if (widget.showCollapseToggle)
                _CollapseToggle(
                  isCollapsed: widget.isCollapsed,
                  onToggle: widget.onToggleCollapsed,
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── _SidebarItem ────────────────────────────────────────────────────────────

/// A single sidebar navigation item with icon and optional label.
class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.tab,
    required this.label,
    required this.isActive,
    required this.isCollapsed,
    required this.onTap,
    this.badgeCount = 0,
  });

  final AppTabInfo tab;
  final String label;
  final bool isActive;
  final bool isCollapsed;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final activeColor = cs.primary;
    final inactiveColor = cs.onSurface.withValues(alpha: AppOpacity.half);
    final itemColor = isActive ? activeColor : inactiveColor;

    final hasBadge = tab.key == AppTab.loops && badgeCount > 0;
    final iconWidget = Badge(
      isLabelVisible: hasBadge,
      label: Text(badgeCount > 9 ? '9+' : '$badgeCount'),
      child: Icon(
        isActive ? tab.activeIcon : tab.icon,
        size: AppIconSize.tab,
        color: itemColor,
      ),
    );

    final semanticsLabel = hasBadge
        ? context.l10n.a11yTabWithBadge(label, badgeCount)
        : label;

    return Semantics(
      excludeSemantics: true,
      selected: isActive,
      button: true,
      label: semanticsLabel,
      child: Tooltip(
        message: isCollapsed ? label : '',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: AppMotion.duration(context, AppDuration.normal),
            curve: AppCurve.standard,
            height: AppTouchTarget.comfortable,
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xxs,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? AppSpacing.sm : AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isActive ? cs.surfaceContainerHighest : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: isCollapsed
                ? Center(child: iconWidget)
                : Row(
                    children: [
                      iconWidget,
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: itemColor,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── _CollapseToggle ─────────────────────────────────────────────────────────

/// Toggle button at the bottom of the sidebar that collapses or expands it.
class _CollapseToggle extends StatelessWidget {
  const _CollapseToggle({required this.isCollapsed, required this.onToggle});

  final bool isCollapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = isCollapsed
        ? Icons.keyboard_arrow_right
        : Icons.keyboard_arrow_left;
    final shortcut = (!kIsWeb && Platform.isMacOS) ? '⌘B' : 'Ctrl+B';
    final label = isCollapsed ? 'Expand sidebar' : 'Collapse sidebar';
    final tooltip = '$label ($shortcut)';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            height: AppTouchTarget.min,
            alignment: isCollapsed ? Alignment.center : Alignment.centerLeft,
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? AppSpacing.sm : AppSpacing.md,
            ),
            child: Icon(
              icon,
              size: AppSpacing.xl,
              color: cs.onSurface.withValues(alpha: AppOpacity.medium),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── ResponsiveNavLayout ─────────────────────────────────────────────────────

/// Responsive navigation shell that switches between a bottom tab bar
/// (phone, <600 px) and a collapsible sidebar (tablet/desktop, ≥600 px).
///
/// The sidebar collapse state is persisted across restarts via [MMKVStorage].
class ResponsiveNavLayout extends StatelessWidget {
  const ResponsiveNavLayout({
    required this.activeTab,
    required this.onTabPress,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.child,
    this.bottomBar,
    this.badgeCounts = const <AppTab, int>{},
    super.key,
  });

  /// Currently active navigation tab.
  final AppTab activeTab;

  /// Called when the user taps a navigation item.
  final void Function(AppTab tab) onTabPress;

  /// Whether the sidebar is in collapsed mode (only relevant on ≥600 px).
  final bool isCollapsed;

  /// Called when the user taps the sidebar collapse/expand toggle.
  final VoidCallback onToggleCollapsed;

  /// The main content area (tab body).
  final Widget child;

  /// Optional custom bottom bar widget for phone layout.
  /// If null, no bottom bar is rendered on phone (caller provides it
  /// via [Scaffold.bottomNavigationBar]).
  final Widget? bottomBar;

  /// Optional operational counts mirrored from the phone tab bar.
  final Map<AppTab, int> badgeCounts;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= AppBreakpoint.tablet;

    if (!isTablet) {
      // Phone: just return the child; bottom bar is provided via Scaffold.
      return child;
    }

    // Compact tablets always use the 56 px rail. Expanding it would leave
    // too little usable width for master-detail chat; desktop keeps the
    // user's persisted preference and exposes the toggle.
    final canExpand = width >= AppBreakpoint.desktop;
    final effectiveCollapsed = !canExpand || isCollapsed;
    final sidebarWidth = effectiveCollapsed
        ? AppSidebar.collapsedWidth
        : AppSidebar.expandedWidth;
    final mediaQuery = MediaQuery.of(context);
    return Row(
      children: [
        AppSidebar(
          activeTab: activeTab,
          onTabPress: onTabPress,
          isCollapsed: effectiveCollapsed,
          onToggleCollapsed: onToggleCollapsed,
          badgeCounts: badgeCounts,
          showCollapseToggle: canExpand,
        ),
        Expanded(
          child: MediaQuery(
            data: mediaQuery.copyWith(
              size: Size(width - sidebarWidth, mediaQuery.size.height),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
