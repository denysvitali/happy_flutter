import 'dart:async';

import 'package:riverpod/riverpod.dart';

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

  Future<void> initialize() {
    final existing = _initializeFuture;
    if (existing != null) {
      return existing;
    }

    state = const OfflineDictationState(
      status: OfflineDictationStatus.initializing,
    );
    _initializeFuture = _initialize();
    return _initializeFuture!;
  }

  Future<void> _initialize() async {
    try {
      await ref.read(offlineDictationServiceProvider).initialize();
      state = const OfflineDictationState(status: OfflineDictationStatus.ready);
      _readyTimer?.cancel();
      _readyTimer = Timer(const Duration(seconds: 2), () {
        state = const OfflineDictationState.idle();
      });
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
