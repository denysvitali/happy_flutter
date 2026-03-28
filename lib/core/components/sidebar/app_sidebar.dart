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
    this.inboxBadgeCount,
    this.showInboxBadge = false,
    super.key,
  });

  /// Currently active navigation tab.
  final AppTab activeTab;

  /// Called when the user taps a navigation item.
  final void Function(AppTab tab) onTabPress;

  /// Whether the sidebar is in collapsed (icon-only) mode.
  final bool isCollapsed;

  /// Called when the user taps the expand/collapse toggle button.
  final VoidCallback onToggleCollapsed;

  /// Numeric badge count for the Inbox tab.
  final int? inboxBadgeCount;

  /// Whether to show an unread dot on the Inbox tab.
  final bool showInboxBadge;

  /// Width when fully expanded.
  static const double expandedWidth = 200;

  /// Width when collapsed (icon-only).
  static const double collapsedWidth = 56;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  static const _kTabs = <AppTabInfo>[
    AppTabInfo(
      key: AppTab.inbox,
      icon: Icons.inbox_outlined,
      activeIcon: Icons.inbox,
      label: 'Inbox',
    ),
    AppTabInfo(
      key: AppTab.sessions,
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: 'Sessions',
    ),
    AppTabInfo(
      key: AppTab.settings,
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  String _labelForTab(AppTab tab, AppLocalizations l10n) {
    return switch (tab) {
      AppTab.inbox => l10n.tabsInbox,
      AppTab.sessions => l10n.sessionHistoryTitle,
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
      duration: AppDuration.normal,
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
              ...(_kTabs.map(
                (tab) => _SidebarItem(
                  tab: tab,
                  label: _labelForTab(tab.key, context.l10n),
                  isActive: widget.activeTab == tab.key,
                  isCollapsed: widget.isCollapsed,
                  badgeCount: tab.key == AppTab.inbox
                      ? widget.inboxBadgeCount
                      : null,
                  showDot: tab.key == AppTab.inbox &&
                      widget.showInboxBadge,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onTabPress(tab.key);
                  },
                ),
              )),
              const Spacer(),
              // Collapse/expand toggle
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

/// A single sidebar navigation item with icon, optional label, and badge.
class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.tab,
    required this.label,
    required this.isActive,
    required this.isCollapsed,
    required this.onTap,
    this.badgeCount,
    this.showDot = false,
  });

  final AppTabInfo tab;
  final String label;
  final bool isActive;
  final bool isCollapsed;
  final VoidCallback onTap;
  final int? badgeCount;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final activeColor = cs.primary;
    final inactiveColor = cs.onSurface.withValues(alpha: AppOpacity.half);
    final itemColor = isActive ? activeColor : inactiveColor;

    final iconWidget = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          isActive ? tab.activeIcon : tab.icon,
          size: AppSpacing.xl,
          color: itemColor,
        ),
        if (tab.key == AppTab.inbox &&
            badgeCount != null &&
            badgeCount! > 0)
          Positioned(
            top: -(AppSpacing.sm + AppSpacing.xs),
            right: -(AppSpacing.lg + AppSpacing.md),
            child: _SidebarBadge(count: badgeCount!),
          ),
        if (tab.key == AppTab.inbox &&
            showDot &&
            (badgeCount == null || badgeCount! == 0))
          Positioned(
            top: -AppSpacing.sm,
            right: -AppSpacing.xs,
            child: Container(
              width: AppSpacing.xs + AppSpacing.xs,
              height: AppSpacing.xs + AppSpacing.xs,
              decoration: BoxDecoration(
                color: cs.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );

    return Semantics(
      selected: isActive,
      button: true,
      label: label,
      child: Tooltip(
        message: isCollapsed ? label : '',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: AppDuration.normal,
            curve: AppCurve.standard,
            height: AppTouchTarget.comfortable,
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xxs,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed
                  ? AppSpacing.sm
                  : AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? cs.surfaceContainerHighest
                  : Colors.transparent,
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

// ─── _SidebarBadge ───────────────────────────────────────────────────────────

/// Numeric red badge for the sidebar inbox item.
class _SidebarBadge extends StatelessWidget {
  const _SidebarBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = count > 99 ? '99+' : count.toString();
    final isMultiDigit = count > 9;
    return Container(
      height: AppSpacing.md + AppSpacing.xs,
      constraints: BoxConstraints(
        minWidth: isMultiDigit
            ? AppSpacing.md + AppSpacing.xsm
            : AppSpacing.md,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMultiDigit ? AppSpacing.xs : 0,
      ),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppFontSize.xxs,
          color: cs.onError,
          fontWeight: FontWeight.w600,
          height: AppLineHeight.tight,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─── _CollapseToggle ─────────────────────────────────────────────────────────

/// Toggle button at the bottom of the sidebar that collapses or expands it.
class _CollapseToggle extends StatelessWidget {
  const _CollapseToggle({
    required this.isCollapsed,
    required this.onToggle,
  });

  final bool isCollapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = isCollapsed
        ? Icons.keyboard_arrow_right
        : Icons.keyboard_arrow_left;
    final tooltip = isCollapsed ? 'Expand sidebar' : 'Collapse sidebar';

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
            alignment: isCollapsed
                ? Alignment.center
                : Alignment.centerLeft,
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed
                  ? AppSpacing.sm
                  : AppSpacing.md,
            ),
            child: AnimatedRotation(
              turns: isCollapsed ? 0 : 0,
              duration: AppDuration.normal,
              curve: AppCurve.standard,
              child: Icon(
                icon,
                size: AppSpacing.xl,
                color: cs.onSurface.withValues(
                  alpha: AppOpacity.medium,
                ),
              ),
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
    this.inboxBadgeCount,
    this.showInboxBadge = false,
    this.bottomBar,
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

  /// Numeric badge count for the Inbox tab.
  final int? inboxBadgeCount;

  /// Whether to show an unread dot on the Inbox tab.
  final bool showInboxBadge;

  /// Optional custom bottom bar widget for phone layout.
  /// If null, no bottom bar is rendered on phone (caller provides it
  /// via [Scaffold.bottomNavigationBar]).
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= AppBreakpoint.tablet;

    if (!isTablet) {
      // Phone: just return the child; bottom bar is provided via Scaffold.
      return child;
    }

    // Tablet/desktop: sidebar layout
    return Row(
      children: [
        AppSidebar(
          activeTab: activeTab,
          onTabPress: onTabPress,
          isCollapsed: isCollapsed,
          onToggleCollapsed: onToggleCollapsed,
          inboxBadgeCount: inboxBadgeCount,
          showInboxBadge: showInboxBadge,
        ),
        Expanded(child: child),
      ],
    );
  }
}
