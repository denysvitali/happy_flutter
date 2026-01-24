import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/draft_storage.dart';
import 'widgets/autocomplete_overlay.dart';
import 'widgets/permission_mode_selector.dart';

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

/// Enhanced chat input widget with autocomplete and draft persistence
class ChatInput extends ConsumerStatefulWidget {
  final String sessionId;
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;
  final PermissionMode? permissionMode;
  final ValueChanged<PermissionMode>? onPermissionModeChanged;
  final List<AutocompleteSuggestion> fileSuggestions;
  final bool showSettingsButton;
  final String? machineName;
  final String? currentPath;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onMachinePressed;
  final VoidCallback? onPathPressed;
  final String? profileId;
  final VoidCallback? onProfilePressed;
  final bool isSendDisabled;

  const ChatInput({
    super.key,
    required this.sessionId,
    required this.controller,
    required this.onSend,
    this.isSending = false,
    this.permissionMode,
    this.onPermissionModeChanged,
    this.fileSuggestions = const [],
    this.showSettingsButton = true,
    this.machineName,
    this.currentPath,
    this.onSettingsPressed,
    this.onMachinePressed,
    this.onPathPressed,
    this.profileId,
    this.onProfilePressed,
    this.isSendDisabled = false,
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
  bool _showSettings = false;

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
      setState(() => _showSettings = false);
      // Save draft when losing focus
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
      final prefix = lastWordMatch.group(0)!;
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

        // Settings overlay
        if (_showSettings) _buildSettingsOverlay(context),

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
                  // Settings button
                  if (widget.showSettingsButton)
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        setState(() => _showSettings = !_showSettings);
                        widget.onSettingsPressed?.call();
                      },
                    ),

                  // Expanded text field
                  Expanded(
                    child: RawKeyboardListener(
                      focusNode: FocusNode(skipTraversal: true),
                      onKey: _handleKeyPress,
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText:
                              'Type a message... (@ for files, / for commands)',
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          // Permission mode selector
          if (widget.onPermissionModeChanged != null)
            PermissionModeSelector(
              selectedMode: widget.permissionMode,
              onModeChanged: widget.onPermissionModeChanged,
            ),
          const Spacer(),
          // Character count or other status info
          if (widget.controller.text.isNotEmpty)
            Text(
              '${widget.controller.text.length} chars',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsOverlay(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Permission mode section title
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Text(
                  'Permission Mode',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Permission mode options
              ...PermissionMode.values.map(
                (mode) => ListTile(
                  leading: Radio<PermissionMode>(
                    value: mode,
                    groupValue: widget.permissionMode,
                    onChanged: widget.onPermissionModeChanged != null
                        ? (value) {
                            widget.onPermissionModeChanged!(
                              value as PermissionMode,
                            );
                          }
                        : null,
                  ),
                  title: Text(mode.displayName),
                  subtitle: Text(mode.description),
                  onTap: widget.onPermissionModeChanged != null
                      ? () => widget.onPermissionModeChanged!(mode)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
