part of 'chat_input.dart';

extension _ChatInputDictationActions on _ChatInputState {
  Future<void> _onDictationTap() async {
    if (_isTranscribing || _isDownloadingModel || _isStoppingDictation) {
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
    // Surface model download progress before opening the microphone.
    final selected = _dictationService.selectedModel;
    final needsDownload =
        _dictationService.statusFor(selected.id) != OfflineSttStatus.ready;
    if (needsDownload && mounted) {
      _setComposerState(() => _isDownloadingModel = true);
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Downloading ${selected.displayName}'
            '${selected.sizeLabel.isEmpty ? '' : ' (${selected.sizeLabel})'}…',
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    }
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
      _setComposerState(() {
        _isDownloadingModel = false;
        _isRecording = true;
        _dictationStartedAt = DateTime.now();
        _dictationSilenceStartedAt = null;
      });
      _startDictationWatchers();
    } on OfflineDictationException catch (error) {
      if (_dictationSessionId != sessionId) return;
      _dictationSessionId++;
      if (mounted) {
        _setComposerState(() => _isDownloadingModel = false);
      }
      _showDictationError(error.message);
    } catch (error) {
      if (_dictationSessionId != sessionId) return;
      _dictationSessionId++;
      if (mounted) {
        _setComposerState(() => _isDownloadingModel = false);
      }
      _showDictationError(
        needsDownload
            ? 'Failed to download dictation model'
            : 'Failed to start dictation',
      );
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
    _setComposerState(() {
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
        _setComposerState(() => _isTranscribing = false);
      }
    }
  }

  void _cancelDictationForSend() {
    _dictationSessionId++;
    if (!_isRecording &&
        !_isTranscribing &&
        !_isDownloadingModel &&
        !_isStoppingDictation) {
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
      _setComposerState(() {
        _isRecording = false;
        _isTranscribing = false;
        _isDownloadingModel = false;
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
    context.showSnack(message);
  }

  void _startDictationWatchers() {
    _stopDictationWatchers();
    _dictationMaxTimer = Timer(
      _ChatInputState._dictationMaxDuration,
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
        now.difference(startedAt) < _ChatInputState._dictationInitialGrace) {
      return;
    }

    if (levelDb > _ChatInputState._dictationSilenceThresholdDb) {
      _dictationSilenceStartedAt = null;
      return;
    }

    final silenceStartedAt = _dictationSilenceStartedAt ?? now;
    _dictationSilenceStartedAt = silenceStartedAt;
    if (now.difference(silenceStartedAt) >=
        _ChatInputState._dictationSilenceDuration) {
      unawaited(_stopAndTranscribe());
    }
  }
}
