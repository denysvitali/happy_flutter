import 'dart:async' show unawaited, Timer;

import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';

import '../i18n/app_localizations.dart';
import '../services/logger_service.dart' show logger;
import '../services/offline_dictation_service.dart';

enum OfflineDictationStatus { idle, initializing, ready, error }

class OfflineDictationState {
  const OfflineDictationState({required this.status, this.message});

  const OfflineDictationState.idle()
    : status = OfflineDictationStatus.idle,
      message = null;

  final OfflineDictationStatus status;
  final String? message;

  bool get isInitializing => status == OfflineDictationStatus.initializing;
}

final offlineDictationServiceProvider = Provider<OfflineDictationService>((
  ref,
) {
  final service = OfflineDictationService();
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

class OfflineDictationNotifier extends Notifier<OfflineDictationState> {
  Future<void>? _initializeFuture;
  Timer? _readyTimer;

  @override
  OfflineDictationState build() {
    ref.onDispose(() => _readyTimer?.cancel());
    return const OfflineDictationState.idle();
  }

  Future<void> initialize([BuildContext? context]) {
    final existing = _initializeFuture;
    if (existing != null) {
      return existing;
    }

    state = const OfflineDictationState(
      status: OfflineDictationStatus.initializing,
    );
    _initializeFuture = _initialize(context);
    return _initializeFuture!;
  }

  Future<void> _showReadyToast(BuildContext context) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.transcriptionReady),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _initialize(BuildContext? context) async {
    try {
      await ref.read(offlineDictationServiceProvider).initialize();
      state = const OfflineDictationState(status: OfflineDictationStatus.ready);
      _readyTimer?.cancel();
      _readyTimer = Timer(const Duration(seconds: 2), () {
        state = const OfflineDictationState.idle();
      });
      if (context != null) {
        // _showReadyToast checks context.mounted internally.
        // ignore: use_build_context_synchronously
        unawaited(_showReadyToast(context));
      }
    } on OfflineDictationException catch (error) {
      _initializeFuture = null;
      state = OfflineDictationState(
        status: OfflineDictationStatus.error,
        message: error.message,
      );
    } catch (error, stack) {
      _initializeFuture = null;
      logger.warning(
        'Offline dictation startup initialization failed',
        error,
        stack,
      );
      state = const OfflineDictationState(
        status: OfflineDictationStatus.error,
        message: 'Transcription setup failed',
      );
    }
  }
}

final offlineDictationNotifierProvider =
    NotifierProvider<OfflineDictationNotifier, OfflineDictationState>(
      OfflineDictationNotifier.new,
    );
