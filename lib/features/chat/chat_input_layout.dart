part of 'chat_input.dart';

/// Human name for a session flavor, used in the "Ask {agent}…" hint.
String? _composerAgentName(String? flavor) => switch (flavor) {
  'claude' => 'Claude',
  'codex' => 'Codex',
  'opencode' => 'OpenCode',
  'agy' || 'gemini' => 'AgY',
  'pi' => 'pi',
  'prime-agent' => 'Prime Agent',
  'grok' || 'grok-build' => 'Grok',
  'har' => 'Har',
  _ => null,
};

/// Drafts this long get an inline "open full editor" shortcut.
const int _inlineExpandThreshold = 80;

/// Hand-off composer layout: a circular "+" beside a rounded field that
/// names the agent, with dictation inside the field and a send button
/// that only takes the agent's colour once there is something to send.
/// Approvals and model stay one tap away in a quiet summary line.
extension _ChatInputPolishLayout on _ChatInputState {
  Widget _buildHandoffComposer(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final identity = agentIdentityForSeed(
      widget.sessionId,
      brightness: theme.brightness,
      flavor: widget.sessionFlavor,
    );
    final tight = ChatChromeScope.of(context).isTight;

    final pill = ValueListenableBuilder<bool>(
      valueListenable: _isFocused,
      builder: (context, isFocused, child) => AnimatedContainer(
        key: const ValueKey<String>('chat-composer-card'),
        duration: AppMotion.duration(context, kBorderAnimDuration),
        curve: AppCurve.standard,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.xxxl),
          border: Border.all(
            color: isFocused
                ? identity.color.withValues(alpha: AppOpacity.strong)
                : cs.outlineVariant.withValues(alpha: AppOpacity.medium),
            width: isFocused ? AppBorder.thin : AppBorder.hairline,
          ),
        ),
        child: child,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.attachmentController != null)
            _buildAttachmentStrip(context),
          Row(
            key: const ValueKey<String>('chat-composer-input-row'),
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _isDownloadingModel
                    ? ValueListenableBuilder<
                        Map<String, OfflineSttDownloadProgress>
                      >(
                        valueListenable: _dictationService.progress,
                        builder: (context, progressMap, _) => _buildTextField(
                          context,
                          downloadProgress:
                              progressMap[_dictationService.selectedModelId],
                        ),
                      )
                    : _buildTextField(context),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: AppSpacing.xxs,
                  bottom: AppSpacing.xxs,
                ),
                child: _buildInFieldActions(context, identity),
              ),
            ],
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _ComposerPlusButton(onTap: () => _showComposerSheet(context)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: pill),
          ],
        ),
        if (!tight)
          _settingsLine(context)
        else
          ListenableBuilder(
            listenable: Listenable.merge([_isFocused, _sendableListenable]),
            builder: (context, _) => !_isFocused.value && !_hasSendableContent
                ? const SizedBox.shrink()
                : _settingsLine(context),
          ),
      ],
    );
  }

  /// Dictation while the field is empty (or busy recording); expand, queue
  /// and send once there is a draft.
  Widget _buildInFieldActions(BuildContext context, AgentIdentity identity) {
    return ListenableBuilder(
      listenable: _sendableListenable,
      builder: (context, _) {
        final hasContent = _hasSendableContent;
        final dictationBusy =
            _isRecording || _isTranscribing || _isDownloadingModel;
        final showSend = hasContent || widget.isSending;
        final longDraft =
            widget.controller.text.length > _inlineExpandThreshold ||
            widget.controller.text.contains('\n');
        final theme = Theme.of(context);
        final appCs =
            theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
        // The send fill carries the agent's identity colour.
        final tinted = theme.copyWith(
          extensions: [
            ...theme.extensions.values.where((e) => e is! AppColorScheme),
            appCs.copyWith(accentGradient: [identity.color, identity.color]),
          ],
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSend && longDraft)
              ExpandComposerButton(onTap: _openFullscreenComposer),
            if (!showSend || dictationBusy) _dictationButton(),
            if (showSend) ...[
              if (_showFollowUpActions)
                QueueNextTurnButton(
                  key: const ValueKey('chat-follow-up-actions'),
                  isDisabled:
                      widget.isSendDisabled ||
                      widget.isSending ||
                      !_hasSendableContent,
                  onTap: _onQueueNextTurnTap,
                ),
              Theme(
                data: tinted,
                child: SendButton(
                  isSending: widget.isSending,
                  isSendDisabled: widget.isSendDisabled || !hasContent,
                  onTap: _onSendTap,
                  scaleAnimation: _sendScale,
                  lastDeliveryStatus: widget.lastDeliveryStatus,
                  actionLabel: widget.onQueueNextTurn == null
                      ? null
                      : context.l10n.chatUpdateCurrentTurn,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _dictationButton() {
    if (!_isDownloadingModel) {
      return _DictationButton(
        isRecording: _isRecording,
        isTranscribing: _isTranscribing,
        isDownloadingModel: false,
        onTap: _onDictationTap,
      );
    }
    return ValueListenableBuilder<Map<String, OfflineSttDownloadProgress>>(
      valueListenable: _dictationService.progress,
      builder: (context, progressMap, _) => _DictationButton(
        isRecording: _isRecording,
        isTranscribing: _isTranscribing,
        isDownloadingModel: true,
        downloadProgress: progressMap[_dictationService.selectedModelId],
        onTap: _onDictationTap,
      ),
    );
  }

  /// The settings row under the field: approvals and model chips (plus
  /// options on phones, the full lane on desktop). Attach, dictate and
  /// send live in the field row above, so this row stays quiet.
  Widget _settingsLine(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('chat-composer-toolbar'),
      padding: const EdgeInsetsDirectional.only(
        start: AppTouchTarget.comfortable + AppSpacing.xs,
        top: AppSpacing.xxs,
      ),
      child: _settingsLane(
        context,
        compact: MediaQuery.sizeOf(context).width < AppBreakpoint.desktop,
      ),
    );
  }

  String _modelLabel(BuildContext context) {
    final model = widget.modelMode ?? ChatModelMode.defaultModel;
    return widget.resolvedModelLabel ??
        (model == ChatModelMode.defaultModel
            ? context.l10n.polishComposerDefaultModel
            : model.label);
  }

  /// "+" sheet: attachments first, then everything that shapes this
  /// conversation (approvals, model, speed, profile, context, editor).
  Future<void> _showComposerSheet(BuildContext context) async {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canAttach = widget.attachmentController != null && !widget.isSending;
    final showApprovals =
        widget.onPermissionModeChanged != null && widget.sessionFlavor != 'har';
    final mode = widget.permissionMode ?? perm.PermissionMode.defaultMode;
    final modelEnabled =
        widget.onModelModeChanged != null &&
        (widget.availableModels.length > 1 || widget.onRefreshModels != null);
    final context0 = context;

    final action = await showModalBottomSheet<_ComposerSheetAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxxl),
        ),
      ),
      builder: (sheetContext) {
        void pop(_ComposerSheetAction a) => Navigator.of(sheetContext).pop(a);
        Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Semantics(
            header: true,
            child: Text(text, style: AppText.label(theme, cs.onSurfaceVariant)),
          ),
        );
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canAttach) ...[
                  header(l10n.polishComposerAddSection),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ComposerSheetTile(
                            icon: Icons.photo_library_outlined,
                            label: l10n.chatAttachFromGallery,
                            onTap: () => pop(_ComposerSheetAction.gallery),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _ComposerSheetTile(
                            icon: Icons.photo_camera_outlined,
                            label: l10n.chatAttachFromCamera,
                            onTap: () => pop(_ComposerSheetAction.camera),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                header(l10n.polishComposerConversationSection),
                if (showApprovals)
                  ListTile(
                    key: const ValueKey('composer-sheet-approvals'),
                    leading: Icon(
                      mode.icon,
                      color: mode.skipsConfirmation ? mode.color : null,
                    ),
                    title: Text(l10n.polishComposerApprovals),
                    subtitle: Text(mode.localizedDisplayName(l10n)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => pop(_ComposerSheetAction.approvals),
                  ),
                if (widget.sessionFlavor == 'har')
                  ListTile(
                    leading: const Icon(Icons.warning_amber_rounded),
                    title: const Text('Host · approvals disabled'),
                  ),
                ListTile(
                  key: const ValueKey('composer-sheet-model'),
                  enabled: modelEnabled,
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: Text(l10n.polishComposerModel),
                  subtitle: Text(_modelLabel(context0)),
                  trailing: modelEnabled
                      ? const Icon(Icons.chevron_right_rounded)
                      : null,
                  onTap: () => pop(_ComposerSheetAction.model),
                ),
                if (widget.sessionFlavor == 'codex')
                  ListTile(
                    leading: const Icon(Icons.bolt_outlined),
                    title: Text(l10n.codexSpeedTitle),
                    trailing: CodexSpeedSelector(
                      fastMode: widget.codexFastMode,
                      onChanged: widget.isSending
                          ? null
                          : (value) {
                              widget.onCodexFastModeChanged?.call(value);
                              Navigator.of(sheetContext).pop();
                            },
                    ),
                  ),
                if (widget.sessionFlavor != 'har')
                  ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: Text(l10n.polishComposerProfile),
                    subtitle: Text(
                      [
                        widget.selectedProfile?.name ??
                            l10n.chatInputProfileDefault,
                        ?profileBackendHost(widget.selectedProfile),
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => pop(_ComposerSheetAction.profile),
                  ),
                if (widget.contextSize != null &&
                    (widget.contextSize! > 0 ||
                        widget.sessionFlavor == 'prime-agent'))
                  ListTile(
                    leading: const Icon(Icons.data_usage_rounded),
                    title: Text(l10n.chatComposerContext),
                    trailing: ContextSizeIndicator(
                      contextSize: widget.contextSize!,
                      maxContext: widget.sessionFlavor == 'prime-agent'
                          ? widget.maxContext
                          : widget.maxContext ??
                                ContextSizeIndicator.defaultMaxContext,
                      showPercentage: widget.sessionFlavor == 'prime-agent',
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.open_in_full_rounded),
                  title: Text(l10n.polishComposerFullEditor),
                  onTap: () => pop(_ComposerSheetAction.fullEditor),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _ComposerSheetAction.gallery:
        await _attachFrom(_AttachSource.gallery);
      case _ComposerSheetAction.camera:
        await _attachFrom(_AttachSource.camera);
      case _ComposerSheetAction.approvals:
        _showApprovalsSheet();
      case _ComposerSheetAction.model:
        if (widget.onModelModeChanged != null) _showModelPicker(this.context);
      case _ComposerSheetAction.profile:
        _showProfilePicker(this.context);
      case _ComposerSheetAction.fullEditor:
        await _openFullscreenComposer();
    }
  }

  void _showApprovalsSheet() {
    final onChanged = widget.onPermissionModeChanged;
    if (onChanged == null) return;
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxxl),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.permissionModeTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              perm.PermissionModeSettingsList(
                selectedMode:
                    widget.permissionMode ?? perm.PermissionMode.defaultMode,
                availableModes: widget.sessionFlavor == 'codex'
                    ? perm.PermissionModeExtension.codexModes
                    : perm.PermissionModeExtension.claudeAgyModes,
                onModeChanged: (mode) {
                  HapticFeedback.selectionClick();
                  Navigator.of(sheetContext).pop();
                  onChanged(mode);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ComposerSheetAction {
  gallery,
  camera,
  approvals,
  model,
  profile,
  fullEditor,
}

/// Separate circular "+" next to the field (attachments and options).
class _ComposerPlusButton extends StatelessWidget {
  const _ComposerPlusButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = context.l10n.polishComposerMore;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          key: const ValueKey<String>('composer-attach-button'),
          color: cs.surfaceContainerLow,
          shape: CircleBorder(
            side: BorderSide(
              color: cs.outlineVariant.withValues(alpha: AppOpacity.medium),
              width: AppBorder.hairline,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: AppTouchTarget.comfortable,
              child: Icon(
                Icons.add_rounded,
                size: AppIconSize.tab,
                color: cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Big rounded tile in the "+" sheet.
class _ComposerSheetTile extends StatelessWidget {
  const _ComposerSheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            children: [
              Icon(icon, color: cs.onSurface),
              const SizedBox(height: AppSpacing.xsm),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
