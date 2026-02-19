import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/draft_storage.dart';
import 'widgets/autocomplete_overlay.dart';
import 'widgets/permission_mode_selector.dart' as perm;

/// Slash command suggestions
final class SlashCommand {
  final String command;
  final String description;
  final IconData icon;

  const SlashCommand({
    required this.command,
    required this.description,
    required this.icon,
  });
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

/// Model options for Claude sessions
enum ClaudeModel {
  defaultModel,
  sonnet,
  opus;

  String get label => switch (this) {
    ClaudeModel.defaultModel => 'Default',
    ClaudeModel.sonnet => 'Sonnet',
    ClaudeModel.opus => 'Opus',
  };

  String get modeString => switch (this) {
    ClaudeModel.defaultModel => 'default',
    ClaudeModel.sonnet => 'sonnet',
    ClaudeModel.opus => 'opus',
  };

  static ClaudeModel fromString(String? value) => switch (value) {
    'sonnet' => ClaudeModel.sonnet,
    'opus' => ClaudeModel.opus,
    _ => ClaudeModel.defaultModel,
  };
}

/// Enhanced chat input widget with autocomplete and draft persistence
class ChatInput extends ConsumerStatefulWidget {
  final String sessionId;
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;
  final perm.PermissionMode? permissionMode;
  final ValueChanged<perm.PermissionMode>? onPermissionModeChanged;
  final ClaudeModel? modelMode;
  final ValueChanged<ClaudeModel>? onModelModeChanged;
  final List<AutocompleteSuggestion> fileSuggestions;
  final String? machineName;
  final String? currentPath;
  final VoidCallback? onMachinePressed;
  final VoidCallback? onPathPressed;
  final String? profileId;
  final VoidCallback? onProfilePressed;
  final bool isSendDisabled;
  final int? contextSize;

