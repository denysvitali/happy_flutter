import 'package:flutter/foundation.dart' show FlutterExceptionHandler, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../i18n/app_localizations.dart';
import '../services/logger_service.dart';
import '../theme/app_tokens.dart';
import '../utils/tool_error_parser.dart';

/// Error boundary widget that catches and displays errors gracefully.
///
/// Wraps child widgets and displays a fallback UI when errors occur.
/// In debug mode, shows detailed error information including stack traces.
/// In release mode, shows a user-friendly error message.
///
/// Usage:
/// ```dart
/// ErrorBoundary(
///   child: MyWidget(),
///   onError: (error, stack) {
///     logger.error('Widget error', error, stack);
///   },
/// )
/// ```
class ErrorBoundary extends ConsumerStatefulWidget {

  const ErrorBoundary({
    required this.child, super.key,
    this.onError,
    this.fallbackBuilder,
    this.errorBuilder,
  });
  /// The child widget to wrap
  final Widget child;

  /// Optional callback when an error occurs
  final void Function(Object error, StackTrace stack)? onError;

  /// Optional custom fallback widget
  final Widget Function(Object error, StackTrace stack)? fallbackBuilder;

  /// Optional custom error display
  final Widget Function(Object error, StackTrace stack)? errorBuilder;

  @override
  ConsumerState<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends ConsumerState<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  // Dedupe identical errors so a widget that throws on every frame does
  // not generate one logger entry + one Sentry envelope per failed
  // subtree per frame. Without this, a single null-unwrap in a tool
  // view list locks up the UI isolate on log + envelope serialization.
  static final Map<String, DateTime> _lastReportedAt = {};
  static const Duration _reportWindow = Duration(seconds: 1);

  static String _fingerprint(Object error, StackTrace? stack) {
    final type = error.runtimeType.toString();
    final firstFrame = stack
        ?.toString()
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    return '$type|$firstFrame';
  }

  /// True when this error fingerprint has not been reported in the
  /// last [_reportWindow]. Side-effect: stamps the key on accept.
  static bool _shouldReport(Object error, StackTrace? stack) {
    final key = _fingerprint(error, stack);
    final now = DateTime.now();
    final last = _lastReportedAt[key];
    if (last != null && now.difference(last) < _reportWindow) {
      return false;
    }
    _lastReportedAt[key] = now;
    // Light-weight GC so the map does not grow unbounded.
    if (_lastReportedAt.length > 64) {
      _lastReportedAt.removeWhere(
        (_, t) => now.difference(t) > _reportWindow * 5,
      );
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _captureErrors();
  }

  void _captureErrors() {
    // Capture Flutter framework errors (e.g. layout, rendering errors).
    // Store the previous handler so we chain to it.
    _previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      _handleError(details);
      // Forward to previous handler (e.g. Sentry) only when this
      // fingerprint passes the dedupe window — see _shouldReport in
      // _handleError. We must NOT forward unconditionally, otherwise
      // Sentry receives one envelope per failed widget per frame.
    };

    // Replace the default red error widget with our own.
    _previousErrorWidgetBuilder = ErrorWidget.builder;
    ErrorWidget.builder = (details) {
      if (_shouldReport(details.exception, details.stack)) {
        logger.error(
          'ErrorWidget built for error',
          details.exception,
          details.stack,
        );
        widget.onError?.call(
          details.exception,
          details.stack ?? StackTrace.empty,
        );
      }
      return _ErrorWidgetFallback(details: details);
    };
  }

  FlutterExceptionHandler? _previousOnError;
  ErrorWidgetBuilder? _previousErrorWidgetBuilder;

  void _handleError(FlutterErrorDetails errorDetails) {
    if (!mounted) return;
    final shouldReport = _shouldReport(
      errorDetails.exception,
      errorDetails.stack,
    );

    if (_error == null) {
      setState(() {
        _error = errorDetails.exception;
        _stackTrace = errorDetails.stack;
      });
    }

    if (!shouldReport) return;

    logger.error(
      'ErrorBoundary caught error',
      errorDetails.exception,
      errorDetails.stack,
    );

    widget.onError?.call(
      errorDetails.exception,
      errorDetails.stack ?? StackTrace.empty,
    );

    _previousOnError?.call(errorDetails);
  }

