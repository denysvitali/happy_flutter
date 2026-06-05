import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../services/logger_service.dart' show logger;
import 'gemma_model_config.dart';

/// Lazily initializes the flutter_gemma runtime exactly once.
///
/// Kept off the cold-start critical path: the SDK init (FFI + HF token wiring)
/// only runs the first time smart features actually touch the model, instead
/// of unconditionally during `_deferredInit` for every user. Idempotent — the
/// cached future is a cheap no-op after the first call.
Future<void>? _gemmaRuntimeInit;
Future<void> ensureGemmaRuntime() {
  return _gemmaRuntimeInit ??= FlutterGemma.initialize(
    huggingFaceToken: GemmaModelConfig.token,
  );
}

/// Native (Android/iOS/desktop) Gemma service backed by flutter_gemma
/// (MediaPipe LLM Inference). Runs real on-device generation for session
/// ranking and auto-tagging. The model is downloaded on demand; until it is
/// present, [isAvailable] is false and callers fall back to heuristics.
class GemmaService {
  GemmaService();

  InferenceModel? _model;
  bool _initialized = false;

  /// Whether the model is loaded and ready for inference.
  bool get isAvailable => _model != null;

  /// Whether the model file has been downloaded to the device.
  Future<bool> isModelDownloaded() async {
    try {
      await ensureGemmaRuntime();
      return await FlutterGemma.isModelInstalled(
        GemmaModelConfig.modelFilename,
      );
    } catch (e) {
      logger.warning('GemmaService: isModelInstalled check failed: $e');
      return false;
    }
  }

