import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/outgoing_image.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/draft_storage.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/offline_dictation_service.dart';
import '../../core/theme/app_tokens.dart';
import 'send/chat_attachment_controller.dart';
import 'send/image_attachment_service.dart';
import 'widgets/autocomplete_overlay.dart';
import 'widgets/chat_input_buttons.dart';
import 'widgets/file_autocomplete.dart';
import 'widgets/input_toolbar.dart';
import 'widgets/model_mode.dart';
import 'widgets/permission_mode_selector.dart' as perm;
import 'widgets/picker_sheets.dart';
import 'widgets/slash_commands.dart';

export 'widgets/model_mode.dart' show ChatModelMode;

/// Enhanced chat input with autocomplete, draft
/// persistence, and polished animations.
class ChatInput extends ConsumerStatefulWidget {
  /// Creates a [ChatInput].
  const ChatInput({
    required this.sessionId,
    required this.controller,
    required this.onSend,
    super.key,
    this.attachmentController,
    this.isSending = false,
    this.permissionMode,
    this.onPermissionModeChanged,
    this.modelMode,
    this.onModelModeChanged,
    this.availableModels = ChatModelMode.values,
    this.availableSlashCommands = const [],
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
    this.enterToSend = false,
    this.lastDeliveryStatus,
  });

  /// Stable identifier for the current session
  /// (used for draft storage).
  final String sessionId;

  /// Controller for the message text field.
  final TextEditingController controller;

  /// Staged image attachments. When null, the attach UI is hidden.
  final ChatAttachmentController? attachmentController;

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
  final ChatModelMode? modelMode;

  /// Callback invoked when the user changes the model.
  final ValueChanged<ChatModelMode>? onModelModeChanged;

  /// Model options available for the current session flavor.
  final List<ChatModelMode> availableModels;

  /// Slash commands advertised by the current session's agent.
  final List<String> availableSlashCommands;

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

  /// Whether pressing Enter sends the message
  /// (vs inserting a newline).
  final bool enterToSend;