  @override
  void didUpdateWidget(ErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      _error = null;
      _stackTrace = null;
    }
  }

  @override
  void dispose() {
    // Restore previous handlers.
    FlutterError.onError = _previousOnError;
    ErrorWidget.builder =
        _previousErrorWidgetBuilder ?? _defaultErrorBuilder;
    super.dispose();
  }

  static Widget _defaultErrorBuilder(FlutterErrorDetails details) =>
      ErrorWidget(details.exception);

  void onError(FlutterErrorDetails errorDetails) {
    _handleError(errorDetails);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      // Check for tool error parsing
      final toolError = (_error is String)
          ? ToolErrorParser.parse(_error! as String)
          : null;

      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(_error!, _stackTrace!);
      }

      return _DefaultErrorWidget(
        error: _error,
        stackTrace: _stackTrace,
        toolError: toolError,
        onRetry: () {
          setState(() {
            _error = null;
            _stackTrace = null;
          });
        },
      );
    }

    return widget.child;
  }
}

/// Default error display widget
class _DefaultErrorWidget extends StatelessWidget {

  const _DefaultErrorWidget({
    required this.error,
    required this.stackTrace,
    required this.toolError,
    required this.onRetry,
  });
  final Object? error;
  final StackTrace? stackTrace;
  final ParsedToolError? toolError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const isDebugMode = kDebugMode;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              toolError?.errorName ?? 'Something went wrong',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              toolError?.message ??
                  (error?.toString() ?? 'An unknown error occurred'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (toolError?.context != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  toolError!.context!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            if (toolError?.suggestion != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        toolError!.suggestion!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isDebugMode && stackTrace != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              ExpansionTile(
                title: Text(
                  'Stack Trace',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: SelectableText(
                      stackTrace.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(AppLocalizations.of(context).commonTryAgain),
                ),
                const SizedBox(width: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home),
                  label: Text(AppLocalizations.of(context).commonGoHome),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Global error snackbar manager for showing errors from anywhere in the app
class ErrorSnackbarManager {
  static GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Initialize the snackbar manager with a scaffold messenger key
  static void init(GlobalKey<ScaffoldMessengerState> key) {
    _scaffoldKey = key;
  }

  /// Show an error snackbar
  static void show(
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 5),
  }) {
    final context = _scaffoldKey.currentState?.context;
    if (context == null) return;

    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: theme.colorScheme.errorContainer,
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: theme.colorScheme.onErrorContainer,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show a tool error snackbar with parsed information
  static void showToolError(String rawError) {
    final parsed = ToolErrorParser.parse(rawError);
    if (parsed != null) {
      show(
        parsed.message,
        title: parsed.errorName,
      );
    } else {
      show(rawError, title: 'Error');
    }
  }

  /// Hide the current snackbar
  static void hide() {
    _scaffoldKey.currentState?.hideCurrentSnackBar();
  }
}

/// Widget that displays errors in a snackbar when they occur
class ErrorSnackbarBoundary extends StatelessWidget {

  const ErrorSnackbarBoundary({
    required this.child, super.key,
    this.onError,
  });
  final Widget child;
  final void Function(Object, StackTrace)? onError;

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: Builder(
        builder: (context) {
          // Register error handler
          return Listener(
            onPointerDown: (_) {
              // Clear any existing snackbars when user interacts
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
            child: NotificationListener<ErrorNotification>(
              onNotification: (notification) {
                ErrorSnackbarManager.show(
                  notification.message,
                  title: notification.title,
                );
                onError?.call(notification.error, notification.stackTrace);
                return true;
              },
              child: child,
            ),
          );
        },
      ),
    );
  }
}

/// Notification for errors that should be shown as snackbars
class ErrorNotification extends Notification {

  ErrorNotification({
    required this.message,
    required this.error, required this.stackTrace, this.title,
  });
  final String message;
  final String? title;
  final Object error;
  final StackTrace stackTrace;
}

/// Extension to easily dispatch error notifications
extension ErrorNotificationExtension on BuildContext {
  /// Dispatch an error notification that will be caught by
  void notifyError(
    String message, {
    required Object error, required StackTrace stackTrace, String? title,
  }) {
    ErrorNotification(
      message: message,
      title: title,
      error: error,
      stackTrace: stackTrace,
    ).dispatch(this);
  }
}

/// Fallback widget shown in place of the default red error screen.
class _ErrorWidgetFallback extends StatelessWidget {

  const _ErrorWidgetFallback({required this.details});
  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              kDebugMode
                  ? details.exceptionAsString()
                  : 'An error occurred',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
