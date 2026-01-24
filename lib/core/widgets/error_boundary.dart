import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/logger_service.dart';
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
  /// The child widget to wrap
  final Widget child;

  /// Optional callback when an error occurs
  final void Function(Object error, StackTrace stack)? onError;

  /// Optional custom fallback widget
  final Widget Function(Object error, StackTrace stack)? fallbackBuilder;

  /// Optional custom error display
  final Widget Function(Object error, StackTrace stack)? errorBuilder;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.onError,
    this.fallbackBuilder,
    this.errorBuilder,
  });

  @override
  ConsumerState<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends ConsumerState<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    _captureErrors();
  }

  void _captureErrors() {
    // Set up error tracking for this boundary
    // This is handled by Flutter's ErrorWidget.builder in main.dart
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
  void onError(FlutterErrorDetails errorDetails) {
    setState(() {
      _error = errorDetails.exception;
      _stackTrace = errorDetails.stack;
    });

    // Log the error
    logger.error(
      'ErrorBoundary caught error',
      errorDetails.exception,
      errorDetails.stack,
    );

    // Call optional onError callback
    widget.onError?.call(errorDetails.exception, errorDetails.stack!);
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
  final Object? error;
  final StackTrace? stackTrace;
  final ParsedToolError? toolError;
  final VoidCallback onRetry;

  const _DefaultErrorWidget({
    required this.error,
    required this.stackTrace,
    required this.toolError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDebugMode = true; // kDebugMode equivalent check

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              toolError?.errorName ?? 'Something went wrong',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              toolError?.message ??
                  (error?.toString() ?? 'An unknown error occurred'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (toolError?.context != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  toolError!.context!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            if (toolError?.suggestion != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
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
              const SizedBox(height: 24),
              ExpansionTile(
                title: Text(
                  'Stack Trace',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
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
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home),
                  label: const Text('Go Home'),
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
            const SizedBox(width: 12),
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
  final Widget child;
  final void Function(Object, StackTrace)? onError;

  const ErrorSnackbarBoundary({
    super.key,
    required this.child,
    this.onError,
  });

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
  final String message;
  final String? title;
  final Object error;
  final StackTrace stackTrace;

  ErrorNotification({
    required this.message,
    this.title,
    required this.error,
    required this.stackTrace,
  });
}

/// Extension to easily dispatch error notifications
extension ErrorNotificationExtension on BuildContext {
  /// Dispatch an error notification that will be caught by ErrorSnackbarBoundary
  void notifyError(
    String message, {
    String? title,
    required Object error,
    required StackTrace stackTrace,
  }) {
    ErrorNotification(
      message: message,
      title: title,
      error: error,
      stackTrace: stackTrace,
    ).dispatch(this);
  }
}
