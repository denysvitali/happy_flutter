import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/draft_storage.dart';
import '../../core/theme/app_tokens.dart';
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
    command: 'clear',
    description: 'Clear conversation history',
    icon: Icons.delete_sweep_outlined,
  ),
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

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

/// Abort button shown in the input toolbar when the session is online.
///
/// Shows a stop icon at rest and a spinner while the abort RPC is
/// in-flight.  Hidden during permission-request state.
class _AbortButton extends StatelessWidget {
  const _AbortButton({
    required this.isAborting,
    this.onTap,
  });

  final bool isAborting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: isAborting ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        child: Center(
          child: AnimatedContainer(
            duration: _kBorderAnim,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: cs.error.withValues(alpha: 0.4),
              ),
            ),
            child: AnimatedSwitcher(
              duration: _kSwitchAnim,
              child: isAborting
                  ? SizedBox(
                      key: const ValueKey('abort-spinner'),
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onErrorContainer,
                      ),
                    )
                  : Row(
                      key: const ValueKey('abort-icon'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.stop_rounded,
                          size: 14,
                          color: cs.onErrorContainer,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Stop',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onErrorContainer,
                            height: 1,
                          ),
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

/// Send / stop button with animated icon crossfade and scale spring.
class _SendButton extends StatelessWidget {
  /// Creates a [_SendButton].
  const _SendButton({
    required this.isSending,
    required this.isSendDisabled,
    required this.onTap,
    required this.scaleAnimation,
  });

  /// Whether a message is actively being sent (shows stop indicator).
  final bool isSending;

  /// Whether sending is disabled entirely.
  final bool isSendDisabled;

  /// Callback when the button is tapped.
  final VoidCallback onTap;

  /// Spring-scale animation driven by the parent state.
  final Animation<double> scaleAnimation;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canSend = !isSendDisabled && !isSending;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: AnimatedContainer(
          duration: _kBorderAnim,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: canSend
                ? cs.primary
                : cs.surfaceContainerHighest,
            boxShadow: canSend
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.28),
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
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: isSending
                ? Padding(
                    key: const ValueKey('spinner'),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onSurfaceVariant,
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
}

/// Model selector pill that opens a bottom-sheet picker.
class _ModelSelector extends StatelessWidget {
  /// Creates a [_ModelSelector].
  const _ModelSelector({
    required this.model,
    required this.onTap,
  });

  /// The currently selected model.
  final ClaudeModel model;

  /// Called when the chip is tapped (should open picker).
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDefault = model == ClaudeModel.defaultModel;

    final chipBg = isDefault
        ? cs.surfaceContainerHighest
        : cs.primary;
    final chipFg = isDefault ? cs.onSurfaceVariant : cs.onPrimary;
    final chipBorder = isDefault
        ? cs.outlineVariant.withValues(alpha: 0.7)
        : cs.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: _kBorderAnim,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
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
}

/// Context-size indicator showing token usage as "Nk / Mk" label.
class _ContextSizeIndicator extends StatelessWidget {
  /// Creates a [_ContextSizeIndicator].
  const _ContextSizeIndicator({required this.contextSize});

  /// Token count currently used.
  final int contextSize;

  static const int _maxContext = 190000;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pctUsed =
        (contextSize / _maxContext * 100).clamp(0.0, 100.0);
    final pctRemaining = (100 - pctUsed).round();

    final Color indicatorColor;
    if (pctRemaining <= 5) {
      indicatorColor = theme.colorScheme.error;
    } else if (pctRemaining <= 15) {
      indicatorColor = Colors.orange;
    } else {
      indicatorColor =
          theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    }

    // Format as "Nk tokens"
    final String label;
    if (contextSize >= 1000) {
      final kVal = (contextSize / 1000).toStringAsFixed(0);
      label = '${kVal}k / 190k';
    } else {
      label = '$contextSize / 190k';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          height: 3,
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
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: indicatorColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Toolbar row containing permission selector, model selector, abort
/// button, and context indicator.
class _InputToolbar extends StatelessWidget {
  /// Creates an [_InputToolbar].
  const _InputToolbar({
    required this.onShowModelPicker,
    this.permissionMode,
    this.onPermissionModeChanged,
    this.modelMode,
    this.contextSize,
    this.showAbort = false,
    this.isAborting = false,
    this.onAbort,
  });

  /// Active permission mode (null = server default).
  final perm.PermissionMode? permissionMode;

  /// Callback when permission mode changes.
  final ValueChanged<perm.PermissionMode>? onPermissionModeChanged;

  /// Active model (null = server default).
  final ClaudeModel? modelMode;

  /// Opens the model bottom-sheet picker.
  final VoidCallback onShowModelPicker;

  /// Current context token usage, or null if unknown.
  final int? contextSize;

  /// Whether to show the abort button.
  final bool showAbort;

  /// Whether an abort RPC is in-flight (shows spinner).
  final bool isAborting;

  /// Called when the abort button is tapped.
  final VoidCallback? onAbort;

  @override
  Widget build(BuildContext context) {
    final model = modelMode ?? ClaudeModel.defaultModel;

    return Row(
      children: [
        if (onPermissionModeChanged != null)
          perm.PermissionModeSelector(
            selectedMode: permissionMode,
            onModeChanged: onPermissionModeChanged,
            availableModes:
                perm.PermissionModeExtension.claudeGeminiModes,
          ),
        const SizedBox(width: AppSpacing.xs + 2),
        _ModelSelector(
          model: model,
          onTap: onShowModelPicker,
        ),
        const Spacer(),
        if (showAbort) ...[
          _AbortButton(isAborting: isAborting, onTap: onAbort),
          if (contextSize != null && contextSize! > 0)
            const SizedBox(width: AppSpacing.xs + 2),
        ],
        if (contextSize != null && contextSize! > 0)
          _ContextSizeIndicator(contextSize: contextSize!),
      ],
    );
  }
}

/// Floating autocomplete suggestion list rendered above the input.
class _FileAutocomplete extends StatelessWidget {
  /// Creates a [_FileAutocomplete].
  const _FileAutocomplete({
    required this.suggestions,
    required this.selectedIndex,
    required this.onSelect,
  });

  /// Filtered suggestions to display.
  final List<AutocompleteSuggestion> suggestions;

  /// Currently highlighted suggestion index.
  final int selectedIndex;

  /// Called when a suggestion is tapped.
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000), // ~8% black
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: AutocompleteOverlay(
              suggestions: suggestions,
              selectedIndex: selectedIndex,
              onSelect: onSelect,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Model picker bottom sheet helpers (standalone functions)
// ---------------------------------------------------------------------------

Widget _buildModelTile(
  BuildContext ctx,
  ClaudeModel model,
  ClaudeModel current,
  ThemeData theme,
  ValueChanged<ClaudeModel> onChanged,
) {
  final cs = theme.colorScheme;
  final isSelected = model == current;

  return InkWell(
    onTap: () {
      Navigator.pop(ctx);
      onChanged(model);
    },
    child: AnimatedContainer(
      duration: _kBorderAnim,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
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
              color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              model.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
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

void _showModelPickerSheet(
  BuildContext context,
  ClaudeModel current,
  ValueChanged<ClaudeModel> onChanged,
) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              _buildModelTile(ctx, model, current, theme, onChanged),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

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
    this.isPermissionPending = false,
    this.isSessionOnline = false,
    this.onAbort,
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

  /// When true, input is locked while the agent awaits a permission
  /// decision from the user.
  final bool isPermissionPending;

  /// Whether the session CLI is currently connected (presence == 'online').
  /// Controls visibility of the abort button in the toolbar.
  final bool isSessionOnline;

  /// Called when the user taps the abort button.  Must return a [Future]
  /// so the button can show a spinner until the RPC completes.
  final Future<void> Function()? onAbort;

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
            (s) =>
                s.label.toLowerCase().contains(query.toLowerCase()),
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
    if (widget.isSendDisabled ||
        widget.isSending ||
        widget.isPermissionPending) {
      return;
    }
    _sendScaleController
      ..value = 0.0
      ..forward();
    widget.onSend();
  }

  Future<void> _onAbortTap() async {
    if (_isAborting || widget.onAbort == null) return;
    setState(() => _isAborting = true);
    final start = DateTime.now();
    try {
      await widget.onAbort!();
    } catch (_) {
      // Ignore — the caller logs errors.
    } finally {
      // Enforce a minimum 300 ms loading time so the spinner is visible.
      final elapsed = DateTime.now().difference(start);
      const minDuration = Duration(milliseconds: 300);
      if (elapsed < minDuration) {
        await Future<void>.delayed(minDuration - elapsed);
      }
      if (mounted) setState(() => _isAborting = false);
    }
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
          _FileAutocomplete(
            suggestions: _autocompleteController.suggestions,
            selectedIndex: _autocompleteController.selectedIndex,
            onSelect: (index) {
              _applySuggestion(
                _autocompleteController.suggestions[index],
              );
            },
          ),
        _buildInputContainer(context),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Input container  (card-like elevated surface)
  // ---------------------------------------------------------------------------

  Widget _buildInputContainer(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color: cs.onSurface.withValues(alpha: 0.08),
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // ~5% black
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm + 2,
            AppSpacing.sm,
            AppSpacing.sm + 2,
            AppSpacing.sm + 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card-like text area
              _buildCardInputArea(context),
              const SizedBox(height: AppSpacing.xs + 2),
              // Toolbar below card
              _InputToolbar(
                permissionMode: widget.permissionMode,
                onPermissionModeChanged:
                    widget.onPermissionModeChanged,
                modelMode: widget.modelMode,
                onShowModelPicker: () =>
                    widget.onModelModeChanged != null
                        ? _showModelPicker(context)
                        : null,
                contextSize: widget.contextSize,
                showAbort: widget.isSessionOnline &&
                    !widget.isPermissionPending,
                isAborting: _isAborting,
                onAbort: _onAbortTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card text area + send button
  // ---------------------------------------------------------------------------

  Widget _buildCardInputArea(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pending = widget.isPermissionPending;
    final borderColor = pending
        ? cs.onSurface.withValues(alpha: 0.08)
        : _isFocused
            ? cs.primary
            : cs.outlineVariant;
    final cardColor = pending
        ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
        : cs.surfaceContainerLow;

    return AnimatedContainer(
      duration: _kBorderAnim,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
        boxShadow: (!pending && _isFocused)
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _buildTextField(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              0,
              AppSpacing.xs + 2,
              AppSpacing.xs + 2,
              AppSpacing.xs + 2,
            ),
            child: _SendButton(
              isSending: widget.isSending,
              isSendDisabled:
                  widget.isSendDisabled || widget.isPermissionPending,
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
    final pending = widget.isPermissionPending;

    final hintText = pending
        ? 'Respond to the permission request above'
        : 'Message\u2026  \u2318\u23ce to send';
    final hintColor = pending
        ? cs.onSurfaceVariant.withValues(alpha: 0.7)
        : cs.onSurface.withValues(alpha: 0.35);

    return KeyboardListener(
      focusNode: FocusNode(skipTraversal: true),
      onKeyEvent: _handleKeyPress,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: !pending,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: hintColor,
            fontSize: 14,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md + 2,
            AppSpacing.sm + 2,
            AppSpacing.sm,
            AppSpacing.sm + 2,
          ),
        ),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          color: pending
              ? cs.onSurface.withValues(alpha: 0.38)
              : null,
        ),
        maxLines: 4,
        minLines: 1,
        textInputAction:
            defaultTargetPlatform == TargetPlatform.android
                ? TextInputAction.newline
                : TextInputAction.send,
        onSubmitted:
            defaultTargetPlatform == TargetPlatform.android
                ? null
                : (_) => widget.onSend(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Context info bar (machine / path)
  // ---------------------------------------------------------------------------

  Widget _buildContextInfoBar(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
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
        borderRadius: BorderRadius.circular(AppRadius.xs + 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
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
  // Model picker (bottom sheet)
  // ---------------------------------------------------------------------------

  void _showModelPicker(BuildContext context) {
    final current = widget.modelMode ?? ClaudeModel.defaultModel;
    _showModelPickerSheet(
      context,
      current,
      (model) => widget.onModelModeChanged?.call(model),
    );
  }
}
