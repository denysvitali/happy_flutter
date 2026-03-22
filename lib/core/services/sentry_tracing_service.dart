/// Helper service for Sentry tracing operations.
///
/// Provides utilities for creating manual spans and transactions
/// to trace performance-critical paths in the app.
library;

import 'package:sentry_flutter/sentry_flutter.dart';

/// Singleton service for Sentry tracing operations.
///
/// Usage:
/// ```dart
/// final span = SentryTracingService().startSpan(
///   operation: 'chat.load',
///   description: 'Loading messages for session',
/// );
/// // ... do work ...
/// span.finish();
/// ```
class SentryTracingService {
  SentryTracingService._();
  static final SentryTracingService _instance = SentryTracingService._();
  factory SentryTracingService() => _instance;

  /// Starts a child span on the current transaction.
  ///
  /// If no transaction is active, returns null and the caller
  /// should skip span.finish().
  ISentrySpan? startSpan({
    required String operation,
    String? description,
    Map<String, dynamic>? data,
  }) {
    final transaction = Sentry.getSpan();
    if (transaction == null) return null;

    final span = transaction.startChild(
      operation,
      description: description,
    );

    if (data != null) {
      for (final entry in data.entries) {
        span.setData(entry.key, entry.value);
      }
    }

    return span;
  }

  /// Starts a new transaction.
  ///
  /// Use this for top-level operations that should be traced
  /// as complete units of work.
  ISentrySpan startTransaction({
    required String name,
    required String operation,
    bool bindToScope = true,
    Map<String, dynamic>? data,
  }) {
    final transaction = Sentry.startTransaction(
      name,
      operation,
      bindToScope: bindToScope,
    );

    if (data != null) {
      for (final entry in data.entries) {
        transaction.setData(entry.key, entry.value);
      }
    }

    return transaction;
  }

  /// Adds a breadcrumb with timing information.
  void addTimedBreadcrumb({
    required String message,
    required String category,
    required int elapsedMs,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.info,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      message: message,
      category: category,
      level: level,
      data: {
        'elapsedMs': elapsedMs,
        ...?data,
      },
    ));
  }

  /// Adds a breadcrumb for state changes.
  void addStateBreadcrumb({
    required String message,
    required String category,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
    SentryLevel level = SentryLevel.info,
  }) {
    Sentry.addBreadcrumb(Breadcrumb(
      message: message,
      category: category,
      level: level,
      data: {
        'before': before,
        'after': after,
      },
    ));
  }
}
