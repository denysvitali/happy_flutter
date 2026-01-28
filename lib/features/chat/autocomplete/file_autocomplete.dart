import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Characters that stop the active word search
const List<String> _stopCharacters = [
  '\n',
  ',',
  '(',
  ')',
  '[',
  ']',
  '{',
  '}',
  '<',
  '>',
  ';',
  '!',
  '?',
  '.',
];

/// Represents the active word at the cursor position
final class ActiveWord {
  /// The complete word from prefix to end (e.g., "@username")
  final String word;

  /// The part from prefix to cursor position (e.g., "@use")
  final String activeWord;

  /// Starting position of the word in the text
  final int offset;

  /// Total length of the complete word
  final int length;

  /// Length from prefix to cursor position
  final int activeLength;

  /// Position where the word ends (offset + length)
  final int endOffset;

  const ActiveWord({
    required this.word,
    required this.activeWord,
    required this.offset,
    required this.length,
    required this.activeLength,
    required this.endOffset,
  });
}

/// Result of applying a suggestion
final class ApplySuggestionResult {
  final String text;
  final int cursorPosition;

  const ApplySuggestionResult({
    required this.text,
    required this.cursorPosition,
  });
}

/// Finds the starting position of the active word at the cursor
int _findActiveWordStart(
  String content,
  TextSelection selection,
  List<String> prefixes,
) {
  var startIndex = selection.start - 1;
  var spaceIndex = -1;
  var foundPrefix = false;
  var prefixIndex = -1;

  while (startIndex >= 0) {
    final char = content[startIndex];

    // Check if we hit a space
    if (char == ' ') {
      if (foundPrefix) {
        // We found a prefix earlier, return its position
        return prefixIndex;
      }
      if (spaceIndex >= 0) {
        // Multiple spaces, stop here
        return spaceIndex + 1;
      } else {
        spaceIndex = startIndex;
        startIndex--;
      }
    }
    // Check if this is a prefix character at word boundary
    else if (prefixes.contains(char) &&
        (startIndex == 0 || content[startIndex - 1] == ' ')) {
      // For @ prefix, continue searching backwards to include the entire file path
      if (char == '@') {
        foundPrefix = true;
        prefixIndex = startIndex;
        // Return immediately for @ at word boundary
        return startIndex;
      } else {
        return startIndex;
      }
    }
    // Check if we hit a stop character
    else if (_stopCharacters.contains(char)) {
      if (foundPrefix) {
        return prefixIndex;
      }
      return startIndex + 1;
    }
    // Continue searching backwards
    else {
      startIndex--;
    }
  }

  // Reached beginning of text
  if (foundPrefix) {
    return prefixIndex;
  }
  return (spaceIndex >= 0 ? spaceIndex : startIndex) + 1;
}

/// Finds the ending position of the active word
int _findActiveWordEnd(
  String content,
  int cursorPos,
  int? wordStartPos,
) {
  var endIndex = cursorPos;

  // Check if this is a file path (starts with @ and may contain /)
  var isFilePath = false;
  if (wordStartPos != null && wordStartPos >= 0 && wordStartPos < content.length) {
    isFilePath = content[wordStartPos] == '@';
  }

  while (endIndex < content.length) {
    final char = content[endIndex];

    // For file paths starting with @, don't stop at / or .
    if (isFilePath && (char == '/' || char == '.')) {
      endIndex++;
      continue;
    }

    // Stop at spaces or stop characters
    if (char == ' ' || _stopCharacters.contains(char)) {
      break;
    }
    endIndex++;
  }

  return endIndex;
}

/// Finds the active word at the cursor position that starts with one of the given prefixes.
///
/// [content] The full text content
/// [selection] The current cursor position/selection
/// [prefixes] Array of prefix characters to look for (e.g., ['@', ':', '/'])
///
/// Returns an [ActiveWord] containing word details, or null if no prefixed word is found at cursor position.
ActiveWord? findActiveWord(
  String content,
  TextSelection selection,
  List<String> prefixes = const ['@', ':', '/'],
) {
  // Only detect when cursor is at a single point (no text selected)
  if (selection.start != selection.end) {
    return null;
  }

  // Don't detect if cursor is at the very beginning
  if (selection.start == 0) {
    return null;
  }

  final startIndex = _findActiveWordStart(content, selection, prefixes);
  final activeWordPart = content.substring(startIndex, selection.end);

  // Check if the active word ends with a space - if so, no active word
  if (activeWordPart.endsWith(' ')) {
    return null;
  }

  // Check if the word starts with one of our prefixes
  if (activeWordPart.isNotEmpty) {
    final firstChar = activeWordPart[0];
    if (prefixes.contains(firstChar)) {
      // Find where the word ends after the cursor
      // Pass the start position to help determine if this is a file path
      final endIndex = _findActiveWordEnd(content, selection.end, startIndex);
      final fullWord = content.substring(startIndex, endIndex);

      // Don't return just the prefix character alone
      if (activeWordPart.length == 1 && fullWord.length == 1) {
        return ActiveWord(
          word: fullWord,
          activeWord: activeWordPart,
          offset: startIndex,
          length: fullWord.length,
          activeLength: activeWordPart.length,
          endOffset: endIndex,
        );
      }
      return ActiveWord(
        word: fullWord,
        activeWord: activeWordPart,
        offset: startIndex,
        length: fullWord.length,
        activeLength: activeWordPart.length,
        endOffset: endIndex,
      );
    }
  }

  return null;
}

