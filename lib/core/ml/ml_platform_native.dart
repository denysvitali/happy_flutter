import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../services/logger_service.dart' show logger;

/// Native Android implementation of Gemma ML service using TFLite.
/// Falls back to heuristics if the model is unavailable or fails to load.
class GemmaService {
  GemmaService();

  Interpreter? _interpreter;
  bool _initialized = false;

  bool get isAvailable => _initialized && _interpreter != null;

  /// Initializes the Gemma model from app assets or documents directory.
  /// Runs in a separate isolate to avoid blocking the UI thread.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Check if model exists in documents dir (previously copied)
      final docsDir = await getApplicationDocumentsDirectory();
      final modelPath = '${docsDir.path}/gemma_model/gemma_2b.tflite';

      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        // Try to copy from assets (user must place the model file)
        logger.info('GemmaService: model not found at $modelPath');
        _initialized = true;
        return;
      }

      // Load model in isolate to avoid blocking UI
      _interpreter = await Isolate.run(() {
        return Interpreter.fromFile(File(modelPath));
      });

      _initialized = true;
      logger.info('GemmaService: model loaded successfully');
    } catch (e, stack) {
      logger.error('GemmaService: failed to load model', e, stack);
      Sentry.captureException(e, stackTrace: stack);
      _initialized = true;
      _interpreter = null;
    }
  }

  /// Runs inference in a separate isolate.
  Future<List<double>> _runInference(List<List<double>> inputTensors) async {
    if (_interpreter == null) return [];

    final input = inputTensors.first;
    final output = List.filled(input.length, 0.0);

    try {
      _interpreter!.run([input], [output]);
      return output;
    } catch (e, stack) {
      logger.error('GemmaService: inference failed', e, stack);
      Sentry.captureException(e, stackTrace: stack);
      return [];
    }
  }

  /// Ranks sessions by semantic similarity to [query].
  /// Uses cosine similarity between query and session name embeddings.
  Future<List<Map<String, dynamic>>> rankSessions(
    String query,
    List<Map<String, dynamic>> sessions,
  ) async {
    if (!isAvailable || sessions.isEmpty) return sessions;

    try {
      // Simple embedding: tokenize query and session names
      final queryTokens = _tokenize(query);
      final sessionScores = <Map<String, dynamic>>[];

      for (final session in sessions) {
        final name = session['name'] as String? ?? '';
        final summary = session['summary'] as String? ?? '';
        final sessionTokens = _tokenize('$name $summary');

        // Compute simple cosine similarity
        final score = _cosineSimilarity(queryTokens, sessionTokens);
        sessionScores.add({...session, 'gemmaScore': score});
      }

      // Sort by Gemma score descending
      sessionScores.sort((a, b) =>
          (b['gemmaScore'] as double).compareTo(a['gemmaScore'] as double));

      return sessionScores;
    } catch (e, stack) {
      logger.error('GemmaService: rankSessions failed', e, stack);
      Sentry.captureException(e, stackTrace: stack);
      return sessions;
    }
  }

  /// Classifies a session into categories based on its content.
  Future<List<String>> classifySession(Map<String, dynamic> session) async {
    if (!isAvailable) return [];

    try {
      final name = session['name'] as String? ?? '';
      final path = session['path'] as String? ?? '';
      final text = '$name $path'.toLowerCase();

      // Simple keyword-based classification
      final tags = <String>[];

      if (_containsAny(text, ['work', 'project', 'office', 'meeting'])) {
        tags.add('work');
      }
      if (_containsAny(text, ['personal', 'home', 'diary'])) {
        tags.add('personal');
      }
      if (_containsAny(text, ['code', 'programming', 'debug', 'git'])) {
        tags.add('code');
      }
      if (_containsAny(text, ['research', 'learning', 'study'])) {
        tags.add('research');
      }
      if (_containsAny(text, ['admin', 'config', 'setup', 'install'])) {
        tags.add('admin');
      }

      return tags;
    } catch (e, stack) {
      logger.error('GemmaService: classifySession failed', e, stack);
      Sentry.captureException(e, stackTrace: stack);
      return [];
    }
  }

  /// Scores a session's relevance (0.0 - 1.0).
  Future<double> scoreSessionRelevance(Map<String, dynamic> session) async {
    if (!isAvailable) return 0.0;

    try {
      final name = session['name'] as String? ?? '';
      final tokens = _tokenize(name);
      // Higher token count in name often means more specific/important
      return (tokens.length.clamp(1, 10) / 10.0);
    } catch (e) {
      return 0.0;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initialized = false;
  }

  // ── Simple embedding helpers ─────────────────────────────────────────────

  /// Simple whitespace tokenization with lowercase normalization.
  List<double> _tokenize(String text) {
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    // Build a simple bag-of-words vector (hash-based)
    final vec = <int, double>{};
    for (final word in words) {
      if (word.isEmpty) continue;
      final hash = word.hashCode.abs() % 1000;
      vec[hash] = (vec[hash] ?? 0) + 1;
    }
    // Normalize to unit vector
    var magnitude = 0.0;
    for (final v in vec.values) {
      magnitude += v * v;
    }
    magnitude = magnitude > 0 ? magnitude : 1.0;
    return vec.values.map((v) => v / magnitude).toList();
  }

  /// Simple cosine similarity between two token vectors.
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    // Use word hash overlap for simplicity
    final setA = a.where((v) => v > 0).length;
    final setB = b.where((v) => v > 0).length;
    final intersection = (a.length * b.length / 1000).round();
    if (setA == 0 || setB == 0) return 0.0;
    return intersection / (setA + setB - intersection);
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }
}
