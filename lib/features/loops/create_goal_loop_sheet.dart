import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/app_status_dot.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/remote_feature_failure_localization.dart';
import '../../core/models/loop.dart';
import '../../core/models/machine.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/goal_loops_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Bottom sheet for starting a goal loop.
///
/// A goal loop needs three things the user must supply — a machine, a
/// directory, and a goal — and nothing else: everything below the divider has
/// a working default. The goal field is the important one, so it gets the
/// most room and the explanatory copy.
class CreateGoalLoopSheet extends ConsumerStatefulWidget {
  const CreateGoalLoopSheet({
    super.key,
    this.initialMachineId,
    this.initialDirectory,
  });

  final String? initialMachineId;
  final String? initialDirectory;

  /// Shows the sheet and returns the loop that was created, or null if the
  /// user dismissed it.
  static Future<Loop?> show(
    BuildContext context, {
    String? initialMachineId,
    String? initialDirectory,
  }) {
    return showModalBottomSheet<Loop>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CreateGoalLoopSheet(
        initialMachineId: initialMachineId,
        initialDirectory: initialDirectory,
      ),
    );
  }

  @override
  ConsumerState<CreateGoalLoopSheet> createState() =>
      _CreateGoalLoopSheetState();
}

class _CreateGoalLoopSheetState extends ConsumerState<CreateGoalLoopSheet> {
  final _goalController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _modelController = TextEditingController();
  final _progressFileController = TextEditingController();

  String? _machineId;
  String _directory = '';
  String _agent = 'claude';
  int _maxIterations = 25;
  bool _showAdvanced = false;
  bool _submitting = false;
  String? _error;

  static const _agents = <String>[
    'claude',
    'codex',
    'gemini',
    'opencode',
    'grok',
  ];

  @override
  void initState() {
    super.initState();
    _machineId = widget.initialMachineId;
    _directory = widget.initialDirectory ?? '';
  }

  @override
  void dispose() {
    _goalController.dispose();
    _instructionsController.dispose();
    _modelController.dispose();
    _progressFileController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting &&
      _machineId != null &&
      _directory.trim().isNotEmpty &&
      _goalController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final res = await ref
        .read(goalLoopsNotifierProvider.notifier)
        .create(
          machineId: _machineId!,
          goal: _goalController.text.trim(),
          directory: _directory.trim(),
          agent: _agent,
          model: _modelController.text.trim(),
          progressFile: _progressFileController.text.trim(),
          maxIterations: _maxIterations,
          extraInstructions: _instructionsController.text.trim(),
        );
    if (!mounted) return;
    if (!res.success) {
      setState(() {
        _submitting = false;
        _error = res.failureKind.localizedRemoteFeatureFailure(context.l10n);
      });
      return;
    }
    Navigator.of(context).pop(res.loop);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final now = DateTime.now().millisecondsSinceEpoch;
    final machines = ref.watch(machinesNotifierProvider).values.toList()
      ..sort((a, b) => compareMachinesByAvailabilityAt(now, a, b));

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, color: cs.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.goalLoopsCreateTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.goalLoopsCreateSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            TextField(
              key: const ValueKey('goal-loop-goal'),
              controller: _goalController,
              minLines: 3,
              maxLines: 6,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.goalLoopsGoalLabel,
                hintText: l10n.goalLoopsGoalHint,
                helperText: l10n.goalLoopsGoalHelper,
                helperMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (machines.isEmpty)
              Text(l10n.newSessionNoMachinesFound)
            else
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: l10n.sessionMachine),
                initialValue: _machineId,
                isExpanded: true,
                items: machines.map((machine) {
                  final online = machine.isOnlineAt(now);
                  return DropdownMenuItem(
                    value: machine.id,
                    enabled: online,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppStatusDot(
                          color: online
                              ? AppColors.success
                              : cs.onSurfaceVariant,
                          size: 8,
                          semanticLabel: online
                              ? l10n.machineOnline
                              : l10n.machineOffline,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            machine.displayLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  final machine = ref.read(machinesNotifierProvider)[value];
                  if (machine != null && !machine.isOnlineAt(now)) return;
                  setState(() {
                    if (_machineId != value) _directory = '';
                    _machineId = value;
                    _error = null;
                  });
                },
              ),
            const SizedBox(height: AppSpacing.lg),

            Autocomplete<String>(
              key: ValueKey(_machineId),
              optionsBuilder: (value) {
                final paths = _knownPathsForMachine(_machineId);
                if (value.text.isEmpty) return paths;
                return paths.where(
                  (p) => p.toLowerCase().contains(value.text.toLowerCase()),
                );
              },
              onSelected: (value) => setState(() => _directory = value),
              fieldViewBuilder: (context, controller, focusNode, _) {
                if (_directory.isNotEmpty && controller.text.isEmpty) {
                  controller.text = _directory;
                }
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: l10n.sessionPath,
                    hintText: l10n.sessionPathHint,
                    helperText: l10n.goalLoopsDirectoryHelper,
                    helperMaxLines: 2,
                  ),
                  onChanged: (value) => setState(() {
                    _directory = value;
                    _error = null;
                  }),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),

            _AdvancedSection(
              expanded: _showAdvanced,
              onToggle: () => setState(() => _showAdvanced = !_showAdvanced),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: l10n.sessionsAgent),
                    initialValue: _agent,
                    items: _agents
                        .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                        .toList(),
                    onChanged: (v) => setState(() => _agent = v ?? 'claude'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    key: const ValueKey('goal-loop-model'),
                    controller: _modelController,
                    decoration: InputDecoration(
                      labelText: l10n.goalLoopsModelLabel,
                      hintText: l10n.goalLoopsModelHint,
                      helperText: l10n.goalLoopsModelHelper,
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.goalLoopsMaxIterations(_maxIterations),
                    style: theme.textTheme.bodyMedium,
                  ),
                  Slider(
                    value: _maxIterations.toDouble(),
                    min: 1,
                    max: 100,
                    divisions: 99,
                    label: '$_maxIterations',
                    onChanged: (v) =>
                        setState(() => _maxIterations = v.round()),
                  ),
                  Text(
                    l10n.goalLoopsMaxIterationsHelper,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _progressFileController,
                    decoration: InputDecoration(
                      labelText: l10n.goalLoopsProgressFileLabel,
                      hintText: 'PROGRESS.md',
                      helperText: l10n.goalLoopsProgressFileHelper,
                      helperMaxLines: 3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _instructionsController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: l10n.goalLoopsInstructionsLabel,
                      hintText: l10n.goalLoopsInstructionsHint,
                      helperText: l10n.goalLoopsInstructionsHelper,
                      helperMaxLines: 2,
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: _canSubmit ? _submit : null,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(l10n.goalLoopsStartButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Directories the user has already run sessions in on this machine — the
  /// only path suggestions the app can offer without a remote listing.
  List<String> _knownPathsForMachine(String? machineId) {
    if (machineId == null) return const <String>[];
    final sessions = ref.read(sessionsNotifierProvider);
    return sessions.values
        .where((s) => s.metadata?.machineId == machineId)
        .map((s) => s.metadata?.path)
        .whereType<String>()
        .toSet()
        .toList(growable: false);
  }
}

/// Collapsible "everything with a sane default" section.
class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: onToggle,
          icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
          label: Text(l10n.goalLoopsAdvanced),
        ),
        if (expanded) ...[const SizedBox(height: AppSpacing.sm), child],
      ],
    );
  }
}
