import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart' as sentry;

import 'sentry_config.dart';

class SentryWidget extends StatelessWidget {
  const SentryWidget({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!sentryEnabled) return child;
    return sentry.SentryWidget(child: child);
  }
}

class SentryNavigatorObserver extends NavigatorObserver {
  SentryNavigatorObserver()
    : _delegate = sentryEnabled && sentryEnableNavigationObserver
          ? sentry.SentryNavigatorObserver()
          : null;

  final NavigatorObserver? _delegate;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _delegate?.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _delegate?.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _delegate?.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _delegate?.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    _delegate?.didStartUserGesture(route, previousRoute);
  }

  @override
  void didStopUserGesture() {
    _delegate?.didStopUserGesture();
  }
}