  /// Loads the model into memory if it has already been downloaded.
  /// Never triggers a download — that is an explicit user action via
  /// [downloadModel]. Safe to call repeatedly.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await ensureGemmaRuntime();
      if (!await isModelDownloaded()) {
        logger.info('GemmaService: model not downloaded yet');
        return;
      }
      await _activateAndLoad();
      logger.info('GemmaService: model loaded and ready');
    } catch (e, stack) {
      logger.error('GemmaService: initialize failed', e, stack);
      unawaited(Sentry.captureException(e, stackTrace: stack));
      _model = null;
    }
  }

  /// Downloads the model with progress (0.0–1.0) and loads it on completion.
  /// Emits a final 1.0 once the model is ready, then closes. Errors are
  /// forwarded to the stream so the UI can surface them.
  Stream<double> downloadModel() {
    final controller = StreamController<double>();

    Future<void>(() async {
      try {
        await ensureGemmaRuntime();
        await FlutterGemma.installModel(modelType: GemmaModelConfig.modelType)
            .fromNetwork(
              GemmaModelConfig.modelUrl,
              token: GemmaModelConfig.token,
            )
            .withProgress((p) {
              if (!controller.isClosed) {
                controller.add((p.clamp(0, 100)) / 100.0);
              }
            })
            .install();

        // install() sets the model active; load it into an interpreter.
        await _loadActiveModel();
        if (!controller.isClosed) controller.add(1.0);
        await controller.close();
      } catch (e, stack) {
        // Auth/token failures (HTTP 401) are an expected user-facing
        // condition — the model requires a HuggingFace token that was
        // not provided.  Log at warning and skip Sentry to avoid noise.
        final isAuthError = _isDownloadAuthError(e);
        if (isAuthError) {
          logger.warning('GemmaService: model download auth failure '
              '(no HuggingFace token configured): $e');
        } else {
          logger.error('GemmaService: model download failed', e, stack);
          unawaited(Sentry.captureException(e, stackTrace: stack));
        }
        if (!controller.isClosed) controller.addError(e, stack);
        await controller.close();
      }
    });

    return controller.stream;
  }

  static bool _isDownloadAuthError(Object e) {
    final msg = e.toString();
    return msg.contains('401') ||
        msg.contains('Authentication required') ||
        msg.contains('Unauthorized');
  }

  /// Re-registers the already-downloaded model as active (idempotent install
  /// skips the network when files exist) and loads it.
  Future<void> _activateAndLoad() async {
    await FlutterGemma.installModel(modelType: GemmaModelConfig.modelType)
        .fromNetwork(
          GemmaModelConfig.modelUrl,
          token: GemmaModelConfig.token,
        )
        .install();
    await _loadActiveModel();
  }

  Future<void> _loadActiveModel() async {
    await _model?.close();
    _model = await FlutterGemma.getActiveModel(
      maxTokens: GemmaModelConfig.maxTokens,
    );
  }

  /// Ranks [sessions] by relevance to [query] using a single batched
  /// generation call. Returns the input maps annotated with a `gemmaScore`
  /// (1.0 = most relevant, descending). Falls back to the input order on any
  /// failure so the caller's heuristic blend still has data.
  Future<List<Map<String, dynamic>>> rankSessions(
    String query,
    List<Map<String, dynamic>> sessions,
  ) async {
    final model = _model;
    if (model == null || sessions.isEmpty || query.trim().isEmpty) {
      return sessions;
    }

    try {
      final lines = <String>[];
      for (var i = 0; i < sessions.length; i++) {
        final s = sessions[i];
        final name = (s['name'] as String? ?? '').trim();
        final summary = (s['summary'] as String? ?? '').trim();
        lines.add('$i: $name${summary.isEmpty ? '' : ' — $summary'}');
      }

      final chat = await model.createChat(
        systemInstruction:
            'You rank developer chat sessions by relevance to a search '
            'query. Reply with ONLY a comma-separated list of the session '
            'indices, most relevant first. No prose.',
      );
      await chat.addQueryChunk(
        Message.text(
          text: 'Query: "$query"\nSessions:\n${lines.join('\n')}',
          isUser: true,
        ),
      );
      final response = await chat.generateChatResponse();
      final text = response is TextResponse ? response.token : '';

      final order = _parseIndices(text, sessions.length);
      if (order.isEmpty) return sessions;

      // Assign descending scores by rank position.
      final scored = <Map<String, dynamic>>[];
      for (var rank = 0; rank < order.length; rank++) {
        final idx = order[rank];
        final score = (order.length - rank) / order.length;
        scored.add({...sessions[idx], 'gemmaScore': score});
      }
      // Append any sessions the model omitted, with score 0.
      final seen = order.toSet();
      for (var i = 0; i < sessions.length; i++) {
        if (!seen.contains(i)) {
          scored.add({...sessions[i], 'gemmaScore': 0.0});
        }
      }
      return scored;
    } catch (e, stack) {
      logger.error('GemmaService: rankSessions failed', e, stack);
      unawaited(Sentry.captureException(e, stackTrace: stack));
      return sessions;
    }
  }

  /// Generates up to a few short tags for a session.
  Future<List<String>> classifySession(Map<String, dynamic> session) async {
    final model = _model;
    if (model == null) return [];

    try {
      final name = (session['name'] as String? ?? '').trim();
      final path = (session['path'] as String? ?? '').trim();

      final chat = await model.createChat(
        systemInstruction:
            'You tag developer chat sessions. Reply with ONLY 1-3 short, '
            'lowercase, comma-separated tags. No prose.',
      );
      await chat.addQueryChunk(
        Message.text(
          text: 'Session name: "$name"\nPath: "$path"',
          isUser: true,
        ),
      );
      final response = await chat.generateChatResponse();
      final text = response is TextResponse ? response.token : '';

      return text
          .split(RegExp(r'[,\n]'))
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty && t.length <= 24)
          .take(3)
          .toList();
    } catch (e, stack) {
      logger.error('GemmaService: classifySession failed', e, stack);
      unawaited(Sentry.captureException(e, stackTrace: stack));
      return [];
    }
  }

  /// Parses a comma/space separated list of indices, keeping only valid,
  /// in-range, first-seen entries.
  List<int> _parseIndices(String text, int count) {
    final result = <int>[];
    final seen = <int>{};
    for (final match in RegExp(r'\d+').allMatches(text)) {
      final n = int.tryParse(match.group(0)!);
      if (n != null && n >= 0 && n < count && seen.add(n)) {
        result.add(n);
      }
    }
    return result;
  }

  void dispose() {
    unawaited(_model?.close());
    _model = null;
    _initialized = false;
  }
}
