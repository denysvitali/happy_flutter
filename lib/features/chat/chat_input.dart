import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/settings.dart';
import '../../core/services/draft_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'widgets/autocomplete_overlay.dart';
import 'widgets/chat_input_buttons.dart';
import 'widgets/claude_model.dart';
import 'widgets/file_autocomplete.dart';
import 'widgets/input_toolbar.dart';
import 'widgets/permission_mode_selector.dart' as perm;
import 'widgets/picker_sheets.dart';
import 'widgets/slash_commands.dart';

export 'widgets/claude_model.dart' show ClaudeModel;

/// Enhanced chat input with autocomplete, draft
/// persistence, and polished animations.
class ChatInput extends ConsumerStatefulWidget {
  /// Creates a [ChatInput].
  const ChatInput({
    required this.sessionId,
    required this.controller,
    required this.onSend,
    super.key,
    this.isSending = false,
    this.permissionMode,
    this.onPermissionModeChanged,
    this.modelMode,
    this.onModelModeChanged,
    this.availableModels = ClaudeModel.values,
    this.fileSuggestions = const [],
    this.machineName,
    this.currentPath,
    this.onMachinePressed,
    this.onPathPressed,
    this.selectedProfile,
    this.availableProfiles = const [],
    this.onProfileChanged,
    this.profileId,
    this.onProfilePressed,
    this.isSendDisabled = false,
    this.contextSize,
    this.isSessionOnline = false,
    this.isAgentThinking = false,
    this.onAbort,
    this.enterToSend = true,
  });

  /// Stable identifier for the current session
  /// (used for draft storage).
  final String sessionId;

  /// Controller for the message text field.
  final TextEditingController controller;

  /// Called when the user submits a message.
  final VoidCallback onSend;

  /// Whether a message is currently being sent.
  final bool isSending;

  /// Active permission mode, or null for server default.
  final perm.PermissionMode? permissionMode;

  /// Callback invoked when the user changes the
  /// permission mode.
  final ValueChanged<perm.PermissionMode>? onPermissionModeChanged;

  /// Active model selection, or null for server default.
  final ClaudeModel? modelMode;

  /// Callback invoked when the user changes the model.
  final ValueChanged<ClaudeModel>? onModelModeChanged;

  /// Model options available for the current session flavor.
  final List<ClaudeModel> availableModels;

  /// File path suggestions for `@`-autocomplete.
  final List<AutocompleteSuggestion> fileSuggestions;

  /// Display name of the connected machine.
  final String? machineName;

  /// Current working directory path on the machine.
  final String? currentPath;

  /// Called when the machine label is tapped.
  final VoidCallback? onMachinePressed;

  /// Called when the path label is tapped.
  final VoidCallback? onPathPressed;

  /// The currently active AI backend profile,
  /// or null for default.
  final AIBackendProfile? selectedProfile;

  /// All available profiles to show in the picker.
  final List<AIBackendProfile> availableProfiles;

  /// Called when the user selects a profile
  /// (null = default).
  final ValueChanged<AIBackendProfile?>? onProfileChanged;

  /// Profile identifier (reserved for future use).
  final String? profileId;

  /// Called when the profile avatar is tapped.
  final VoidCallback? onProfilePressed;

  /// Whether the send action is disabled.
  final bool isSendDisabled;

  /// Current context window usage in tokens.
  final int? contextSize;

  /// Whether the session CLI is currently connected
  /// (presence == 'online').
  final bool isSessionOnline;

  /// Whether the agent is actively thinking /
  /// processing a request.
  final bool isAgentThinking;

  /// Called when the user taps the abort button.
  final Future<void> Function()? onAbort;

  /// Whether pressing Enter sends the message
  /// (vs inserting a newline).
  final bool enterToSend;

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput>
    with TickerProviderStateMixin {
  _ChatInputState()
    : _draftAutoSave = DraftAutoSave(sessionId: '', onSave: (_) {});
  final FocusNode _focusNode = FocusNode();
  final AutocompleteController _autocompleteController =
      AutocompleteController();
  final DraftAutoSave _draftAutoSave;

  String _previousText = '';
  bool _showAutocomplete = false;
  bool _isFocused = false;
  bool _isAborting = false;

  late final AnimationController _sendScaleController;
  late final Animation<double> _sendScale;

  @override
  void initState() {
    super.initState();
    _draftAutoSave
      ..sessionId = widget.sessionId
      ..onSave = _saveDraft;

    _sendScaleController = AnimationController(
      vsync: this,
      duration: kSendAnimDuration,
      value: 1.0,
    );
    _sendScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _sendScaleController, curve: Curves.easeOutBack),
    );

