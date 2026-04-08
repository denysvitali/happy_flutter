import 'package:flutter/widgets.dart';

/// Tracks lightweight runtime context for performance telemetry.
///
/// This data is intentionally small and ephemeral so it can be attached
/// to tracing events without introducing allocation-heavy bookkeeping.
class PerformanceContextService {
  factory PerformanceContextService() => _instance;
  PerformanceContextService._();

  static final PerformanceContextService _instance =
      PerformanceContextService._();

  String? _currentRoute;

  String? get currentRoute => _currentRoute;

  void setCurrentRoute(String? routeName) {
    if (routeName == null || routeName.isEmpty) return;
    _currentRoute = routeName;
  }
}

class PerformanceRouteObserver extends NavigatorObserver {
  void _update(Route<dynamic>? route) {
    final name = route?.settings.name;
    PerformanceContextService().setCurrentRoute(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _update(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _update(previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({
    Route<dynamic>? newRoute,
    Route<dynamic>? oldRoute,
  }) {
    _update(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
