import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

/// Adaptive master-detail scaffold for tablet-and-up layouts.
class MasterDetailScaffold extends StatelessWidget {
  const MasterDetailScaffold({
    super.key,
    required this.master,
    required this.detail,
    required this.hasSelection,
    this.emptyDetail,
    this.masterWidth,
    this.tabletBreakpoint = AppBreakpoint.tablet,
    this.showDivider = true,
  });

  final Widget master;
  final Widget detail;
  final bool hasSelection;
  final Widget? emptyDetail;
  final double? masterWidth;
  final double tabletBreakpoint;
  final bool showDivider;

  static bool isWide(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= AppBreakpoint.tablet;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= tabletBreakpoint;

    if (!isWide) {
      return Builder(
        builder: (context) => hasSelection ? detail : master,
      );
    }

    final theme = Theme.of(context);
    final resolvedMasterWidth = masterWidth ?? AppBreakpoint.sidebarMax;
    final resolvedDetail = hasSelection
        ? detail
        : (emptyDetail ?? const _DefaultEmptyDetail());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: resolvedMasterWidth,
          child: Builder(builder: (context) => master),
        ),
        if (showDivider)
          VerticalDivider(
            width: AppBorder.thin,
            thickness: AppBorder.thin,
            color: theme.dividerColor,
          ),
        Expanded(
          child: Builder(builder: (context) => resolvedDetail),
        ),
      ],
    );
  }
}

/// Reusable empty-state placeholder for the detail pane.
class TabletDetailEmpty extends StatelessWidget {
  const TabletDetailEmpty({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppSpacing.xxxl + AppSpacing.lg,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultEmptyDetail extends StatelessWidget {
  const _DefaultEmptyDetail();

  @override
  Widget build(BuildContext context) {
    return const TabletDetailEmpty(
      icon: Icons.list_alt_outlined,
      message: 'Select an item',
    );
  }
}