  /// Delivery status of the most-recently sent message.
  /// Passed to [SendButton] so it can morph to a checkmark
  /// when the value becomes `'sent'`.
  final String? lastDeliveryStatus;

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput>
    with TickerProviderStateMixin {
  _ChatInputState()
    : _draftAutoSave = DraftAutoSave(sessionId: '', onSave: (_) {}),
      _draftStorage = DraftStorage();

  final DraftStorage _draftStorage;
  static final _containerRadius = BorderRadius.circular(AppRadius.xl);
  // AppShadow.card has brightness-aware variants — dark in light
  // mode (subtle black 4% + 2%), light in dark mode (subtle white).
  // The previous Colors.black.withValues(alpha: 0.04) was always
  // on-top black regardless of theme.
  static final _cardBoxShadow = AppShadow.card;

  final FocusNode _focusNode = FocusNode();
  final AutocompleteController _autocompleteController =
      AutocompleteController();
  final DraftAutoSave _draftAutoSave;
  late final OfflineDictationService _dictationService;
  static const _dictationSilenceThresholdDb = -45.0;
  static const _dictationSilenceDuration = Duration(milliseconds: 1200);
  static const _dictationInitialGrace = Duration(seconds: 2);
  static const _dictationMaxDuration = Duration(seconds: 30);

  String _previousText = '';
  bool _showAutocomplete = false;

  // Debounce timer for the autocomplete search/filter pass. Cursor and
  // cancel behavior remain synchronous; only the regex match + list
  // filter + setState are deferred so rapid keystrokes don't rebuild
  // the suggestion list on every character.
  Timer? _autocompleteDebounce;
  static const Duration _autocompleteDebounceDuration = Duration(
    milliseconds: 100,
  );
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isStoppingDictation = false;
  DateTime? _dictationStartedAt;
  DateTime? _dictationSilenceStartedAt;
  Timer? _dictationMaxTimer;
  StreamSubscription<double>? _dictationLevelSub;
  int? _dictationPreviewStart;
  int? _dictationPreviewEnd;
  String _dictationPreviewText = '';
  int _dictationSessionId = 0;
  final ValueNotifier<bool> _isFocused = ValueNotifier<bool>(false);

  late final AnimationController _sendScaleController;
  late final Animation<double> _sendScale;

  @override
  void initState() {
    super.initState();
    _dictationService = ref.read(offlineDictationServiceProvider);
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
    _autocompleteDebounce?.cancel();
    _sendScaleController.dispose();
    _draftAutoSave.dispose();
    _stopDictationWatchers();
    _isFocused.dispose();
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
    final draft = await _draftStorage.getDraft(targetSessionId);
    if (targetSessionId != widget.sessionId) return;
    if (draft != null && draft.isNotEmpty && widget.controller.text.isEmpty) {
      widget.controller.text = draft;
      _previousText = draft;
    }
  }

  Future<void> _saveDraft(String draft) async {
    if (draft.trim().isEmpty) {
      await _draftStorage.removeDraft(widget.sessionId);
    } else {
      await _draftStorage.saveDraft(widget.sessionId, draft);
    }
  }

  // -----------------------------------------------------------
  // Event handlers
  // -----------------------------------------------------------

  void _onTextChanged() {
    final currentText = widget.controller.text;
    _scheduleAutocompleteUpdate(currentText);

    if (currentText.trim().isEmpty) {
      _draftAutoSave.discardPending();
      unawaited(_draftStorage.removeDraft(widget.sessionId));
    } else if (DraftStateTransition.isStateTransition(
      _previousText,
      currentText,
    )) {
      _draftAutoSave.saveNow();
    } else {
      _draftAutoSave.update(currentText);
    }

    _previousText = currentText;
  }

  /// Debounce the autocomplete search/filter pass. If the cursor is no
  /// longer at a trigger position, we cancel immediately (no debounce
  /// needed for close behavior). Otherwise we coalesce keystrokes at
  /// [_autocompleteDebounceDuration].
  void _scheduleAutocompleteUpdate(String text) {
    final cursorPosition = widget.controller.selection.base.offset;
    if (cursorPosition < 0) {
      _autocompleteDebounce?.cancel();
      _clearAutocomplete();
      return;
    }
    final textBeforeCursor = text.substring(0, cursorPosition);
    final hasTrigger =
        RegExp(r'[@/]([\w-]*)$').firstMatch(textBeforeCursor) != null;
    if (!hasTrigger) {
      // No active trigger: close immediately, no debounce.
      _autocompleteDebounce?.cancel();
      _clearAutocomplete();
      return;
    }
    _autocompleteDebounce?.cancel();
    _autocompleteDebounce = Timer(_autocompleteDebounceDuration, () {
      if (!mounted) return;
      _updateAutocomplete(widget.controller.text);
    });
  }

  void _updateAutocomplete(String text) {
    final cursorPosition = widget.controller.selection.base.offset;
    if (cursorPosition < 0) {
      _clearAutocomplete();
      return;
    }

    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastWordMatch = RegExp(r'[@/]([\w-]*)$').firstMatch(textBeforeCursor);

    if (lastWordMatch == null) {
      _clearAutocomplete();
      return;
    }

    final trigger = lastWordMatch.group(0)!.substring(0, 1);
    final query = lastWordMatch.group(1) ?? '';
    // Hoist normalization out of the per-element loop.
    final queryLower = query.toLowerCase();

    if (trigger == '@') {
      final suggestions = widget.fileSuggestions
          .where((s) => s.label.toLowerCase().contains(queryLower))
          .toList();
      _autocompleteController.setSuggestions(suggestions, query);
      if (_showAutocomplete != suggestions.isNotEmpty) {
        setState(() => _showAutocomplete = suggestions.isNotEmpty);
      }
    } else if (trigger == '/') {
      final suggestions = buildSlashCommands(widget.availableSlashCommands)
          .where((c) => c.command.toLowerCase().contains(queryLower))
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
      if (_showAutocomplete != suggestions.isNotEmpty) {
        setState(() => _showAutocomplete = suggestions.isNotEmpty);
      }
    } else {
      _clearAutocomplete();
    }
  }

  void _clearAutocomplete() {
    // Always cancel any pending debounced filter so a close/submit can't
    // be undone by a stale timer firing afterwards.
    _autocompleteDebounce?.cancel();
    if (!_showAutocomplete) return;
    _autocompleteController.clear();
    setState(() => _showAutocomplete = false);
  }

  void _onFocusChanged() {
    _isFocused.value = _focusNode.hasFocus;
    if (!_focusNode.hasFocus) _draftAutoSave.saveNow();
  }

  void _applySuggestion(AutocompleteSuggestion suggestion) {
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.base.offset;
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastWordMatch = RegExp(r'[@/]([\w-]*)$').firstMatch(textBeforeCursor);

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
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // Handle Shift+Enter to insert newline when enterToSend is enabled.
    // This allows Shift+Enter to add a new line while plain Enter sends.
    if (widget.enterToSend &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        HardwareKeyboard.instance.isShiftPressed) {
      final cursorPosition = widget.controller.selection.base.offset;
      if (cursorPosition >= 0) {
        final text = widget.controller.text;
        final newText = text.replaceRange(cursorPosition, cursorPosition, '\n');
        widget.controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursorPosition + 1),
        );
      }
      return KeyEventResult.handled;
    }

