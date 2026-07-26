import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/routing/app_router.dart';

/// Route names are telemetry, not just navigation keys: `_routeName(state)`
/// feeds `state.name` into `PerformanceContextService.currentRoute`, which is
/// stamped onto every span as `current_route`.
void main() {
  Map<String, String> routeNamesByPath(List<RouteBase> routes) {
    return <String, String>{
      for (final route in routes.whereType<GoRoute>())
        if (route.name != null) route.path: route.name!,
    };
  }

  group('shellRoutes', () {
    test('the root path is not named after authentication', () {
      final names = routeNamesByPath(shellRoutes);

      // '/' renders AuthGate(child: SessionsScreen(...)) — the ordinary
      // signed-in sessions list. Naming it 'auth' tagged every span emitted
      // while the user browsed the list with current_route=auth, which
      // caused a slow send to be misdiagnosed as an authentication bounce.
      expect(names['/'], isNot('auth'));
      expect(names['/'], 'home');
    });

    test('route names are unique', () {
      final names = routeNamesByPath(shellRoutes).values.toList();

      expect(names.toSet(), hasLength(names.length));
    });
  });
}