    _loadDraft();
    widget.controller.addListener(_onTextChanged);
    _focusNode
      ..addListener(_onFocusChanged)
      ..onKeyEvent = _handleFocusKeyEvent;
  }

  @override
  void didUpdateWidget(ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      // Save the OLD session's draft before switching.
      _draftAutoSave
        ..saveNow()
        ..sessionId = widget.sessionId;
      _loadDraft();
    }
  }

  @override
  void dispose() {
    _sendScaleController.dispose();
    _draftAutoSave.dispose();
    widget.controller.removeListener(_onTextChanged);
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  // -----------------------------------------------------------
  // Draft helpers
  // -----------------------------------------------------------

  Future<void> _loadDraft() async {
    final targetSessionId = widget.sessionId;
    final draft =
        await DraftStorage().getDraft(targetSessionId);
    if (targetSessionId != widget.sessionId) return;
    if (draft != null &&
        draft.isNotEmpty &&
        widget.controller.text.isEmpty) {
      widget.controller.text = draft;
      _previousText = draft;
    }
  }

  Future<void> _saveDraft(String draft) async {
    if (draft.trim().isEmpty) {
      await DraftStorage().removeDraft(widget.sessionId);
    } else {
      await DraftStorage().saveDraft(widget.sessionId, draft);
    }
  }

  // -----------------------------------------------------------
  // Event handlers
  // -----------------------------------------------------------

  void _onTextChanged() {
    final currentText = widget.controller.text;
    _updateAutocomplete(currentText);

    if (DraftStateTransition.isStateTransition(_previousText, currentText)) {
      _draftAutoSave.saveNow();
    } else if (currentText.trim().isNotEmpty) {
      _draftAutoSave.update(currentText);
    }

    _previousText = currentText;
  }

  void _updateAutocomplete(String text) {
    final cursorPosition = widget.controller.selection.base.offset;
    if (cursorPosition < 0) {
      _clearAutocomplete();
      return;
    }

    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastWordMatch = RegExp(r'[@/](\w*)$').firstMatch(textBeforeCursor);

    if (lastWordMatch == null) {
      _clearAutocomplete();
      return;
    }

    final trigger = lastWordMatch.group(0)!.substring(0, 1);
    final query = lastWordMatch.group(1) ?? '';

    if (trigger == '@') {
      final suggestions = widget.fileSuggestions
          .where((s) => s.label.toLowerCase().contains(query.toLowerCase()))
          .toList();
      _autocompleteController.setSuggestions(suggestions, query);
      setState(() => _showAutocomplete = suggestions.isNotEmpty);
    } else if (trigger == '/') {
      final suggestions = slashCommands
          .where((c) => c.command.toLowerCase().contains(query.toLowerCase()))
          .map(
            (c) => AutocompleteSuggestion(
              id: c.command,
              label: c.command,
              description: c.description,
              icon: c.icon,
              type: SuggestionType.command,
            ),
          )
          .toList();
      _autocompleteController.setSuggestions(suggestions, query);
      setState(() => _showAutocomplete = suggestions.isNotEmpty);
    } else {
      _clearAutocomplete();
    }
  }

  void _clearAutocomplete() {
    _autocompleteController.clear();
    setState(() => _showAutocomplete = false);
  }

  void _onFocusChanged() {
    setState(() => _isFocused = _focusNode.hasFocus);
    if (!_focusNode.hasFocus) _draftAutoSave.saveNow();
  }

  void _applySuggestion(AutocompleteSuggestion suggestion) {
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.base.offset;
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastWordMatch = RegExp(r'[@/](\w*)$').firstMatch(textBeforeCursor);

    if (lastWordMatch != null) {
      final startIndex = lastWordMatch.start;
      final trigger = suggestion.type == SuggestionType.command ? '/' : '@';
      final replacement = '$trigger${suggestion.label} ';
      final newText = text.replaceRange(
        startIndex,
        cursorPosition,
        replacement,
      );
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: startIndex + replacement.length,
        ),
      );
    }

    _clearAutocomplete();
    _focusNode.requestFocus();
  }

  KeyEventResult _handleFocusKeyEvent(FocusNode node, KeyEvent event) {
    if (!_showAutocomplete) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _autocompleteController.moveSelectionUp();
      setState(() {});
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _autocompleteController.moveSelectionDown();
      setState(() {});
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      final selected = _autocompleteController.selectedSuggestion;
      if (selected != null) {
        _applySuggestion(selected);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _clearAutocomplete();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onSendTap() {
    if (widget.isSendDisabled || widget.isSending) {
      return;
    }
    HapticFeedback.mediumImpact();
    _sendScaleController
      ..value = 0.0
      ..forward();
    widget.onSend();
  }

  Future<void> _onAbortTap() async {
    if (_isAborting || widget.onAbort == null) return;
    unawaited(HapticFeedback.heavyImpact());
    setState(() => _isAborting = true);
    final start = DateTime.now();
    try {
      await widget.onAbort!();
    } catch (_) {
      // Ignore — the caller logs errors.
    } finally {
      final elapsed = DateTime.now().difference(start);
      const minDuration = Duration(milliseconds: 300);
      if (elapsed < minDuration) {
        await Future<void>.delayed(minDuration - elapsed);
      }
      if (mounted) setState(() => _isAborting = false);
    }
  }

  // -----------------------------------------------------------
  // Build
  // -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.machineName != null || widget.currentPath != null)
          const SizedBox.shrink(),
        if (_showAutocomplete)
          FileAutocomplete(
            suggestions: _autocompleteController.suggestions,
            selectedIndex: _autocompleteController.selectedIndex,
            onSelect: (index) {
              _applySuggestion(_autocompleteController.suggestions[index]);
            },
          ),
        _buildInputContainer(context),
      ],
    );
  }

  Widget _buildInputContainer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cs.surface.withValues(alpha: 0.6),
                cs.surface.withValues(alpha: 0.95),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCardInputArea(context),
                  const SizedBox(height: AppSpacing.smd),
                  InputToolbar(
                    permissionMode: widget.permissionMode,
                    onPermissionModeChanged: widget.onPermissionModeChanged,
                    modelMode: widget.modelMode,
                    availableModels: widget.availableModels,
                    onShowModelPicker: () => widget.onModelModeChanged != null
                        ? _showModelPicker(context)
                        : null,
                    selectedProfile: widget.selectedProfile,
                    onShowProfilePicker: () => _showProfilePicker(context),
                    contextSize: widget.contextSize,
                    showAbort: widget.isAgentThinking,
                    isAborting: _isAborting,
                    onAbort: _onAbortTap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardInputArea(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final borderColor = _isFocused
        ? cs.primary.withValues(alpha: 0.4)
        : cs.outlineVariant.withValues(alpha: 0.4);
    final cardColor = cs.surfaceContainerLow;

    return AnimatedContainer(
      duration: kBorderAnimDuration,
      curve: AppCurve.standard,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xs,
              ),
              child: _buildTextField(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xsm),
            child: SendButton(
              isSending: widget.isSending,
              isSendDisabled: widget.isSendDisabled,
              onTap: _onSendTap,
              scaleAnimation: _sendScale,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hintColor = cs.onSurface.withValues(
      alpha: AppOpacity.medium,
    );
    final l10n = AppLocalizations.of(context);

    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      decoration: InputDecoration(
        hintText: l10n.chatInputHint,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(color: hintColor),
        filled: false,
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
        ),
      ),
      style: theme.textTheme.bodyMedium,
      textAlignVertical: TextAlignVertical.center,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      enableSuggestions: true,
      autocorrect: true,
      maxLines: 6,
      minLines: 1,
      textInputAction: widget.enterToSend
          ? TextInputAction.send
          : TextInputAction.newline,
      onSubmitted: widget.enterToSend
          ? (_) => widget.onSend()
          : null,
    );
  }

  void _showModelPicker(BuildContext context) {
    final current = widget.modelMode ?? ClaudeModel.defaultModel;
    showModelPickerSheet(
      context,
      current,
      widget.availableModels,
      (model) => widget.onModelModeChanged?.call(model),
    );
  }

  void _showProfilePicker(BuildContext context) {
    showProfilePickerSheet(
      context,
      widget.selectedProfile,
      widget.availableProfiles,
      (profile) => widget.onProfileChanged?.call(profile),
    );
  }
}
