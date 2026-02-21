// Stub for web platform - no SentryWidget
import 'package:flutter/widgets.dart';

/// A pass-through widget for web that doesn't use Sentry
class SentryWidget extends StatelessWidget {
  const SentryWidget({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// A pass-through observer for web that doesn't use Sentry
class SentryNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic>? route, Route<dynamic>? previousRoute) {}

  @override
  void didPop(Route<dynamic>? route, Route<dynamic>? previousRoute) {}

  @override
  void didRemove(Route<dynamic>? route, Route<dynamic>? previousRoute) {}

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {}

  @override
  void didStartUserGesture(
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
  ) {}

  @override
  void didStopUserGesture() {}
}
