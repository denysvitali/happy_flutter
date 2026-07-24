import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// Thin in-pane header used when a screen renders as a pane inside the
/// tablet master-detail layout instead of as a pushed route.
///
/// Replaces six near-identical private headers that had drifted apart in
/// `session_files_screen`, `session_recent_screen`, `session_info_screen`,
/// `message_detail_screen`, `session_file_viewer_screen`, and
/// `agent_conversation_screen`.
class EmbeddedPaneHeader extends StatelessWidget {
  const EmbeddedPaneHeader({
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.showProgress = false,
    this.onClose,
    super.key,
  });

  /// Primary label shown on the leading edge.
  final String title;

  /// Optional secondary label rendered under [title].
  final String? subtitle;

  /// Trailing widgets rendered before the close button.
  final List<Widget> actions;

  /// When true, shows a small spinner before [actions].
  final bool showProgress;

  /// Called when the close button is tapped. The button is hidden when null.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleText = subtitle;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: AppBorder.hairline,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitleText != null)
                  Text(
                    subtitleText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (showProgress)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ...actions,
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              // TODO(i18n): close tooltip not yet localized
              tooltip: 'Close',
              onPressed: onClose,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// Renders [body] either as a pushed route (Scaffold + AppBar) or as a
/// master-detail pane (thin [EmbeddedPaneHeader] + body column).
///
/// Every session detail screen needs both modes; before this existed each
/// one hand-rolled the same `if (!embedded) Scaffold(...) else Column(...)`
/// branch.
class EmbeddedPaneShell extends StatelessWidget {
  const EmbeddedPaneShell({
    required this.title,
    required this.body,
    required this.embedded,
    this.subtitle,
    this.appBarActions = const <Widget>[],
    this.headerActions = const <Widget>[],
    this.showProgress = false,
    this.onClose,
    super.key,
  });

  /// Title shown in the app bar (route mode) or header (embedded mode).
  final String title;

  /// Optional secondary label; embedded mode only.
  final String? subtitle;

  /// The pane content.
  final Widget body;

  /// When true, render as an embedded pane instead of a route.
  final bool embedded;

  /// Trailing app-bar widgets used in route mode.
  final List<Widget> appBarActions;

  /// Trailing header widgets used in embedded mode.
  final List<Widget> headerActions;

  /// Shows a spinner in the embedded header.
  final bool showProgress;

  /// Embedded-mode close callback.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    if (!embedded) {
      final theme = Theme.of(context);
      final subtitleText = subtitle;
      return Scaffold(
        appBar: AppBar(
          title: subtitleText == null
              ? Text(title, overflow: TextOverflow.ellipsis)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      subtitleText,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
          actions: [
            if (showProgress)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.lg),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ...appBarActions,
          ],
        ),
        body: body,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmbeddedPaneHeader(
          title: title,
          subtitle: subtitle,
          actions: headerActions,
          showProgress: showProgress,
          onClose: onClose,
        ),
        Expanded(child: body),
      ],
    );
  }
}
