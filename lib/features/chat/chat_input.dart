import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/draft_storage.dart';
import 'widgets/autocomplete_overlay.dart';
import 'widgets/permission_mode_selector.dart' as perm;

/// Slash command suggestions
final class SlashCommand {
  /// Creates a slash command entry.
  const SlashCommand({
    required this.command,
    required this.description,
    required this.icon,
  });

  /// The slash command name, e.g. `test`.
  final String command;

  /// Short human-readable description.
  final String description;

  /// Icon to display alongside this command.
  final IconData icon;
}

/// Available slash commands
const List<SlashCommand> _slashCommands = [
  SlashCommand(
    command: 'test',
    description: 'Run tests',
    icon: Icons.check_circle_outline,
  ),
  SlashCommand(
    command: 'lint',
    description: 'Run linter',
    icon: Icons.warning_amber_outlined,
  ),
  SlashCommand(
    command: 'review',
    description: 'Code review',
    icon: Icons.rate_review_outlined,
  ),
  SlashCommand(
    command: 'explain',
    description: 'Explain code',
    icon: Icons.info_outline,
  ),
  SlashCommand(
    command: 'refactor',
    description: 'Refactor code',
    icon: Icons.restart_alt_outlined,
  ),
  SlashCommand(
    command: 'docs',
    description: 'Generate docs',
    icon: Icons.description_outlined,
  ),
];

/// Model options for Claude sessions.
enum ClaudeModel {
  /// Use the server-configured default model.
  defaultModel,

  /// Claude Sonnet.
  sonnet,

  /// Claude Opus.
  opus;

  /// Human-readable label shown in the UI.
  String get label => switch (this) {
    ClaudeModel.defaultModel => 'Default',
    ClaudeModel.sonnet => 'Sonnet',
    ClaudeModel.opus => 'Opus',
  };

  /// Wire-format string sent to the API.
  String get modeString => switch (this) {
    ClaudeModel.defaultModel => 'default',
    ClaudeModel.sonnet => 'sonnet',
    ClaudeModel.opus => 'opus',
  };

  /// Parse a wire-format string back to a [ClaudeModel].
  static ClaudeModel fromString(String? value) => switch (value) {
    'sonnet' => ClaudeModel.sonnet,
    'opus' => ClaudeModel.opus,
    _ => ClaudeModel.defaultModel,
  };
}

// Animation duration constants.
const _kBorderAnim = Duration(milliseconds: 200);
const _kSendAnim = Duration(milliseconds: 120);
const _kSwitchAnim = Duration(milliseconds: 180);

