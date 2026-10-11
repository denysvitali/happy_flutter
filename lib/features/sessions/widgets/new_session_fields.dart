part of 'new_session_dialog.dart';

class _PathField extends ConsumerStatefulWidget {
  const _PathField({
    required this.machineId,
    required this.selectedPath,
    required this.onChanged,
    required this.onSelected,
  });

  final String? machineId;
  final String? selectedPath;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSelected;

  @override
  ConsumerState<_PathField> createState() => _PathFieldState();
}

class _PathFieldState extends ConsumerState<_PathField> {
  late final _controller = TextEditingController(text: widget.selectedPath);
  final _focusNode = FocusNode();

  @override
  void didUpdateWidget(_PathField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPath != oldWidget.selectedPath &&
        _controller.text != (widget.selectedPath ?? '')) {
      final path = widget.selectedPath ?? '';
      _controller.value = TextEditingValue(
        text: path,
        selection: TextSelection.collapsed(offset: path.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsNotifierProvider);
    final paths =
        sessions.values
            .where((session) => session.metadata?.machineId == widget.machineId)
            .map((session) => session.metadata?.path)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    return Autocomplete<String>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        if (value.text.isEmpty) return paths;
        final query = value.text.toLowerCase();
        return paths.where((path) => path.toLowerCase().contains(query));
      },
      onSelected: widget.onSelected,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: context.l10n.sessionPath,
              hintText: context.l10n.sessionPathHint,
              prefixIcon: const Icon(Icons.folder_outlined),
            ),
            onChanged: widget.onChanged,
          ),
    );
  }
}

class _SpawnBackendPicker extends StatelessWidget {
  const _SpawnBackendPicker({
    required this.backends,
    required this.selectedBackend,
    required this.onSelected,
  });

  final List<String> backends;
  final String selectedBackend;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SegmentedButton<String>(
    segments: backends
        .map(
          (backend) => ButtonSegment(
            value: backend,
            label: Text(
              backend == 'kubernetes'
                  ? context.l10n.newSessionSpawnKubernetes
                  : context.l10n.newSessionSpawnLocal,
            ),
            icon: Icon(
              backend == 'kubernetes'
                  ? Icons.cloud_queue_outlined
                  : Icons.computer_outlined,
            ),
          ),
        )
        .toList(growable: false),
    selected: {selectedBackend},
    onSelectionChanged: (selection) => onSelected(selection.first),
  );
}

class _RepositoryUrlField extends ConsumerWidget {
  const _RepositoryUrlField({
    required this.machineId,
    required this.selectedRepoUrl,
    required this.onChanged,
    required this.onSelected,
  });

  final String? machineId;
  final String? selectedRepoUrl;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsNotifierProvider);
    final repoUrls = _repositoryUrlsForMachine(sessions, machineId);

    return Autocomplete<String>(
      key: ValueKey('repo-url-$machineId'),
      optionsBuilder: (textEditingValue) {
        if (repoUrls.isEmpty) return const <String>[];
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return repoUrls;
        return repoUrls.where((url) => url.toLowerCase().contains(query));
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        final value = selectedRepoUrl;
        if (value != null && value.isNotEmpty && controller.text.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (controller.text.isEmpty) {
              controller.text = value;
            }
          });
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: context.l10n.newSessionRepositoryUrl,
            hintText: context.l10n.newSessionRepositoryUrlHint,
            prefixIcon: const Icon(Icons.source_outlined),
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          onChanged: onChanged,
        );
      },
    );
  }
}

List<String> _repositoryUrlsForMachine(
  Map<String, Session> sessions,
  String? machineId,
) {
  final urls = <String>{};
  for (final session in sessions.values) {
    final metadata = session.metadata;
    if (metadata == null) continue;
    if (machineId != null && metadata.machineId != machineId) continue;
    final url = metadata.repoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      urls.add(url);
    }
  }
  return urls.toList()..sort();
}

class _AgentPicker extends StatelessWidget {
  const _AgentPicker({required this.selectedAgent, required this.onSelected});

