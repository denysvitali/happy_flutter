part of 'tab_bar.dart';

typedef _TabLayout = ({
  int columns,
  bool horizontal,
  double labelHeight,
  double height,
});

/// Keep full destination names readable without reducing the text scale.
_TabLayout _tabLayout(BuildContext context, double width, double nominal) {
  final style = AppText.badge(Theme.of(context));
  final painters = [
    for (final tab in appTabs)
      TextPainter(
        text: TextSpan(text: _labelForTab(tab.key, context.l10n), style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(),
  ];
  final widest = painters.fold<double>(
    0,
    (value, painter) => math.max(value, painter.width),
  );
  final horizontal = widest > width / appTabs.length - AppSpacing.xs * 2;
  const horizontalGutter = _tabIconExtent + AppSpacing.xsm + AppSpacing.xs * 2;
  final columns = horizontal
      ? widest + horizontalGutter <= width / 2
            ? 2
            : 1
      : appTabs.length;
  final labelWidth = math.max(
    1.0,
    width / columns - (horizontal ? horizontalGutter : AppSpacing.xs * 2),
  );
  var labelHeight = 0.0;
  for (final painter in painters) {
    painter.layout(maxWidth: labelWidth);
    labelHeight = math.max(labelHeight, painter.height);
    painter.dispose();
  }
  final iconBlock = math.max(
    _tabIconExtent,
    tabBadgeExtent(context) + AppSpacing.xxs,
  );
  final needed = horizontal
      ? (math.max(iconBlock, labelHeight) + AppSpacing.sm * 2) *
                (appTabs.length / columns).ceil() +
            AppSpacing.sm * 2
      : iconBlock +
            AppSpacing.xs +
            AppSpacing.xsm +
            labelHeight +
            AppSpacing.md;
  return (
    columns: columns,
    horizontal: horizontal,
    labelHeight: labelHeight,
    height: math.max(nominal, needed),
  );
}
