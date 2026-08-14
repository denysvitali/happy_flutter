import 'dart:async';
import 'dart:convert';

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
import '../../core/utils/snack.dart';
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

part 'chat_input_attachments.dart';
part 'chat_input_dictation.dart';

/// Loads file paths matching the active `@` query.
typedef FileSuggestionsLoader =
    Future<List<AutocompleteSuggestion>> Function(String query);

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
    this.onFileSuggestionsRequested,
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
    this.maxContext,
    this.isSessionOnline = false,
    this.enterToSend = false,
    this.lastDeliveryStatus,
    this.onQueueNextTurn,
    this.sessionFlavor,
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

  /// Optional explicit Codex action that keeps this message out of the
  /// active turn and starts it after that turn finishes.
  final VoidCallback? onQueueNextTurn;

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

  /// Agent flavor for the session (`claude`, `codex`, and so on).
  final String? sessionFlavor;

  /// Slash commands advertised by the current session's agent.
  final List<String> availableSlashCommands;

  /// File path suggestions for `@`-autocomplete.
  final List<AutocompleteSuggestion> fileSuggestions;

  /// Optional asynchronous source for `@`-autocomplete suggestions.
  final FileSuggestionsLoader? onFileSuggestionsRequested;

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

  /// The context window [contextSize] is measured against (from the
  /// selected profile), or null to use the model's default budget.
  final int? maxContext;

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
  final ImageAttachmentService _attachmentService = ImageAttachmentService();
  static final _containerRadius = BorderRadius.circular(AppRadius.xl);

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
  int _fileSuggestionRequestId = 0;
  static final RegExp _autocompleteTrigger = RegExp(r'(@[^\s@]*|/[\w-]*)$');
  static const Duration _autocompleteDebounceDuration = Duration(
    milliseconds: 100,
  );
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isDownloadingModel = false;
  bool _isStoppingDictation = false;
  DateTime? _dictationStartedAt;
  DateTime? _dictationSilenceStartedAt;
  Timer? _dictationMaxTimer;
  // Cancelled by _stopDictationWatchers in chat_input_dictation.dart.
  // ignore: cancel_subscriptions
  StreamSubscription<double>? _dictationLevelSub;
  int? _dictationPreviewStart;
  int? _dictationPreviewEnd;
  String _dictationPreviewText = '';
  int _dictationSessionId = 0;
  final ValueNotifier<bool> _isFocused = ValueNotifier<bool>(false);

  late final AnimationController _sendScaleController;
  late final Animation<double> _sendScale;

  bool get _hasSendableContent {
    return widget.controller.text.trim().isNotEmpty ||
        (widget.attachmentController?.isNotEmpty ?? false);
  }

  void _setComposerState(VoidCallback update) => setState(update);

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
    if (!identical(oldWidget.fileSuggestions, widget.fileSuggestions)) {
      _scheduleAutocompleteUpdate(widget.controller.text);
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
        _autocompleteTrigger.firstMatch(textBeforeCursor) != null;
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
    final lastWordMatch = _autocompleteTrigger.firstMatch(textBeforeCursor);

    if (lastWordMatch == null) {
      _clearAutocomplete();
      return;
    }

    final matchedText = lastWordMatch.group(0)!;
    final trigger = matchedText.substring(0, 1);
    final query = matchedText.substring(1);
    // Hoist normalization out of the per-element loop.
    final queryLower = query.toLowerCase();

    if (trigger == '@') {
      final suggestions = widget.fileSuggestions
          .where((s) => s.label.toLowerCase().contains(queryLower))
          .toList();
      _setAutocompleteSuggestions(suggestions, query);

      final loader = widget.onFileSuggestionsRequested;
      if (loader != null && query.isNotEmpty) {
        final requestId = ++_fileSuggestionRequestId;
        unawaited(
          _loadFileSuggestions(
            loader: loader,
            query: query,
            requestId: requestId,
            localSuggestions: suggestions,
          ),
        );
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
      _setAutocompleteSuggestions(suggestions, query);
    } else {
      _clearAutocomplete();
    }
  }

  Future<void> _loadFileSuggestions({
    required FileSuggestionsLoader loader,
    required String query,
    required int requestId,
    required List<AutocompleteSuggestion> localSuggestions,
  }) async {
    try {
      final remoteSuggestions = await loader(query);
      if (!mounted || requestId != _fileSuggestionRequestId) return;

      final cursorPosition = widget.controller.selection.base.offset;
      if (cursorPosition < 0) return;
      final activeMatch = _autocompleteTrigger.firstMatch(
        widget.controller.text.substring(0, cursorPosition),
      );
      if (activeMatch == null || activeMatch.group(0) != '@$query') return;

      final merged = <String, AutocompleteSuggestion>{
        for (final suggestion in localSuggestions) suggestion.id: suggestion,
        for (final suggestion in remoteSuggestions) suggestion.id: suggestion,
      }.values.toList();
      _setAutocompleteSuggestions(merged, query);
    } catch (error) {
      logger.info('File autocomplete request failed: $error');
    }
  }

  void _setAutocompleteSuggestions(
    List<AutocompleteSuggestion> suggestions,
    String query,
  ) {
    _autocompleteController.setSuggestions(suggestions, query);
    if (_showAutocomplete != suggestions.isNotEmpty) {
      setState(() => _showAutocomplete = suggestions.isNotEmpty);
    }
  }

  void _clearAutocomplete() {
    // Always cancel any pending debounced filter so a close/submit can't
    // be undone by a stale timer firing afterwards.
    _autocompleteDebounce?.cancel();
    _fileSuggestionRequestId++;
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
    final lastWordMatch = _autocompleteTrigger.firstMatch(textBeforeCursor);

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
    if (widget.isSendDisabled || widget.isSending || !_hasSendableContent) {
      return;
    }
    // Cancel any pending debounced autocomplete filter — submit is a
    // close-equivalent action and should never leave a stale timer
    // around to flash suggestions over an empty input.
    _autocompleteDebounce?.cancel();
    _cancelDictationForSend();
    HapticFeedback.mediumImpact();
    if (AppMotion.reduceMotion(context)) {
      _sendScaleController.value = 1.0;
    } else {
      _sendScaleController
        ..value = 0.0
        ..forward();
    }
    widget.onSend();
  }

  void _onQueueNextTurnTap() {
    if (widget.onQueueNextTurn == null ||
        widget.isSendDisabled ||
        widget.isSending ||
        !_hasSendableContent) {
      return;
    }
    _autocompleteDebounce?.cancel();
    _cancelDictationForSend();
    HapticFeedback.mediumImpact();
    widget.onQueueNextTurn!();
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
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: AppBorder.hairline,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            key: const ValueKey<String>('chat-composer-content'),
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoint.contentMax,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
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
                      sessionFlavor: widget.sessionFlavor,
                      maxContext: widget.maxContext,
                    ),
                  ],
                ),
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
          duration: AppMotion.duration(context, kBorderAnimDuration),
          curve: AppCurve.standard,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: _containerRadius,
            border: Border.all(color: borderColor, width: 0.5),
            boxShadow: AppElevationShadow.card(Theme.of(context).brightness),
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
                child: _isDownloadingModel
                    ? ValueListenableBuilder<
                        Map<String, OfflineSttDownloadProgress>
                      >(
                        valueListenable: _dictationService.progress,
                        builder: (context, progressMap, _) {
                          final p =
                              progressMap[_dictationService.selectedModelId];
                          return _buildTextField(context, downloadProgress: p);
                        },
                      )
                    : _buildTextField(context),
              ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: _isDownloadingModel
                    ? ValueListenableBuilder<
                        Map<String, OfflineSttDownloadProgress>
                      >(
                        valueListenable: _dictationService.progress,
                        builder: (context, progressMap, _) {
                          final p =
                              progressMap[_dictationService.selectedModelId];
                          return _DictationButton(
                            isRecording: _isRecording,
                            isTranscribing: _isTranscribing,
                            isDownloadingModel: true,
                            downloadProgress: p,
                            onTap: _onDictationTap,
                          );
                        },
                      )
                    : _DictationButton(
                        isRecording: _isRecording,
                        isTranscribing: _isTranscribing,
                        isDownloadingModel: false,
                        onTap: _onDictationTap,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    widget.controller,
                    if (widget.attachmentController != null)
                      widget.attachmentController!,
                  ]),
                  builder: (context, _) {
                    if (widget.onQueueNextTurn == null) {
                      return const SizedBox.shrink();
                    }
                    return QueueNextTurnButton(
                      isDisabled:
                          widget.isSendDisabled ||
                          widget.isSending ||
                          !_hasSendableContent,
                      onTap: _onQueueNextTurnTap,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.xxs,
                  right: AppSpacing.xsm,
                ),
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    widget.controller,
                    if (widget.attachmentController != null)
                      widget.attachmentController!,
                  ]),
                  builder: (context, _) {
                    return SendButton(
                      isSending: widget.isSending,
                      isSendDisabled:
                          widget.isSendDisabled || !_hasSendableContent,
                      onTap: _onSendTap,
                      scaleAnimation: _sendScale,
                      lastDeliveryStatus: widget.lastDeliveryStatus,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    OfflineSttDownloadProgress? downloadProgress,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hintColor = cs.onSurfaceVariant.withValues(alpha: 0.7);
    final l10n = AppLocalizations.of(context);

    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      decoration: InputDecoration(
        hintText: _isDownloadingModel
            ? (downloadProgress?.label ?? 'Downloading model…')
            : _isRecording
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
          AppSpacing.xs,
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