/// Extracts just the query part without the prefix.
///
/// [activeWord] The active word including prefix
///
/// Returns The query string without prefix
String getActiveWordQuery(String activeWord) {
  if (activeWord.length > 1) {
    return activeWord.substring(1);
  }
  return '';
}

/// Applies a suggestion by replacing the active word with the provided suggestion text.
///
/// [content] The full text content
/// [selection] The current cursor position/selection
/// [suggestion] The suggestion text to insert (e.g., "@filename.txt")
/// [prefixes] Array of prefix characters to look for (e.g., ['@', ':', '/'])
/// [addSpace] Whether to add a space after the suggestion (default: true)
///
/// Returns An [ApplySuggestionResult] containing the new text and cursor position
ApplySuggestionResult applySuggestion(
  String content,
  TextSelection selection,
  String suggestion,
  List<String> prefixes = const ['@', ':', '/'],
  bool addSpace = true,
) {
  // Find the active word at the current position
  final activeWord = findActiveWord(content, selection, prefixes);

  if (activeWord == null) {
    // No active word found, just insert the suggestion at cursor position
    final beforeCursor = content.substring(0, selection.start);
    final afterCursor = content.substring(selection.end);
    final suggestionWithSpace = addSpace ? '$suggestion ' : suggestion;

    return ApplySuggestionResult(
      text: beforeCursor + suggestionWithSpace + afterCursor,
      cursorPosition: selection.start + suggestionWithSpace.length,
    );
  }

  // Replace the complete word (from offset to endOffset) with the suggestion
  final beforeWord = content.substring(0, activeWord.offset);
  final afterWord = content.substring(activeWord.endOffset);

  // Add space after suggestion if requested
  var suggestionToInsert = suggestion;
  if (addSpace) {
    // Add space if:
    // 1. There's no text after (end of string)
    // 2. There's text after but no space
    if (afterWord.isEmpty || afterWord[0] != ' ') {
      suggestionToInsert = '$suggestion ';
    }
  }

  final newText = beforeWord + suggestionToInsert + afterWord;
  final newCursorPosition = activeWord.offset + suggestionToInsert.length;

  return ApplySuggestionResult(
    text: newText,
    cursorPosition: newCursorPosition,
  );
}

/// A file autocomplete widget that displays file/folder suggestions when typing @file.
///
/// This widget wraps the chat input and shows a suggestion overlay when the user types
/// @ followed by a file path query. It integrates with the existing autocomplete infrastructure.
class FileAutocomplete extends StatefulWidget {
  /// The text editing controller for the input field
  final TextEditingController controller;

  /// The focus node for the input field
  final FocusNode focusNode;

  /// Callback to fetch file suggestions based on query
  final Future<List<FileSuggestion>> Function(String query) fetchSuggestions;

  /// Callback when a suggestion is selected
  final void Function(FileSuggestion suggestion) onSelect;

  /// The child widget (typically the input field)
  final Widget child;

  /// Maximum height for the suggestions overlay
  final double maxOverlayHeight;

  /// Height of each suggestion item
  final double itemHeight;

  const FileAutocomplete({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.fetchSuggestions,
    required this.onSelect,
    required this.child,
    this.maxOverlayHeight = 240,
    this.itemHeight = 48,
  });

  @override
  State<FileAutocomplete> createState() => _FileAutocompleteState();
}

