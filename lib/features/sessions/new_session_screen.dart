import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/websocket_client.dart' show ConnectionStatus;
import '../../core/i18n/app_localizations.dart';
import '../../core/models/machine.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';

/// Full screen for creating a new session.
class NewSessionScreen extends ConsumerStatefulWidget {
  const NewSessionScreen({super.key});

  @override
  ConsumerState<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends ConsumerState<NewSessionScreen> {
  Machine? _selectedMachine;
  final _pathController = TextEditingController();
  bool _isCreating = false;
  String _selectedAgent = 'claude';

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsNotifierProvider);
    _selectedAgent = settings.lastUsedAgent ?? 'claude';
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  bool _canCreate(ConnectionStatus connectionStatus) =>
      _selectedMachine != null &&
      _pathController.text.trim().isNotEmpty &&
      !_isCreating &&
      connectionStatus == ConnectionStatus.connected;

  Future<void> _createSession() async {
    final machine = _selectedMachine;
    final path = _pathController.text.trim();
    if (machine == null || path.isEmpty) return;

    setState(() => _isCreating = true);

    try {
      await sync.applySettings({'lastUsedAgent': _selectedAgent});
      final sessionId = await sync.createSession(
        machineId: machine.id,
        path: path,
      );
      if (!mounted) return;
      ref.read(sessionsNotifierProvider.notifier).loadFromSync();
      unawaited(context.push('/chat/$sessionId'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    }
  }

  Future<void> _pickMachine() async {
    final result = await context.pushNamed<Machine>('pick-machine');
    if (result != null) {
      setState(() {
        _selectedMachine = result;
      });
    }
  }

  Future<void> _pickPath() async {
    final machineId = _selectedMachine?.id;
    final result = await context.pushNamed<String>(
      'pick-path',
      queryParameters: machineId != null
          ? {'machineId': machineId}
          : const {},
    );
    if (result != null) {
      setState(() {
        _pathController.text = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final machines = ref
        .watch(machinesNotifierProvider)
        .values
        .where((m) => m.active)
        .toList();
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newSessionTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Machine selector
          Text(
            l10n.sessionMachine,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (machines.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.newSessionNoMachinesFound,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _pickMachine,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.computer_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _selectedMachine == null
                            ? Text(
                                l10n.sessionSelectMachine,
                                style: TextStyle(
                                  color:
                                      theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                            : Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedMachine!.metadata
                                            ?.displayName ??
                                        _selectedMachine!.metadata
                                            ?.host ??
                                        _selectedMachine!.id,
                                    style:
                                        theme.textTheme.bodyMedium,
                                  ),
                                  if (_selectedMachine!
                                          .metadata?.host !=
                                      null)
                                    Text(
                                      _selectedMachine!.metadata!.host,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Path input
          Text(
            l10n.sessionPath,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _pathController,
                    decoration: InputDecoration(
                      hintText: l10n.sessionPathHint,
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.folder_outlined),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_selectedMachine != null)
                  InkWell(
                    onTap: _pickPath,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder_open_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Browse paths...',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Agent selector
          Text(
            'Agent',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'claude',
                label: Text('Claude'),
              ),
              ButtonSegment(
                value: 'codex',
                label: Text('Codex'),
              ),
              ButtonSegment(
                value: 'gemini',
                label: Text('Gemini'),
              ),
            ],
            selected: {_selectedAgent},
            onSelectionChanged: (selection) {
              setState(() => _selectedAgent = selection.first);
            },
          ),
          const SizedBox(height: 32),

          // Connection status hint when not yet connected
          if (connectionStatus != ConnectionStatus.connected &&
              connectionStatus != ConnectionStatus.error)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                connectionStatus == ConnectionStatus.connecting
                    ? 'Connecting to server...'
                    : 'Not connected to server',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Create button
          FilledButton(
            onPressed:
                _canCreate(connectionStatus) ? _createSession : null,
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.commonCreate),
          ),
        ],
      ),
    );
  }
}