/// Enhanced chat input with autocomplete, draft persistence, and
/// polished animations.
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
    this.fileSuggestions = const [],
    this.machineName,
    this.currentPath,
    this.onMachinePressed,
    this.onPathPressed,
    this.profileId,
    this.onProfilePressed,
    this.isSendDisabled = false,
    this.contextSize,
  });

  /// Stable identifier for the current session (used for draft storage).
  final String sessionId;

  /// Controller for the message text field.
  final TextEditingController controller;

  /// Called when the user submits a message.
  final VoidCallback onSend;

  /// Whether a message is currently being sent.
  final bool isSending;

  /// Active permission mode, or null for server default.
  final perm.PermissionMode? permissionMode;

  /// Callback invoked when the user changes the permission mode.
  final ValueChanged<perm.PermissionMode>? onPermissionModeChanged;

  /// Active model selection, or null for server default.
  final ClaudeModel? modelMode;

  /// Callback invoked when the user changes the model.
  final ValueChanged<ClaudeModel>? onModelModeChanged;

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

  /// Profile identifier (reserved for future use).
  final String? profileId;

  /// Called when the profile avatar is tapped.
  final VoidCallback? onProfilePressed;

  /// Whether the send action is disabled.
  final bool isSendDisabled;

  /// Current context window usage in tokens.
  final int? contextSize;

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
      duration: _kSendAnim,
      value: 1.0,
    );
    _sendScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _sendScaleController,
        curve: Curves.easeOutBack,
      ),
    );

    _loadDraft();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      _draftAutoSave.sessionId = widget.sessionId;
      _draftAutoSave.saveNow();
      _loadDraft();
    }
  }

  @override
  void dispose() {
    _sendScaleController.dispose();
    _draftAutoSave.dispose();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Draft helpers
  // ---------------------------------------------------------------------------

  Future<void> _loadDraft() async {
    final draft = await DraftStorage().getDraft(widget.sessionId);
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

  // ---------------------------------------------------------------------------
  // Event handlers
  // ---------------------------------------------------------------------------

  void _onTextChanged() {
    final currentText = widget.controller.text;
    _updateAutocomplete(currentText);

    if (DraftStateTransition.isStateTransition(
      _previousText,
      currentText,
    )) {
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
    final lastWordMatch =
        RegExp(r'[@/](\w*)$').firstMatch(textBeforeCursor);

    if (lastWordMatch == null) {
      _clearAutocomplete();
      return;
    }

    final trigger = lastWordMatch.group(0)!.substring(0, 1);
    final query = lastWordMatch.group(1) ?? '';

    if (trigger == '@') {
      final suggestions = widget.fileSuggestions
          .where(
            (s) => s.label.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
      _autocompleteController.setSuggestions(suggestions, query);
      setState(() => _showAutocomplete = suggestions.isNotEmpty);
    } else if (trigger == '/') {
      final suggestions = _slashCommands
          .where(
            (c) => c.command
                .toLowerCase()
                .contains(query.toLowerCase()),
          )
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
    final lastWordMatch =
        RegExp(r'[@/](\w*)$').firstMatch(textBeforeCursor);

    if (lastWordMatch != null) {
      final startIndex = lastWordMatch.start;
      final trigger = suggestion.type == SuggestionType.command
          ? '/'
          : '@';
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

  void _handleKeyPress(KeyEvent event) {
    if (!_showAutocomplete) return;
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _autocompleteController.moveSelectionUp();
      setState(() {});
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _autocompleteController.moveSelectionDown();
      setState(() {});
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      final selected = _autocompleteController.selectedSuggestion;
      if (selected != null) _applySuggestion(selected);
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _clearAutocomplete();
    }
  }

  void _onSendTap() {
    if (widget.isSendDisabled || widget.isSending) return;
    _sendScaleController
      ..value = 0.0
      ..forward();
    widget.onSend();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.machineName != null || widget.currentPath != null)
          _buildContextInfoBar(context),
        if (_showAutocomplete)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AutocompleteOverlay(
              suggestions: _autocompleteController.suggestions,
              selectedIndex: _autocompleteController.selectedIndex,
              onSelect: (index) {
                _applySuggestion(
                  _autocompleteController.suggestions[index],
                );
              },
            ),
          ),
        _buildInputContainer(context),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Input container
  // ---------------------------------------------------------------------------

  Widget _buildInputContainer(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Subtle top-edge fade gradient
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 14,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.scaffoldBackgroundColor,
                  theme.scaffoldBackgroundColor.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.6),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusBar(context),
              const SizedBox(height: 6),
              _buildInputRow(context),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Text field + send button row
  // ---------------------------------------------------------------------------

  Widget _buildInputRow(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final borderColor =
        _isFocused ? cs.primary : cs.outlineVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: _kBorderAnim,
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : const [],
            ),
            child: KeyboardListener(
              focusNode: FocusNode(skipTraversal: true),
              onKeyEvent: _handleKeyPress,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'Message\u2026  \u2318\u23ce to send',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                ),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontSize: 15),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => widget.onSend(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildSendButton(context),
      ],
    );
  }

  Widget _buildSendButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canSend = !widget.isSendDisabled && !widget.isSending;

    return GestureDetector(
      onTap: _onSendTap,
      child: ScaleTransition(
        scale: _sendScale,
        child: AnimatedContainer(
          duration: _kBorderAnim,
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: canSend
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.12),
            boxShadow: canSend
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: AnimatedSwitcher(
            duration: _kSwitchAnim,
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            child: widget.isSending
                ? Padding(
                    key: const ValueKey('spinner'),
                    padding: const EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onPrimary,
                    ),
                  )
                : Icon(
                    key: const ValueKey('send'),
                    Icons.arrow_upward_rounded,
                    size: 20,
                    color: canSend
                        ? cs.onPrimary
                        : cs.onSurface.withValues(alpha: 0.38),
                  ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Context info bar
  // ---------------------------------------------------------------------------

  Widget _buildContextInfoBar(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          if (widget.machineName != null &&
              widget.onMachinePressed != null)
            _buildInfoChip(
              context,
              icon: Icons.computer_outlined,
              label: widget.machineName!,
              onTap: widget.onMachinePressed,
            ),
          if (widget.machineName != null &&
              widget.currentPath != null &&
              widget.onMachinePressed != null &&
              widget.onPathPressed != null)
            _buildInfoSeparator(context),
          if (widget.currentPath != null &&
              widget.onPathPressed != null)
            Flexible(
              child: _buildInfoChip(
                context,
                icon: Icons.folder_open_outlined,
                label: widget.currentPath!,
                onTap: widget.onPathPressed,
                ellipsis: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool ellipsis = false,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final Widget inner = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        if (ellipsis)
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          child: inner,
        ),
      );
    }

    return inner;
  }

  Widget _buildInfoSeparator(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        '/',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status bar (permission mode + model + context)
  // ---------------------------------------------------------------------------

  Widget _buildStatusBar(BuildContext context) {
    return Row(
      children: [
        if (widget.onPermissionModeChanged != null)
          perm.PermissionModeSelector(
            selectedMode: widget.permissionMode,
            onModeChanged: widget.onPermissionModeChanged,
          ),
        if (widget.onModelModeChanged != null) ...[
          const SizedBox(width: 6),
          _buildModelChip(context),
        ],
        const Spacer(),
        if (widget.contextSize != null && widget.contextSize! > 0)
          _buildContextIndicator(context),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Model chip
  // ---------------------------------------------------------------------------

  Widget _buildModelChip(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final model = widget.modelMode ?? ClaudeModel.defaultModel;
    final isDefault = model == ClaudeModel.defaultModel;

    final chipBg = isDefault
        ? cs.surfaceContainerHighest
        : cs.primary;
    final chipFg = isDefault ? cs.onSurfaceVariant : cs.onPrimary;
    final chipBorder =
        isDefault ? cs.outlineVariant.withValues(alpha: 0.7) : cs.primary;

    return GestureDetector(
      onTap: () => _showModelPicker(context),
      child: AnimatedContainer(
        duration: _kBorderAnim,
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: chipBorder),
          boxShadow: isDefault
              ? const []
              : [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              model == ClaudeModel.opus
                  ? Icons.diamond_outlined
                  : Icons.auto_awesome_outlined,
              size: 12,
              color: chipFg,
            ),
            const SizedBox(width: 4),
            Text(
              model.label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: chipFg,
                fontWeight:
                    isDefault ? FontWeight.w500 : FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 13,
              color: chipFg.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  void _showModelPicker(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final current = widget.modelMode ?? ClaudeModel.defaultModel;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Select Model',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final model in ClaudeModel.values)
                _buildModelTile(ctx, model, current, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelTile(
    BuildContext ctx,
    ClaudeModel model,
    ClaudeModel current,
    ThemeData theme,
  ) {
    final cs = theme.colorScheme;
    final isSelected = model == current;

    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        widget.onModelModeChanged?.call(model);
      },
      child: AnimatedContainer(
        duration: _kBorderAnim,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        color: isSelected
            ? cs.primaryContainer.withValues(alpha: 0.35)
            : Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary
                    : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                model == ClaudeModel.opus
                    ? Icons.diamond_outlined
                    : model == ClaudeModel.sonnet
                        ? Icons.auto_awesome_outlined
                        : Icons.smart_toy_outlined,
                size: 18,
                color: isSelected
                    ? cs.onPrimary
                    : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                model.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: isSelected ? cs.primary : cs.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: cs.primary,
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Context window indicator
  // ---------------------------------------------------------------------------

  Widget _buildContextIndicator(BuildContext context) {
    final theme = Theme.of(context);
    const maxContext = 190000;
    final used = widget.contextSize ?? 0;
    final pctUsed = (used / maxContext * 100).clamp(0.0, 100.0);
    final pctRemaining = (100 - pctUsed).round();

    final Color indicatorColor;
    if (pctRemaining <= 5) {
      indicatorColor = theme.colorScheme.error;
    } else if (pctRemaining <= 15) {
      indicatorColor = Colors.orange;
    } else {
      indicatorColor = theme.colorScheme.onSurfaceVariant;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 36,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pctUsed / 100,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest,
              valueColor:
                  AlwaysStoppedAnimation<Color>(indicatorColor),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$pctRemaining%',
          style: theme.textTheme.labelSmall?.copyWith(
            color: indicatorColor,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
