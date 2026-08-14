import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// Opens the composer text in a full-screen editor.
///
/// The [controller] is shared with the inline composer, so text and cursor
/// position survive in both directions without any copy step — draft
/// auto-save keeps working through the same listener.
///
/// Resolves to `true` when the user asked to send from the editor; the
/// caller runs its own send path so identity and validation stay in one
/// place.
Future<bool> showFullscreenComposer(
  BuildContext context, {
  required TextEditingController controller,
  required bool isSendDisabled,
}) async {
  final sent = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => FullscreenComposerScreen(
        controller: controller,
        isSendDisabled: isSendDisabled,
      ),
    ),
  );
  return sent ?? false;
}

/// Full-screen editing surface for long prompts.
class FullscreenComposerScreen extends StatelessWidget {
  const FullscreenComposerScreen({
    required this.controller,
    super.key,
    this.isSendDisabled = false,
  });

  /// The inline composer's controller — edits apply to the live draft.
  final TextEditingController controller;

  /// Whether sending is blocked by the session (offline, in flight, …).
  final bool isSendDisabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey<String>('fullscreen-composer-collapse'),
          icon: const Icon(Icons.close_fullscreen_rounded),
          tooltip: l10n.chatComposerCollapse,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(l10n.chatComposerFullscreenTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  textAlignVertical: TextAlignVertical.top,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: l10n.chatInputHint,
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
            _FullscreenComposerBar(
              controller: controller,
              isSendDisabled: isSendDisabled,
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenComposerBar extends StatelessWidget {
  const _FullscreenComposerBar({
    required this.controller,
    required this.isSendDisabled,
  });

  final TextEditingController controller;
  final bool isSendDisabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final text = controller.text;
        final canSend = !isSendDisabled && text.trim().isNotEmpty;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.chatComposerCharacterCount(text.length),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              FilledButton.icon(
                key: const ValueKey<String>('fullscreen-composer-send'),
                onPressed: canSend
                    ? () => Navigator.of(context).pop(true)
                    : null,
                icon: const Icon(
                  Icons.arrow_upward_rounded,
                  size: AppIconSize.md,
                ),
                label: Text(l10n.chatSend),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Opens the full-screen editor from the composer toolbar.
class ExpandComposerButton extends StatelessWidget {
  const ExpandComposerButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).chatComposerExpand;
    return IconButton(
      key: const ValueKey<String>('expand-composer-button'),
      onPressed: onTap,
      tooltip: label,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(
        minWidth: AppTouchTarget.min,
        minHeight: AppTouchTarget.min,
      ),
      iconSize: AppIconSize.md,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      icon: const Icon(Icons.open_in_full_rounded),
    );
  }
}
