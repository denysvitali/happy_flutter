import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/codex_cyber_access.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/codex_daybreak_selection.dart';
import '../../../core/theme/app_tokens.dart';
import 'codex_daybreak_status.dart';
import 'composer_selector_chip.dart';

/// Label for a Daybreak [choice] in the picker and pending chip.
String codexDaybreakChoiceLabel(
  AppLocalizations l10n,
  CodexDaybreakChoice choice,
) => switch (choice) {
  CodexDaybreakChoice.machine => l10n.daybreakChoiceMachine,
  CodexDaybreakChoice.off => l10n.daybreakChoiceOff,
  CodexDaybreakChoice.blue => l10n.daybreakChoiceBlue,
  CodexDaybreakChoice.red => l10n.daybreakChoiceRed,
  CodexDaybreakChoice.standard => l10n.daybreakChoiceStandard,
};

/// The choice the next message will send, or null when it sends none.
CodexDaybreakChoice? codexDaybreakOutgoingChoice({
  required CodexDaybreakChoice? saved,
  required bool daybreakByDefault,
  required CodexCyberAccess? status,
}) {
  if (saved != null) return saved;
  if (daybreakByDefault && status?.source != 'session') {
    return CodexDaybreakChoice.blue;
  }
  return null;
}

/// Whether [choice] is already what the running session uses.
bool codexDaybreakChoiceApplied(
  CodexDaybreakChoice choice,
  CodexCyberAccess? status,
) {
  if (status == null) return false;
  if (choice == CodexDaybreakChoice.machine) {
    return status.source != 'session';
  }
  return status.source == 'session' &&
      CodexDaybreakChoice.fromProgram(status.requested) == choice;
}

/// Composer chip that shows and switches a Codex session's Daybreak
/// program. The choice travels with the next message
/// (`meta.codexCyberAccessProgram`); happy-cli-go applies it per turn.
class CodexDaybreakSelector extends ConsumerStatefulWidget {
  const CodexDaybreakSelector({
    required this.sessionId,
    this.enabled = true,
    this.onChanged,
    super.key,
  });

  final String sessionId;
  final bool enabled;

  /// Called after a new choice is saved (e.g. to close a parent sheet).
  final VoidCallback? onChanged;

  @override
  ConsumerState<CodexDaybreakSelector> createState() =>
      _CodexDaybreakSelectorState();
}

class _CodexDaybreakSelectorState extends ConsumerState<CodexDaybreakSelector> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = ref.watch(
      sessionsNotifierProvider.select(
        (sessions) => sessions[widget.sessionId]?.metadata?.codexCyberAccess,
      ),
    );
    final daybreakByDefault = ref.watch(
      settingsNotifierProvider.select((s) => s.codexDaybreak),
    );
    final outgoing = codexDaybreakOutgoingChoice(
      saved: CodexDaybreakSelection().read(widget.sessionId),
      daybreakByDefault: daybreakByDefault,
      status: status,
    );
    final pending =
        outgoing != null && !codexDaybreakChoiceApplied(outgoing, status);
    final label = pending
        ? l10n.daybreakPendingNextMessage(
            codexDaybreakChoiceLabel(l10n, outgoing),
          )
        : status != null
        ? codexDaybreakLabel(l10n, status)
        : l10n.daybreakTitle;
    final warning =
        !pending &&
        (status?.state == CodexCyberAccessState.unavailable ||
            status?.state == CodexCyberAccessState.unsupported);
    final onTap = widget.enabled ? () => _showPicker(status, outgoing) : null;
    return Semantics(
      button: true,
      enabled: onTap != null,
      onTap: onTap,
      label: '${l10n.daybreakTitle}: $label',
      excludeSemantics: true,
      child: ComposerSelectorChip(
        key: const ValueKey('codex-daybreak-selector'),
        icon: status == null
            ? Icons.shield_outlined
            : codexDaybreakIcon(status),
        label: label,
        warning: warning,
        onTap: onTap,
      ),
    );
  }

  Future<void> _showPicker(
    CodexCyberAccess? status,
    CodexDaybreakChoice? outgoing,
  ) async {
    final l10n = context.l10n;
    final current =
        outgoing ??
        (status?.source == 'session'
            ? CodexDaybreakChoice.fromProgram(status!.requested)
            : CodexDaybreakChoice.machine);
    final machine = status?.machine ?? '';
    String? description(CodexDaybreakChoice choice) => switch (choice) {
      CodexDaybreakChoice.machine =>
        machine.isEmpty
            ? l10n.daybreakChoiceMachineNone
            : l10n.daybreakMachineProgram(machine),
      CodexDaybreakChoice.off => l10n.daybreakChoiceOffDescription,
      CodexDaybreakChoice.blue => l10n.daybreakChoiceBlueDescription,
      CodexDaybreakChoice.red => l10n.daybreakChoiceRedDescription,
      CodexDaybreakChoice.standard => l10n.daybreakChoiceStandardDescription,
    };
    final selected = await showModalBottomSheet<CodexDaybreakChoice>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.daybreakTitle,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.daybreakSelectorHint),
            for (final choice in CodexDaybreakChoice.values)
              ListTile(
                key: ValueKey('codex-daybreak-choice-${choice.name}'),
                title: Text(codexDaybreakChoiceLabel(l10n, choice)),
                subtitle: switch (description(choice)) {
                  final text? => Text(text),
                  null => null,
                },
                selected: choice == current,
                trailing: choice == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheetContext, choice),
              ),
            if (status != null && status.detail.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                status.detail,
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted || selected == null || selected == current) return;
    CodexDaybreakSelection().save(widget.sessionId, selected);
    setState(() {});
    widget.onChanged?.call();
  }
}
