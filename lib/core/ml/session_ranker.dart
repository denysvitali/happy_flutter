import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../models/session.dart';
import '../services/logger_service.dart' show logger;
import 'ml_platform_io.dart';

/// Session ranker that blends Gemma semantic scores with heuristics.
/// Falls back to pure heuristics when Gemma is unavailable or disabled.
class SessionRanker {
  SessionRanker({
    GemmaService? gemmaService,
    bool gemmaEnabled = false,
  })  : _gemma = gemmaService ?? GemmaService(),
        _gemmaEnabled = gemmaEnabled;

  final GemmaService _gemma;
  final bool _gemmaEnabled;

  /// Whether Gemma is available and enabled.
  bool get isAvailable => _gemmaEnabled && _gemma.isAvailable;

  /// Initializes the Gemma model if enabled and not yet initialized.
  Future<void> initialize() async {
    if (_gemmaEnabled && !_gemma.isAvailable) {
      await _gemma.initialize();
    }
  }

  /// Ranks sessions by relevance to [query].
  /// Uses Gemma semantic ranking when available and enabled, otherwise
  /// falls back to heuristic ranking (recency + fuzzy match).
  Future<List<Session>> rankSessions(
    String query,
    List<Session> sessions,
  ) async {
    if (sessions.isEmpty) return sessions;

    if (isAvailable) {
      try {
        final sessionMaps = sessions
            .map((s) => {
                  'id': s.id,
                  'name': s.metadata?.name ?? '',
                  'path': s.metadata?.path ?? '',
                  'summary': s.metadata?.summary?.text ?? '',
                  'updatedAt': s.updatedAt,
                  'createdAt': s.createdAt,
                  'pinned': s.pinned,
                })
            .toList();

        final rankedMaps = await _gemma.rankSessions(query, sessionMaps);

        // Merge Gemma scores back with original sessions
        final gemmaScores = {
          for (final m in rankedMaps) m['id'] as String: m['gemmaScore'] as double
        };

        return _blendWithHeuristics(sessions, gemmaScores);
      } catch (e, stack) {
        logger.error('SessionRanker: Gemma ranking failed, using heuristics', e, stack);
        Sentry.captureException(e, stackTrace: stack);
        return _heuristicRank(query, sessions);
      }
    }

    return _heuristicRank(query, sessions);
  }

  /// Classifies a session and returns auto-generated tags.
  Future<List<String>> classifySession(Session session) async {
    if (!isAvailable) return [];
    try {
      final sessionMap = {
        'id': session.id,
        'name': session.metadata?.name ?? '',
        'path': session.metadata?.path ?? '',
      };
      return await _gemma.classifySession(sessionMap);
    } catch (e, stack) {
      logger.error('SessionRanker: classifySession failed', e, stack);
      Sentry.captureException(e, stackTrace: stack);
      return [];
    }
  }

  List<Session> _blendWithHeuristics(
    List<Session> sessions,
    Map<String, double> gemmaScores,
  ) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const recencyWeight = 0.4;
    const gemmaWeight = 0.6;

    return List.from(sessions)
      ..sort((a, b) {
        final scoreA = _computeBlendScore(a, gemmaScores, nowMs, recencyWeight, gemmaWeight);
        final scoreB = _computeBlendScore(b, gemmaScores, nowMs, recencyWeight, gemmaWeight);
        return scoreB.compareTo(scoreA);
      });
  }

  double _computeBlendScore(
    Session session,
    Map<String, double> gemmaScores,
    int nowMs,
    double recencyWeight,
    double gemmaWeight,
  ) {
    // Recency score: exponential decay, half-life of 7 days
    const halfLifeMs = 7 * 24 * 60 * 60 * 1000;
    final ageMs = nowMs - session.updatedAt;
    final recencyScore = _expDecay(ageMs, halfLifeMs);

    // Gemma score (0.0 - 1.0)
    final gemmaScore = gemmaScores[session.id] ?? 0.0;

    return recencyWeight * recencyScore + gemmaWeight * gemmaScore;
  }

  double _expDecay(int ageMs, int halfLifeMs) {
    return _pow(0.5, ageMs / halfLifeMs);
  }

  double _pow(double base, double exp) {
    // Simple power approximation using exp and log
    if (exp == 0) return 1.0;
    if (exp == 1) return base;
    // Use dart:math pow via compute if needed, here using simple approximation
    return base < 0 ? 0 : _fastPow(base, exp);
  }

  double _fastPow(double base, double exp) {
    // Taylor series approximation for base in (0, 1]
    if (base <= 0) return 0.0;
    if (base == 1.0) return 1.0;
    // For base in (0, 1], use exp * log(base)
    // Approximate using iteration
    double result = 1.0;
    var term = 1.0;
    final lnBase = _ln(base);
    for (var i = 1; i < 10; i++) {
      term *= exp * lnBase / i;
      result += term;
    }
    return result.clamp(0.0, 1.0);
  }

  double _ln(double x) {
    // Simple natural log approximation
    if (x <= 0) return double.negativeInfinity;
    if (x == 1) return 0.0;
    // Newton-Raphson
    var guess = x - 1.0;
    for (var i = 0; i < 10; i++) {
      final expGuess = _exp(guess);
      guess -= (expGuess - x) / expGuess;
    }
    return guess;
  }

  double _exp(double x) {
    // Taylor series for e^x
    double result = 1.0;
    double term = 1.0;
    for (var i = 1; i < 20; i++) {
      term *= x / i;
      result += term;
    }
    return result;
  }

  List<Session> _heuristicRank(String query, List<Session> sessions) {
    final queryLower = query.toLowerCase();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const halfLifeMs = 7 * 24 * 60 * 60 * 1000;

    return List.from(sessions)
      ..sort((a, b) {
        // Pinned sessions always first
        if (a.pinned && !b.pinned) return -1;
        if (!a.pinned && b.pinned) return 1;

        // Then by recency score
        final recencyA = _expDecay(nowMs - a.updatedAt, halfLifeMs);
        final recencyB = _expDecay(nowMs - b.updatedAt, halfLifeMs);

        // Then by fuzzy match score if query present
        final matchScoreA = query.isEmpty
            ? 0.0
            : _fuzzyScore(a, queryLower);
        final matchScoreB = query.isEmpty
            ? 0.0
            : _fuzzyScore(b, queryLower);

        final scoreA = recencyA + matchScoreA * 0.3;
        final scoreB = recencyB + matchScoreB * 0.3;

        return scoreB.compareTo(scoreA);
      });
  }

  double _fuzzyScore(Session session, String query) {
    final name = (session.metadata?.name ?? '').toLowerCase();
    final path = (session.metadata?.path ?? '').toLowerCase();
    final summary = (session.metadata?.summary?.text ?? '').toLowerCase();

    if (name.contains(query) || path.contains(query) || summary.contains(query)) {
      return 1.0;
    }

    // Simple character overlap score
    var match = 0.0;
    for (final char in query.split('')) {
      if (name.contains(char)) match += 0.3;
      if (path.contains(char)) match += 0.1;
      if (summary.contains(char)) match += 0.05;
    }
    return match.clamp(0.0, 1.0);
  }

  void dispose() {
    _gemma.dispose();
  }
}
