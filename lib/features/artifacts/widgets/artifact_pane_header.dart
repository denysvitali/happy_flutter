import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Compact header shown at the top of an embedded artifact pane. Mirrors the
/// AppBar visual language using design tokens (no explicit hex colors).
///
/// Shared by the artifact detail, create, and edit screens, which each carried
/// a copy of this chrome differing only in the trailing actions.
class ArtifactPaneHeader extends StatelessWidget {
  const ArtifactPaneHeader({
    required this.title,
    this.onClose,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;

  /// Trailing widgets rendered before the close button.
  final List<Widget> actions;

  /// Hides the close button when null.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: AppOpacity.half),
            width: AppBorder.hairline,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                ...actions,
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: AppLocalizations.of(context).commonClose,
                    onPressed: onClose,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Save / Create text button that swaps its label for a spinner while the
/// mutation is in flight. Used in [ArtifactPaneHeader.actions].
class ArtifactBusyTextButton extends StatelessWidget {
  const ArtifactBusyTextButton({
    required this.label,
    required this.isBusy,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool isBusy;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: TextButton(
        onPressed: isBusy ? null : onPressed,
        child: isBusy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
