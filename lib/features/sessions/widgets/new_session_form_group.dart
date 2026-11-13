import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';

/// Leading inset of every row inside a [NewSessionGroup]: the icon column
/// plus its gap, so hairlines and text line up across fields and tiles.
const double kNewSessionRowTextInset = 52;

/// Horizontal padding that puts a row's 24 px icon in the same column as an
/// [InputDecoration.prefixIcon] (centred in its 48 px box).
const EdgeInsets kNewSessionTilePadding = EdgeInsets.only(
  left: AppSpacing.md,
  right: AppSpacing.lg,
);

/// An inset grouped section: optional header, one rounded surface whose rows
/// are separated by inset hairlines, optional caption below.
class NewSessionGroup extends StatelessWidget {
  const NewSessionGroup({
    required this.children,
    this.header,
    this.footer,
    super.key,
  });

  final String? header;
  final Widget? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rows = <Widget>[];
    for (final child in children) {
      if (rows.isNotEmpty) {
        rows.add(
          Divider(
            height: AppBorder.hairline,
            thickness: AppBorder.hairline,
            indent: kNewSessionRowTextInset,
            color: cs.outlineVariant.withValues(alpha: AppOpacity.strong),
          ),
        );
      }
      rows.add(child);
    }
    final title = header;
    final caption = footer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              bottom: AppSpacing.xsm,
            ),
            child: NewSessionGroupHeader(text: title),
          ),
        Material(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          clipBehavior: Clip.antiAlias,
          // ExpansionTiles draw their own dividers; the group owns them.
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: rows,
            ),
          ),
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: DefaultTextStyle.merge(
              style: AppText.secondary(theme, cs.onSurfaceVariant),
              child: caption,
            ),
          ),
      ],
    );
  }
}

/// Section title above a [NewSessionGroup].
class NewSessionGroupHeader extends StatelessWidget {
  const NewSessionGroupHeader({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Text(text, style: AppText.label(theme)),
    );
  }
}

/// A borderless field that sits inside a [NewSessionGroup] row.
InputDecoration newSessionRowDecoration({
  String? label,
  String? hint,
  IconData? icon,
  Widget? suffixIcon,
  String? errorText,
  TextStyle? errorStyle,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon),
    suffixIcon: suffixIcon,
    errorText: errorText,
    errorMaxLines: 3,
    errorStyle: errorStyle,
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    contentPadding: const EdgeInsets.fromLTRB(
      AppSpacing.xs,
      AppSpacing.sm,
      AppSpacing.lg,
      AppSpacing.sm,
    ),
  );
}

/// Quick-pick chips shown inside a group, under the field they fill, on a
/// single horizontally scrolling line.
class NewSessionRowChips extends StatelessWidget {
  const NewSessionRowChips({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      kNewSessionRowTextInset,
      0,
      AppSpacing.lg,
      AppSpacing.sm,
    ),
    child: Theme(
      // Chips here are dense quick picks: without shrink-wrapping each run
      // reserves a full 48 px tap row and the group balloons.
      data: Theme.of(context).copyWith(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        chipTheme: Theme.of(context).chipTheme.copyWith(
          labelPadding: const EdgeInsets.only(right: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        ),
      ),
      // One scrolling line instead of wrapping into several rows.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0) const SizedBox(width: AppSpacing.xsm),
              child,
            ],
          ],
        ),
      ),
    ),
  );
}
