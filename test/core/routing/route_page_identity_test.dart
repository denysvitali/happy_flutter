// Structural guard for the page-reuse bug class.
//
// go_router keys a page by the route *pattern* (`/chat/:sessionId`), so two
// different parameter values produce the same `Page.key`, `Page.canUpdate`
// returns true, and the Navigator keeps the old route and swaps the child in
// place. Every screen that seeds state from its parameter in `initState`
// (message list, futures, controllers, sync subscriptions) then keeps the old
// state while its widget field reads the new parameter — "clicking session B
// opens session A". The chat route was fixed once with a per-session widget
// key; `routePageKey` now fixes it for the whole table.
//
// The tests below walk the *real* route table so a route added later is
// covered automatically.
//
// Limitation, deliberate: the first group calls the real `pageBuilder`s (the
// wrappers where the key lives) but asserts on the produced `Page` instead of
// pumping it. The real screens cannot be pumped headlessly — they need Sync,
// MMKV, sockets and encryption. The second group therefore pumps a
// lightweight probe screen through the same `routePageKey` helper to prove
// the end-to-end symptom (stale `initState`-seeded state) is gone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/routing/app_router.dart';

/// One leaf route of the real table, with its parameters resolved.
class _RouteEntry {
  const _RouteEntry(this.fullPath, this.parameters);

  final String fullPath;
  final List<String> parameters;

  /// A concrete location for [fullPath] where every parameter takes its
  /// "a" value except [vary], which takes its "b" value.
  String locationWith({String? vary}) {
    var location = fullPath;
    for (final name in parameters) {
      final value = name == vary ? 'value_b_$name' : 'value_a_$name';
      location = location.replaceAll(':$name', value);
    }
    return location;
  }
}

List<_RouteEntry> _leafRoutes() {
  // createRouter() concatenates exactly these four lists; they are used
  // directly so the test does not have to stand up the router's Sentry /
  // OpenTelemetry navigator observers.
  final roots = <RouteBase>[
    ...shellRoutes,
    ...settingsRoutes,
    ...chatRoutes,
    ...featureRoutes,
  ];
  final entries = <_RouteEntry>[];

  void walk(RouteBase route, String parentPath) {
    if (route is! GoRoute) {
      for (final child in route.routes) {
        walk(child, parentPath);
      }
      return;
    }
    final path = route.path.startsWith('/')
        ? route.path
        : '${parentPath == '/' ? '' : parentPath}/${route.path}';
    if (route.routes.isEmpty) {
      final parameters = [
        for (final segment in path.split('/'))
          if (segment.startsWith(':')) segment.substring(1),
      ];
      entries.add(_RouteEntry(path, parameters));
    } else {
      if (route.pageBuilder != null || route.builder != null) {
        final parameters = [
          for (final segment in path.split('/'))
            if (segment.startsWith(':')) segment.substring(1),
        ];
        entries.add(_RouteEntry(path, parameters));
      }
      for (final child in route.routes) {
        walk(child, path);
      }
    }
  }

  for (final route in roots) {
    walk(route, '');
  }
  return entries;
}

/// A screen that copies its parameter once, in `initState`, exactly like the
/// real parameterized screens do with message lists and subscriptions.
class _Probe extends StatefulWidget {
  const _Probe({required this.location, super.key});

  final String location;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  late final String _seeded;

  @override
  void initState() {
    super.initState();
    _seeded = widget.location;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(_seeded),
    );
  }
}

void main() {
  final entries = _leafRoutes();
  final parameterized = entries.where((e) => e.parameters.isNotEmpty).toList();

  test('the route table still has parameterized routes to guard', () {
    expect(entries, isNotEmpty);
    expect(parameterized, isNotEmpty);
  });

  group('every parameterized route builds a parameter-scoped page', () {
    late GoRouter router;
    late RouteConfiguration configuration;

    setUp(() {
      router = GoRouter(
        initialLocation: '/',
        routes: [
          ...shellRoutes,
          ...settingsRoutes,
          ...chatRoutes,
          ...featureRoutes,
        ],
      );
      configuration = router.configuration;
    });

    tearDown(() => router.dispose());

    Page<dynamic> buildPage(BuildContext context, String location) {
      final matchList = configuration.findMatch(Uri.parse(location));
      expect(
        matchList.isError,
        isFalse,
        reason: 'no route matched $location',
      );
      final match = matchList.matches.last;
      final route = match.route as GoRoute;
      final state = match.buildState(configuration, matchList);
      return route.pageBuilder!(context, state);
    }

    testWidgets('two parameter values never produce the same page', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox.shrink();
          },
        ),
      );

      for (final entry in parameterized) {
        final pageA = buildPage(context, entry.locationWith());
        for (final parameter in entry.parameters) {
          final pageB = buildPage(
            context,
            entry.locationWith(vary: parameter),
          );
          expect(
            pageB.key,
            isNot(pageA.key),
            reason:
                '${entry.fullPath} builds the same Page.key for two '
                '"$parameter" values, so go() reuses the previous screen '
                'state',
          );
          // canUpdate is the exact predicate the Navigator uses to decide
          // whether to reuse a route, so assert on it directly.
          expect(
            pageB.canUpdate(pageA),
            isFalse,
            reason:
                '${entry.fullPath}: the Navigator would keep the old route '
                'when only "$parameter" changed',
          );
        }
      }
    });

    testWidgets('parameter-free routes keep one stable page across query '
        'changes', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox.shrink();
          },
        ),
      );

      // SessionsScreen rewrites `?tab=` with router.replace() to keep its own
      // page alive; keying on the query string would remount the tab shell on
      // every tab switch.
      final plain = buildPage(context, '/sessions');
      final tabbed = buildPage(context, '/sessions?tab=loops');
      expect(tabbed.canUpdate(plain), isTrue);
    });
  });

  group('go() between two parameter values remounts the screen', () {
    testWidgets('every parameterized route re-seeds initState state', (
      tester,
    ) async {
      for (final entry in parameterized) {
        for (final parameter in entry.parameters) {
          final a = entry.locationWith();
          final b = entry.locationWith(vary: parameter);
          final router = GoRouter(
            initialLocation: a,
            routes: [
              for (final route in parameterized)
                GoRoute(
                  path: route.fullPath,
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: routePageKey(state),
                    child: _Probe(location: state.uri.path),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                    transitionsBuilder: (_, __, ___, child) => child,
                  ),
                ),
            ],
          );
          await tester.pumpWidget(MaterialApp.router(routerConfig: router));
          await tester.pumpAndSettle();
          expect(find.text(a), findsOneWidget, reason: 'initial $a');

          router.go(b);
          await tester.pumpAndSettle();

          expect(
            find.text(b),
            findsOneWidget,
            reason:
                'go($b) over $a kept the old screen state: '
                '${entry.fullPath} reuses its page across "$parameter"',
          );
          expect(find.text(a), findsNothing);

          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
        }
      }
    });
  });
}
