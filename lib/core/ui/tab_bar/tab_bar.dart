import 'package:flutter/material.dart';

/// Tab type for the app
enum AppTab {
  inbox,
  sessions,
  settings,
}

/// Bottom/app tab bar widget
class TabBar extends StatefulWidget {
  final AppTab activeTab;
  final void Function(AppTab tab) onTabPress;
  final int? inboxBadgeCount;
  final bool showInboxBadge;
  final double height;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final Color? indicatorColor;

  const TabBar({
    required this.activeTab,
    required this.onTabPress,
    this.inboxBadgeCount,
    this.showInboxBadge = false,
    this.height = 60,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.indicatorColor,
    super.key,
  });

  @override
  State<TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<TabBar> {
  late final List<AppTabInfo> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      const AppTabInfo(
        key: AppTab.inbox,
        icon: Icons.inbox_outlined,
        activeIcon: Icons.inbox,
        label: 'Inbox',
      ),
      const AppTabInfo(
        key: AppTab.sessions,
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'Sessions',
      ),
      const AppTabInfo(
        key: AppTab.settings,
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'Settings',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final backgroundColor = widget.backgroundColor ?? colorScheme.surface;
    final selectedColor = widget.selectedItemColor ?? colorScheme.primary;
    final unselectedColor = widget.unselectedItemColor ?? colorScheme.onSurfaceVariant;
    final indicatorColor = widget.indicatorColor ?? colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withOpacity(0.3),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: SizedBox(
          height: widget.height + MediaQuery.of(context).padding.bottom,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _tabs.map((tab) {
              final isActive = widget.activeTab == tab.key;

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.onTabPress(tab.key),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              isActive ? tab.activeIcon : tab.icon,
                              size: 24,
                              color: isActive ? selectedColor : unselectedColor,
                            ),
                            if (tab.key == AppTab.inbox &&
                                (widget.inboxBadgeCount != null &&
                                    widget.inboxBadgeCount! > 0))
                              Positioned(
                                top: -4,
                                right: -8,
                                child: _buildBadge(
                                  widget.inboxBadgeCount!,
                                  indicatorColor,
                                ),
                              ),
                            if (tab.key == AppTab.inbox &&
                                widget.showInboxBadge &&
                                (widget.inboxBadgeCount == null ||
                                    widget.inboxBadgeCount! == 0))
                              Positioned(
                                top: -4,
                                right: -2,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: indicatorColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: isActive ? selectedColor : unselectedColor,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(int count, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(
        minWidth: 16,
        minHeight: 16,
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Tab information data class
@immutable
class AppTabInfo {
  final AppTab key;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const AppTabInfo({
    required this.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Compact tab bar for tablets
class CompactTabBar extends StatelessWidget {
  final AppTab activeTab;
  final void Function(AppTab tab) onTabPress;
  final double iconSize;
  final Color? selectedColor;
  final Color? unselectedColor;

  const CompactTabBar({
    required this.activeTab,
    required this.onTabPress,
    this.iconSize = 24,
    this.selectedColor,
    this.unselectedColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedColor = this.selectedColor ?? colorScheme.primary;
    final unselectedColor = this.unselectedColor ?? colorScheme.onSurfaceVariant;

    final tabs = [
      const AppTabInfo(
        key: AppTab.inbox,
        icon: Icons.inbox_outlined,
        activeIcon: Icons.inbox,
        label: 'Inbox',
      ),
      const AppTabInfo(
        key: AppTab.sessions,
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'Sessions',
      ),
      const AppTabInfo(
        key: AppTab.settings,
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings,
        label: 'Settings',
      ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: tabs.map((tab) {
        final isActive = activeTab == tab.key;
        return IconButton(
          icon: Icon(
            isActive ? tab.activeIcon : tab.icon,
            size: iconSize,
            color: isActive ? selectedColor : unselectedColor,
          ),
          onPressed: () => onTabPress(tab.key),
          tooltip: tab.label,
        );
      }).toList(),
    );
  }
}

/// Segment control style tab bar
class SegmentTabBar extends StatefulWidget {
  final List<String> tabs;
  final int selectedIndex;
  final void Function(int index) onTabPress;
  final EdgeInsetsGeometry padding;
  final TextStyle? selectedTextStyle;
  final TextStyle? unselectedTextStyle;

  const SegmentTabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabPress,
    this.padding = const EdgeInsets.all(4),
    this.selectedTextStyle,
    this.unselectedTextStyle,
    super.key,
  });

  @override
  State<SegmentTabBar> createState() => _SegmentTabBarState();
}

class _SegmentTabBarState extends State<SegmentTabBar> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: widget.tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final isSelected = widget.selectedIndex == index;

          return GestureDetector(
            onTap: () => widget.onTabPress(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                entry.value,
                style: isSelected
                    ? (widget.selectedTextStyle ??
                        theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ))
                    : (widget.unselectedTextStyle ??
                        theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
