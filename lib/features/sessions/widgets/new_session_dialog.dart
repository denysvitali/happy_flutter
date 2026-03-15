import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/socket_io_client.dart'
    show ConnectionStatus;
import '../../../core/i18n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_tokens.dart';

/// New session dialog.
class NewSessionDialog extends ConsumerStatefulWidget {
  const NewSessionDialog({super.key});

  @override
  ConsumerState<NewSessionDialog> createState() =>
      _NewSessionDialogState();
}

class _NewSessionDialogState
    extends ConsumerState<NewSessionDialog> {
  String? _selectedPath;
  String? _selectedMachine;
  bool _isCreating = false;
  String? _createError;
  String _selectedAgent = 'claude';
  String _sessionType = 'simple';

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsNotifierProvider);
    _selectedAgent = settings.lastUsedAgent ?? 'claude';
    Future<void>.microtask(
      () => ref
          .read(machinesNotifierProvider.notifier)
          .refreshFromSync(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final connectionStatus =
        ref.watch(connectionNotifierProvider);
    final machines = ref
        .watch(machinesNotifierProvider)
        .values
        .where((m) => m.active)
        .toList();

    return AlertDialog(
      title: Text(l10n.newSessionTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (machines.isEmpty)
            Text(l10n.newSessionNoMachinesFound)
          else
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: l10n.sessionMachine,
              ),
              initialValue: _selectedMachine,
              isExpanded: true,
              selectedItemBuilder: (context) => [
                Text(
                  l10n.sessionSelectMachine,
                  overflow: TextOverflow.ellipsis,
                ),
                ...machines.map(
                  (machine) => Text(
                    machine.metadata?.displayName ??
                        machine.metadata?.host ??
                        machine.id,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.sessionSelectMachine),
                ),
                ...machines.map(
                  (machine) => DropdownMenuItem(
                    value: machine.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.computer,
                          size: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            machine.metadata?.displayName ??
                                machine.metadata?.host ??
                                machine.id,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedMachine = value;
                });
              },
            ),
          const SizedBox(height: AppSpacing.lg),
          Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              if (_selectedMachine == null) return const [];
              final sessions =
                  ref.read(sessionsNotifierProvider);
              final paths = sessions.values
                  .where(
                    (s) =>
                        s.metadata?.machineId ==
                        _selectedMachine,
                  )
                  .map((s) => s.metadata?.path)
                  .whereType<String>()
                  .toSet()
                  .toList();
              if (textEditingValue.text.isEmpty) {
                return paths;
              }
              return paths.where(
                (p) => p.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    ),
              );
            },
            onSelected: (value) {
              setState(() => _selectedPath = value);
            },
            fieldViewBuilder: (
              context,
              controller,
              focusNode,
              onFieldSubmitted,
            ) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: l10n.sessionPath,
                  hintText: l10n.sessionPathHint,
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedPath = value;
                    _createError = null;
                  });
                },
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'simple',
                label: Text(l10n.sessionsSimple),
                icon: const Icon(Icons.folder_outlined),
              ),
              ButtonSegment(
                value: 'worktree',
                label: Text(l10n.sessionsWorktree),
                icon: const Icon(
                  Icons.account_tree_outlined,
                ),
              ),
            ],
            selected: {_sessionType},
            onSelectionChanged: (selection) {
              setState(
                () => _sessionType = selection.first,
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'claude',
                label: Text(l10n.sessionsClaude),
              ),
              ButtonSegment(
                value: 'codex',
                label: Text(l10n.sessionsCodex),
              ),
              ButtonSegment(
                value: 'gemini',
                label: Text(l10n.sessionsGemini),
              ),
            ],
            selected: {_selectedAgent},
            onSelectionChanged: (selection) {
              setState(
                () => _selectedAgent = selection.first,
              );
            },
          ),
          if (_createError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _createError!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: !_isCreating &&
                  (_selectedPath?.isNotEmpty ?? false) &&
                  _selectedMachine != null &&
                  connectionStatus ==
                      ConnectionStatus.connected &&
                  sync.isInitialized
              ? () => _createSession(context)
              : null,
          child: _isCreating
              ? const SizedBox(
                  width: AppSpacing.lg,
                  height: AppSpacing.lg,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Text(l10n.commonCreate),
        ),
      ],
    );
  }

  Future<void> _createSession(BuildContext context) async {
    final machineId = _selectedMachine;
    final path = _selectedPath?.trim();
    if (machineId == null || path == null || path.isEmpty) {
      return;
    }
    final navigator =
        Navigator.of(context, rootNavigator: true);

    setState(() {
      _isCreating = true;
      _createError = null;
    });

    try {
      await sync.applySettings(
        {'lastUsedAgent': _selectedAgent},
      );
      final String sessionPath;
      if (_sessionType == 'worktree') {
        sessionPath = await sync.createWorktree(
          machineId: machineId,
          basePath: path,
        );
      } else {
        sessionPath = path;
      }
      final sessionId = await sync.createSession(
        machineId: machineId,
        path: sessionPath,
      );
      if (!mounted) return;
      await ref
          .read(sessionsNotifierProvider.notifier)
          .refreshFromSync();
      if (!mounted) return;
      navigator.pop(sessionId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _createError =
            e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }
}