  final String selectedAgent;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.sessionsAgent,
            style: AppText.label(theme, cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FocusTraversalGroup(
          policy: AppReadingOrderTraversalPolicy(),
          child: Column(
            children: [
              for (var start = 0; start < _agentIds.length; start += 3) ...[
                if (start > 0) const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    for (
                      var i = start;
                      i < start + 3 && i < _agentIds.length;
                      i++
                    ) ...[
                      if (i > start) const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _AgentOption(
                          label: _agentLabel(l10n, _agentIds[i]),
                          agent: _agentIds[i],
                          selected: _agentIds[i] == selectedAgent,
                          onTap: () => onSelected(_agentIds[i]),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AgentOption extends StatelessWidget {
  const _AgentOption({
    required this.label,
    required this.agent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String agent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final borderColor = selected ? cs.primary : cs.outlineVariant;
    final foreground = selected ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    final radius = BorderRadius.circular(AppRadius.sm);

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      child: Material(
        color: selected ? cs.primaryContainer : cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          mouseCursor: SystemMouseCursors.click,
          child: ExcludeSemantics(
            child: Container(
              constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (agent == 'prime-agent')
                    const PrimeAgentLogo(size: AppIconSize.lg)
                  else
                    Icon(
                      _agentIcon(agent),
                      size: AppIconSize.lg,
                      color: foreground,
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppText.badge(theme, foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogRequirementStatus extends StatelessWidget {
  const _DialogRequirementStatus({
    required this.blocker,
    required this.selectedMachineOffline,
  });

  final NewSessionCreateBlocker? blocker;
  final bool selectedMachineOffline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isBlocked = blocker != null;
    final color =
        selectedMachineOffline ||
            blocker == NewSessionCreateBlocker.offlineMachine
        ? cs.error
        : isBlocked
        ? cs.onSurfaceVariant
        : AppColors.success;
    final icon = isBlocked
        ? selectedMachineOffline ||
                  blocker == NewSessionCreateBlocker.offlineMachine
              ? Icons.cloud_off_rounded
              : Icons.info_outline_rounded
        : Icons.check_circle_outline_rounded;

    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(icon, size: AppIconSize.md, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              _dialogRequirementText(l10n, blocker),
              style: AppText.secondary(theme, color),
            ),
          ),
        ),
      ],
    );
  }
}

String _agentLabel(AppLocalizations l10n, String agent) {
  return switch (agent) {
    'codex' => l10n.sessionsCodex,
    'agy' => l10n.sessionsAgy,
    'pi' => l10n.sessionsPi,
    'opencode' => l10n.sessionsOpencode,
    'grok' => l10n.sessionsGrok,
    'har' => 'Har',
    'prime-agent' => 'Prime Agent',
    _ => l10n.sessionsClaude,
  };
}

IconData _agentIcon(String agent) {
  return switch (agent) {
    'codex' => Icons.terminal_rounded,
    'agy' => Icons.auto_awesome_rounded,
    'pi' => Icons.memory_rounded,
    'opencode' => Icons.code_rounded,
    'grok' => Icons.rocket_launch_rounded,
    'har' => Icons.hub_outlined,
    _ => Icons.psychology_alt_rounded,
  };
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({
    required this.isCreating,
    required this.onPressed,
    required this.label,
    required this.tooltip,
  });

  final bool isCreating;
  final VoidCallback? onPressed;
  final String label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: onPressed,
      child: isCreating
          ? const Icon(Icons.hourglass_top_rounded, size: AppIconSize.md)
          : Text(label),
    );
    final tip = tooltip;
    if (tip == null || tip.isEmpty) return button;
    return Tooltip(message: tip, child: button);
  }
}

String _dialogRequirementText(
  AppLocalizations l10n,
  NewSessionCreateBlocker? blocker,
) {
  switch (blocker) {
    case NewSessionCreateBlocker.missingMachine:
      return l10n.sessionNoMachineSelected;
    case NewSessionCreateBlocker.offlineMachine:
      return l10n.machineOfflineUnableToSpawn;
    case NewSessionCreateBlocker.kubernetesUnavailable:
      return l10n.newSessionKubernetesUnavailable;
    case NewSessionCreateBlocker.missingPath:
      return l10n.sessionNoPathSelected;
    case NewSessionCreateBlocker.missingRepository:
      return l10n.newSessionRepositoryRequired;
    case NewSessionCreateBlocker.missingRepositoryRef:
      return l10n.newSessionGitRefRequired;
    case NewSessionCreateBlocker.harLocalBackend:
      return 'Select the local backend for Har.';
    case NewSessionCreateBlocker.creating:
      return l10n.commonCreate;
    case NewSessionCreateBlocker.disconnected:
      return l10n.sessionNotConnectedToServer;
    case NewSessionCreateBlocker.syncNotReady:
      return l10n.authConnecting;
    case null:
      return l10n.newSessionReadyToCreate;
  }
}