    if (!_showAutocomplete) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _autocompleteController.moveSelectionUp();
      // AutocompleteController notifies its listeners — no setState needed.
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _autocompleteController.moveSelectionDown();
      // AutocompleteController notifies its listeners — no setState needed.
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
    // Cancel any pending debounced autocomplete filter — submit is a
    // close-equivalent action and should never leave a stale timer
    // around to flash suggestions over an empty input.
    _autocompleteDebounce?.cancel();
    _cancelDictationForSend();
    HapticFeedback.mediumImpact();
    _sendScaleController
      ..value = 0.0
      ..forward();
    widget.onSend();
  }

  Future<void> _onDictationTap() async {
    if (_isTranscribing || _isStoppingDictation) {
      return;
    }

    if (_isRecording) {
      await _stopAndTranscribe();
      return;
    }

    await _startDictation();
  }

  Future<void> _startDictation() async {
    final sessionId = ++_dictationSessionId;
    try {
      _prepareDictationPreview();
      await _dictationService.start(
        onTranscript: (text) {
          if (_dictationSessionId == sessionId) {
            _replaceDictationPreview(text);
          }
        },
      );
      if (_dictationSessionId != sessionId) {
        await _dictationService.cancel();
        return;
      }
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      setState(() {
        _isRecording = true;
        _dictationStartedAt = DateTime.now();
        _dictationSilenceStartedAt = null;
      });
      _startDictationWatchers();
    } on OfflineDictationException catch (error) {
      if (_dictationSessionId != sessionId) return;
      _dictationSessionId++;
      _showDictationError(error.message);
    } catch (error) {
      if (_dictationSessionId != sessionId) return;
      _dictationSessionId++;
      _showDictationError('Failed to start dictation');
    }
  }

  Future<void> _stopAndTranscribe() async {
    if (_isStoppingDictation) {
      return;
    }
    _isStoppingDictation = true;
    final sessionId = _dictationSessionId;
    _stopDictationWatchers();
    if (!mounted) {
      _isStoppingDictation = false;
      return;
    }
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });

    try {
      final text = await _dictationService.stopAndTranscribe();
      if (!mounted || _dictationSessionId != sessionId) return;
      _replaceDictationPreview(text);
      unawaited(HapticFeedback.lightImpact());
      _focusNode.requestFocus();
    } on OfflineDictationException catch (error) {
      _showDictationError(error.message);
    } catch (error) {
      _showDictationError('Transcription failed');
    } finally {
      _isStoppingDictation = false;
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
    }
  }

  void _cancelDictationForSend() {
    _dictationSessionId++;
    if (!_isRecording && !_isTranscribing && !_isStoppingDictation) {
      return;
    }

    _stopDictationWatchers();
    _dictationPreviewStart = null;
    _dictationPreviewEnd = null;
    _dictationPreviewText = '';
    unawaited(
      _dictationService.cancel().catchError((Object error, StackTrace stack) {
        logger.warning('Failed to cancel dictation after send', error, stack);
      }),
    );
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isTranscribing = false;
      });
    }
    _isStoppingDictation = false;
  }

  void _insertDictatedText(String dictatedText) {
    final trimmed = dictatedText.trim();
    if (trimmed.isEmpty) return;

    final value = widget.controller.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final beforeCursor = text.substring(0, start);
    final afterCursor = text.substring(end);
    final prefix = start > 0 && !RegExp(r'\s$').hasMatch(beforeCursor)
        ? ' '
        : '';
    final suffix = end < text.length && !afterCursor.startsWith(' ') ? ' ' : '';
    final replacement = '$prefix$trimmed$suffix';

    widget.controller.value = TextEditingValue(
      text: text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  void _prepareDictationPreview() {
    final value = widget.controller.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    _dictationPreviewStart = start;
    _dictationPreviewEnd = end;
    _dictationPreviewText = '';
  }

  void _replaceDictationPreview(String dictatedText) {
    if (!mounted) return;
    final trimmed = dictatedText.trim();
    if (trimmed.isEmpty) return;

    final start = _dictationPreviewStart;
    final end = _dictationPreviewEnd;
    final value = widget.controller.value;
    final text = value.text;
    if (start == null ||
        end == null ||
        start < 0 ||
        end < start ||
        end > text.length) {
      _insertDictatedText(trimmed);
      return;
    }

    final currentPreview = text.substring(start, end);
    if (currentPreview != _dictationPreviewText) {
      _insertDictatedText(trimmed);
      return;
    }

    final before = text.substring(0, start);
    final after = text.substring(end);
    final prefix = start > 0 && !RegExp(r'\s$').hasMatch(before) ? ' ' : '';
    final suffix = after.isNotEmpty && !after.startsWith(' ') ? ' ' : '';
    final replacement = '$prefix$trimmed$suffix';

    widget.controller.value = TextEditingValue(
      text: text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
    _dictationPreviewEnd = start + replacement.length;
    _dictationPreviewText = replacement;
  }

  void _showDictationError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _startDictationWatchers() {
    _stopDictationWatchers();
    _dictationMaxTimer = Timer(
      _dictationMaxDuration,
      () => unawaited(_stopAndTranscribe()),
    );
    _dictationLevelSub = _dictationService.levels().listen(
      _handleDictationLevel,
      onError: (_) {},
    );
  }

  void _stopDictationWatchers() {
    _dictationMaxTimer?.cancel();
    _dictationMaxTimer = null;
    unawaited(_dictationLevelSub?.cancel());
    _dictationLevelSub = null;
    _dictationSilenceStartedAt = null;
  }

  void _handleDictationLevel(double levelDb) {
    if (!_isRecording || _isStoppingDictation) {
      return;
    }

    final now = DateTime.now();
    final startedAt = _dictationStartedAt;
    if (startedAt == null ||
        now.difference(startedAt) < _dictationInitialGrace) {
      return;
    }

    if (levelDb > _dictationSilenceThresholdDb) {
      _dictationSilenceStartedAt = null;
      return;
    }

    final silenceStartedAt = _dictationSilenceStartedAt ?? now;
    _dictationSilenceStartedAt = silenceStartedAt;
    if (now.difference(silenceStartedAt) >= _dictationSilenceDuration) {
      unawaited(_stopAndTranscribe());
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
        // ListenableBuilder ensures only the autocomplete list rebuilds when
        // the selection index changes (arrow keys), not the entire ChatInput.
        ListenableBuilder(
          listenable: _autocompleteController,
          builder: (context, _) {
            if (!_showAutocomplete ||
                _autocompleteController.suggestions.isEmpty) {
              return const SizedBox.shrink();
            }
            return FileAutocomplete(
              suggestions: _autocompleteController.suggestions,
              selectedIndex: _autocompleteController.selectedIndex,
              onSelect: (index) {
                _applySuggestion(_autocompleteController.suggestions[index]);
              },
            );
          },
        ),
        _buildInputContainer(context),
      ],
    );
  }

  Widget _buildInputContainer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Slightly lower opacity so the blur shows through.
    final surfaceAlpha = isDark ? 0.82 : 0.88;

    return ClipRRect(
      borderRadius: _containerRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cs.surface.withValues(alpha: surfaceAlpha),
                cs.surface.withValues(alpha: surfaceAlpha + 0.06),
              ],
            ),
            borderRadius: _containerRadius,
            border: Border(
              top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            boxShadow: _cardBoxShadow,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCardInputArea(context),
                  const SizedBox(height: AppSpacing.xs),
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
    final cardColor = cs.surfaceContainerLow;

    // Only the border color depends on focus state — wrap in a
    // ValueListenableBuilder so focus changes don't rebuild the
    // entire ChatInput tree.
    return ValueListenableBuilder<bool>(
      valueListenable: _isFocused,
      builder: (context, isFocused, child) {
        final borderColor = isFocused
            ? cs.primary.withValues(alpha: 0.4)
            : cs.outlineVariant.withValues(alpha: 0.4);
        return AnimatedContainer(
          duration: kBorderAnimDuration,
          curve: AppCurve.standard,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: _containerRadius,
            border: Border.all(color: borderColor, width: 0.5),
            boxShadow: _cardBoxShadow,
          ),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.attachmentController != null)
            _buildAttachmentStrip(context),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.attachmentController != null)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: _AttachButton(onTap: _onAttachTap),
                ),
              Expanded(
                child: _buildTextField(context),
              ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: _DictationButton(
                  isRecording: _isRecording,
                  isTranscribing: _isTranscribing,
                  onTap: _onDictationTap,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.xs,
                  right: AppSpacing.xsm,
                ),
                child: SendButton(
                  isSending: widget.isSending,
                  isSendDisabled: widget.isSendDisabled,
                  onTap: _onSendTap,
                  scaleAnimation: _sendScale,
                  lastDeliveryStatus: widget.lastDeliveryStatus,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------
  // Image attachments
  // -----------------------------------------------------------

  final ImageAttachmentService _attachmentService = ImageAttachmentService();

  Future<void> _onAttachTap() async {
    final controller = widget.attachmentController;
    // Ignore attach while a send is in flight — the controller may be
    // cleared underneath us, which would silently re-stage the image
    // onto the next message's composer.
    if (controller == null || widget.isSending) return;
    final l10n = AppLocalizations.of(context);

    final source = await showModalBottomSheet<_AttachSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final sheetL10n = AppLocalizations.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(sheetL10n.chatAttachFromGallery),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AttachSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(sheetL10n.chatAttachFromCamera),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AttachSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    final result = source == _AttachSource.camera
        ? await _attachmentService.pickFromCameraResult()
        : await _attachmentService.pickFromGalleryResult();
    // Re-check after the async picker gap: a send that started while the
    // picker was open must not have this image staged behind its back.
    final image = result.image;
    if (!mounted || widget.isSending) return;
    if (image == null) {
      if (!result.cancelled) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.chatImageAddFailed)));
      }
      return;
    }

    if (!controller.add(image) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.chatAttachmentLimit(ChatAttachmentController.maxAttachments),
          ),
        ),
      );
    }
  }

  Widget _buildAttachmentStrip(BuildContext context) {
    final controller = widget.attachmentController!;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final images = controller.images;
        if (images.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            0,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < images.length; i++)
                    _AttachmentThumb(
                      image: images[i],
                      onRemove: () => controller.remove(images[i]),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hintColor = cs.onSurfaceVariant.withValues(alpha: 0.7);
    final l10n = AppLocalizations.of(context);

    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      decoration: InputDecoration(
        hintText: _isRecording
            ? 'Listening...'
            : _isTranscribing
            ? 'Transcribing...'
            : l10n.chatInputHint,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(color: hintColor),
        filled: false,
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xsm,
          AppSpacing.sm,
          AppSpacing.xsm,
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
      // When enterToSend is enabled, use send action so Enter triggers
      // onSubmitted. When disabled, use newline so mobile keyboards show
      // a return key.
      textInputAction: widget.enterToSend
          ? TextInputAction.send
          : TextInputAction.newline,
      onSubmitted: widget.enterToSend ? (_) => _onSendTap() : null,
    );
  }

  void _showModelPicker(BuildContext context) {
    final current = widget.modelMode ?? ChatModelMode.defaultModel;
    final settings = ref.read(settingsNotifierProvider);
    showModelPickerSheet(
      context,
      current,
      widget.availableModels,
      (model) => widget.onModelModeChanged?.call(model),
      settings: settings,
      onCustomModelsChanged: (customModels) {
        ref
            .read(settingsNotifierProvider.notifier)
            .updateSetting('customModelModes', customModels);
      },
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

enum _AttachSource { gallery, camera }

class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = AppLocalizations.of(context).chatAttachImage;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: AppTouchTarget.min / 2,
          child: SizedBox.square(
            dimension: AppTouchTarget.min,
            child: Center(
              child: Icon(
                Icons.add_rounded,
                color: cs.onSurfaceVariant,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.image, required this.onRemove});

  final OutgoingImage image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.memory(
              base64Decode(image.base64Data),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Semantics(
              button: true,
              label: l10n.chatRemoveAttachment,
              child: InkResponse(
                onTap: onRemove,
                radius: 14,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: cs.inverseSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: cs.onInverseSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DictationButton extends StatelessWidget {
  const _DictationButton({
    required this.isRecording,
    required this.isTranscribing,
    required this.onTap,
  });

  final bool isRecording;
  final bool isTranscribing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isRecording ? cs.error : cs.onSurfaceVariant;
    final label = isRecording
        ? 'Stop dictation'
        : isTranscribing
        ? 'Transcribing'
        : 'Start dictation';

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: isTranscribing ? null : onTap,
          radius: AppTouchTarget.min / 2,
          child: SizedBox.square(
            dimension: AppTouchTarget.min,
            child: Center(
              child: isTranscribing
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  : Icon(
                      isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
                      color: color,
                      size: 22,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
