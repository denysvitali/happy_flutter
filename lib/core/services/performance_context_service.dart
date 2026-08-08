import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, visibleForTesting;
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
  String? _currentSessionsView;
  final ValueNotifier<String?> _routeListenable = ValueNotifier<String?>(null);

  String? get currentRoute => _currentRoute;
  String? get currentSessionsView => _currentSessionsView;
  ValueListenable<String?> get routeListenable => _routeListenable;

  void setCurrentRoute(String? routeName) {
    final nextRoute = _normalizeRouteName(routeName);
    if (_currentRoute == nextRoute) return;
    _currentRoute = nextRoute;
    _routeListenable.value = nextRoute;
  }

  /// Records the bounded sessions presentation currently visible to the user.
  ///
  /// Unlike routes, the sessions modes share the `home` route. Keeping this
  /// separate lets frame telemetry distinguish Mission Control from the
  /// folder, date, and unread-focus views without introducing an unbounded
  /// label.
  void setCurrentSessionsView(String? sessionsView) {
    _currentSessionsView = switch (sessionsView) {
      null || '' => null,
      'mission_control' ||
      'mission_control_folder' ||
      'folder' ||
      'unread_focus' => sessionsView,
      _ => 'other',
    };
  }

  @visibleForTesting
  void resetForTesting() {
    _currentRoute = null;
    _currentSessionsView = null;
    _routeListenable.value = null;
  }

  static String? _normalizeRouteName(String? routeName) {
    if (routeName == null || routeName.isEmpty) return null;
    return routeName;
  }
}

class PerformanceRouteObserver extends NavigatorObserver {
  void _update(Route<dynamic>? route) {
    PerformanceContextService().setCurrentRoute(_routeName(route));
  }

  String? _routeName(Route<dynamic>? route) {
    return PerformanceContextService._normalizeRouteName(route?.settings.name);
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
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _update(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