class _FileAutocompleteState extends State<FileAutocomplete> {
  List<FileSuggestion> _suggestions = [];
  int _selectedIndex = -1;
  String _currentQuery = '';
  bool _showOverlay = false;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(FileAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _updateAutocomplete();
  }

  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) {
      _hideOverlay();
    }
  }

  Future<void> _updateAutocomplete() async {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    // Check if cursor is at a valid position
    if (selection.start < 0) {
      _hideOverlay();
      return;
    }

    // Find active word at cursor
    final activeWord = findActiveWord(text, selection, const ['@']);

    if (activeWord == null) {
      _hideOverlay();
      return;
    }

    // Get the query (without @ prefix)
    final query = getActiveWordQuery(activeWord.activeWord);

    // Don't show suggestions for just "@" - wait for more input
    if (query.isEmpty) {
      _hideOverlay();
      return;
    }

    // Check if we need new suggestions
    if (query != _currentQuery || _suggestions.isEmpty) {
      await _fetchSuggestions(query);
    } else {
      _showOverlayIfNotEmpty();
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _currentQuery = query;
    });

    try {
      final suggestions = await widget.fetchSuggestions(query);
      final filtered = suggestions
          .where((s) => s.label.toLowerCase().contains(query.toLowerCase()))
          .toList();

      setState(() {
        _suggestions = filtered;
        _selectedIndex = filtered.isNotEmpty ? 0 : -1;
        _showOverlay = filtered.isNotEmpty;
      });
    } catch (e) {
      // Silently handle errors
      setState(() {
        _suggestions = [];
        _showOverlay = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showOverlayIfNotEmpty() {
    setState(() {
      _showOverlay = _suggestions.isNotEmpty;
    });
  }

  void _hideOverlay() {
    setState(() {
      _showOverlay = false;
    });
  }

  void _selectSuggestion(int index) {
    if (index >= 0 && index < _suggestions.length) {
      final suggestion = _suggestions[index];
      widget.onSelect(suggestion);

      // Apply the suggestion to the text field
      final result = applySuggestion(
        widget.controller.text,
        widget.controller.selection,
        '@${suggestion.label}',
        const ['@'],
        true,
      );

      widget.controller.value = TextEditingValue(
        text: result.text,
        selection: TextSelection.collapsed(offset: result.cursorPosition),
      );

      _hideOverlay();
      widget.focusNode.requestFocus();
    }
  }

  void _moveSelectionUp() {
    if (_suggestions.isEmpty) return;
    setState(() {
      if (_selectedIndex <= 0) {
        _selectedIndex = _suggestions.length - 1;
      } else {
        _selectedIndex--;
      }
    });
    _scrollToSelected();
  }

  void _moveSelectionDown() {
    if (_suggestions.isEmpty) return;
    setState(() {
      if (_selectedIndex >= _suggestions.length - 1) {
        _selectedIndex = 0;
      } else {
        _selectedIndex++;
      }
    });
    _scrollToSelected();
  }

  void _scrollToSelected() {
    if (_selectedIndex < 0) return;

    final scrollOffset = _selectedIndex * widget.itemHeight;
    _scrollController.animateTo(
      scrollOffset,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  void _handleKeyPress(RawKeyEvent event) {
    if (!_showOverlay) return;

    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _moveSelectionUp();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _moveSelectionDown();
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.tab) {
        _selectSuggestion(_selectedIndex >= 0 ? _selectedIndex : 0);
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _hideOverlay();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        widget.child,
        if (_showOverlay)
          Positioned(
            left: 0,
            right: 0,
            bottom: 100,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surface,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoading)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Searching files...',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          height: widget.maxOverlayHeight,
                          child: Scrollbar(
                            controller: _scrollController,
                            child: ListView.separated(
                              controller: _scrollController,
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _suggestions.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                color: theme.dividerColor.withOpacity(0.5),
                              ),
                              itemBuilder: (context, index) {
                                final suggestion = _suggestions[index];
                                final isSelected = index == _selectedIndex;

                                return _FileSuggestionItem(
                                  suggestion: suggestion,
                                  isSelected: isSelected,
                                  onTap: () => _selectSuggestion(index),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Represents a file or folder suggestion
final class FileSuggestion {
  final String label;
  final String path;
  final FileSuggestionType type;

  const FileSuggestion({
    required this.label,
    required this.path,
    this.type = FileSuggestionType.file,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileSuggestion &&
        other.label == label &&
        other.path == path;
  }

  @override
  int get hashCode => Object.hash(label, path, type);
}

/// Types of file suggestions
enum FileSuggestionType { file, folder }

class _FileSuggestionItem extends StatelessWidget {
  final FileSuggestion suggestion;
  final bool isSelected;
  final VoidCallback onTap;

  const _FileSuggestionItem({
    required this.suggestion,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _buildIcon(theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      suggestion.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (suggestion.path.isNotEmpty)
                      Text(
                        suggestion.path,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              _buildTypeBadge(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(ThemeData theme) {
    final iconData = suggestion.type == FileSuggestionType.folder
        ? Icons.folder_outlined
        : Icons.description_outlined;
    final iconColor = suggestion.type == FileSuggestionType.folder
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, size: 18, color: iconColor),
    );
  }

  Widget _buildTypeBadge(ThemeData theme) {
    final badgeText = suggestion.type == FileSuggestionType.folder
        ? 'Folder'
        : 'File';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        badgeText,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
    );
  }
}