  const ChatInput({
    super.key,
    required this.sessionId,
    required this.controller,
    required this.onSend,
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

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final FocusNode _focusNode = FocusNode();
  final AutocompleteController _autocompleteController =
      AutocompleteController();
  final DraftAutoSave _draftAutoSave;

  String _previousText = '';
  bool _showAutocomplete = false;

  _ChatInputState()
    : _draftAutoSave = DraftAutoSave(sessionId: '', onSave: (_) {}) {
    // Placeholder - sessionId will be set in initState
  }

  @override
  void initState() {
    super.initState();
    _draftAutoSave.sessionId = widget.sessionId;
    _draftAutoSave.onSave = _saveDraft;

    // Load existing draft
    _loadDraft();

    // Add text change listener
    widget.controller.addListener(_onTextChanged);

    // Focus listener
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
    _draftAutoSave.dispose();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final draft = await DraftStorage().getDraft(widget.sessionId);
    if (draft != null && draft.isNotEmpty && widget.controller.text.isEmpty) {
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

  void _onTextChanged() {
    final currentText = widget.controller.text;

    // Update autocomplete based on current word being typed
    _updateAutocomplete(currentText);

    // Handle state transitions for draft auto-save
    if (DraftStateTransition.isStateTransition(_previousText, currentText)) {
      // Save immediately on empty <-> non-empty transition
      _draftAutoSave.saveNow();
    } else if (!currentText.trim().isEmpty) {
      // Debounced save for text modifications
      _draftAutoSave.update(currentText);
    }

    _previousText = currentText;
  }

  void _updateAutocomplete(String text) {
    // Find the current word being typed (for @file or /command)
    final cursorPosition = widget.controller.selection.base.offset;
    if (cursorPosition < 0) {
      _clearAutocomplete();
      return;
    }

    // Get text before cursor
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastWordMatch = RegExp(r'[@/](\w*)$').firstMatch(textBeforeCursor);

    if (lastWordMatch == null) {
      _clearAutocomplete();
      return;
    }

    final prefix = lastWordMatch.group(0)!.substring(0, 1);
    final query = lastWordMatch.group(1) ?? '';

    if (prefix == '@') {
      // File autocomplete
      final suggestions = widget.fileSuggestions
          .where((s) => s.label.toLowerCase().contains(query.toLowerCase()))
          .toList();
      _autocompleteController.setSuggestions(suggestions, query);
      setState(() => _showAutocomplete = suggestions.isNotEmpty);
    } else if (prefix == '/') {
      // Command autocomplete
      final suggestions = _slashCommands
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
    if (!_focusNode.hasFocus) {
      _draftAutoSave.saveNow();
    }
  }

  void _applySuggestion(AutocompleteSuggestion suggestion) {
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.base.offset;

    // Find and replace the current autocomplete trigger with the suggestion
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastWordMatch = RegExp(r'[@/](\w*)$').firstMatch(textBeforeCursor);

    if (lastWordMatch != null) {
      final startIndex = lastWordMatch.start;
      final newText = text.replaceRange(
        startIndex,
        cursorPosition,
        '${suggestion.type == SuggestionType.command ? '/' : '@'}${suggestion.label} ',
      );

      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: startIndex + suggestion.label.length + 2,
        ),
      );
    }

    _clearAutocomplete();
    _focusNode.requestFocus();
  }

  void _handleKeyPress(RawKeyEvent event) {
    if (!_showAutocomplete) return;

    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _autocompleteController.moveSelectionUp();
        setState(() {});
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _autocompleteController.moveSelectionDown();
        setState(() {});
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.tab) {
        final selected = _autocompleteController.selectedSuggestion;
        if (selected != null) {
          _applySuggestion(selected);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _clearAutocomplete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Context info bar (machine + path)
        if (widget.machineName != null || widget.currentPath != null)
          _buildContextInfoBar(context),

        // Autocomplete overlay
        if (_showAutocomplete)
          Positioned(
            left: 0,
            right: 0,
            bottom: 100,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: AutocompleteOverlay(
                suggestions: _autocompleteController.suggestions,
                selectedIndex: _autocompleteController.selectedIndex,
                onSelect: (index) {
                  _applySuggestion(_autocompleteController.suggestions[index]);
                },
              ),
            ),
          ),

        // Input area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Column(
            children: [
              // Status bar (permission mode + connection status)
              _buildStatusBar(context),

              // Input row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Expanded text field
                  Expanded(
                    child: RawKeyboardListener(
                      focusNode: FocusNode(skipTraversal: true),
                      onKey: _handleKeyPress,
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceVariant,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => widget.onSend(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Send button
                  IconButton(
                    icon: widget.isSending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    onPressed: (widget.isSendDisabled || widget.isSending)
                        ? null
                        : widget.onSend,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContextInfoBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (widget.machineName != null && widget.onMachinePressed != null)
            Expanded(
              child: InkWell(
                onTap: widget.onMachinePressed,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.computer_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.machineName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (widget.currentPath != null && widget.onPathPressed != null)
            Expanded(
              child: InkWell(
                onTap: widget.onPathPressed,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          widget.currentPath!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Permission mode selector
          if (widget.onPermissionModeChanged != null)
            perm.PermissionModeSelector(
              selectedMode: widget.permissionMode,
              onModeChanged: widget.onPermissionModeChanged,
            ),
          // Model selector
          if (widget.onModelModeChanged != null) ...[
            const SizedBox(width: 6),
            _buildModelSelector(context, theme),
          ],
          const Spacer(),
          // Context window remaining
          if (widget.contextSize != null && widget.contextSize! > 0)
            _buildContextIndicator(theme),
        ],
      ),
    );
  }

  Widget _buildModelSelector(BuildContext context, ThemeData theme) {
    final model = widget.modelMode ?? ClaudeModel.defaultModel;
    final isDefault = model == ClaudeModel.defaultModel;

    return GestureDetector(
      onTap: () => _showModelPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isDefault
              ? theme.colorScheme.surfaceVariant
              : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 12,
              color: isDefault
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              model.label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: isDefault
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onPrimaryContainer,
                fontWeight: isDefault ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showModelPicker(BuildContext context) {
    final theme = Theme.of(context);
    final current = widget.modelMode ?? ClaudeModel.defaultModel;

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Model',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final model in ClaudeModel.values)
                ListTile(
                  dense: true,
                  leading: Icon(
                    model == ClaudeModel.opus
                        ? Icons.diamond_outlined
                        : model == ClaudeModel.sonnet
                            ? Icons.auto_awesome_outlined
                            : Icons.smart_toy_outlined,
                    size: 20,
                    color: model == current
                        ? theme.colorScheme.primary
                        : null,
                  ),
                  title: Text(model.label),
                  trailing: model == current
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onModelModeChanged?.call(model);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextIndicator(ThemeData theme) {
    const maxContext = 190000;
    final used = widget.contextSize ?? 0;
    final percentUsed = (used / maxContext * 100).clamp(0.0, 100.0);
    final percentRemaining = (100 - percentUsed).round();

    Color color;
    if (percentRemaining <= 5) {
      color = theme.colorScheme.error;
    } else if (percentRemaining <= 15) {
      color = Colors.orange;
    } else {
      color = theme.colorScheme.onSurfaceVariant;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percentUsed / 100,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$percentRemaining%',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
