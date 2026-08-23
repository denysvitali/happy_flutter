part of '../app_router.dart';

/// Top-level shell destinations: the root landing, the sessions tab shell and
/// the chat screen itself.
///
/// Order matters: go_router matches routes in declaration order, so
/// these lists are concatenated by [createRouter] in the same order
/// they had when they lived inline in it.
List<RouteBase> get shellRoutes => [
    GoRoute(
      path: '/',
      // NOT 'auth'. `_routeName(state)` feeds `state.name` straight into
      // `PerformanceContextService.currentRoute`, which is stamped onto
      // every span as `current_route`. '/' renders the ordinary signed-in
      // sessions list wrapped in an AuthGate, so naming it 'auth' tagged all
      // normal browsing as authentication activity — a 45-second send from
      // this screen was misread as an auth bounce during a production audit.
      // Whether the user is actually signed out is AuthGate's business and
      // belongs in its own attribute, not in the route name.
      name: 'home',
      pageBuilder: (context, state) {
        final tabParam = state.uri.queryParameters['tab'];
        return _fadePage(
          AuthGate(child: SessionsScreen(initialTab: tabParam)),
          state,
        );
      },
    ),
    GoRoute(
      path: '/sessions',
      name: 'sessions',
      pageBuilder: (context, state) {
        final tabParam = state.uri.queryParameters['tab'];
        return _fadePage(
          AuthGate(child: SessionsScreen(initialTab: tabParam)),
          state,
        );
      },
    ),
    GoRoute(
      path: '/chat/:sessionId',
      name: 'chat',
      pageBuilder: (context, state) {
        final sessionId = _pathParameter(state, 'sessionId');
        if (sessionId == null) {
          return _missingPathParameterPage(state, 'sessionId');
        }
        // go_router keys the page by the route *pattern*
        // (`/chat/:sessionId`), so `go('/chat/B')` while `/chat/A` is
        // current reuses A's route and swaps the child in place. ChatScreen
        // seeds messages, visibility and sync subscriptions in initState
        // from `widget.sessionId`; without a per-session key it would keep
        // A's state while `widget.sessionId` reads B — the user "opens" B
        // but sees and acts on A. Every imperative `goNamed('chat')`
        // (command palette, notification tap, send redirect, new-session
        // dialog) hits that path.
        return _slidePage(
          AuthGate(
            child: ChatScreen(
              key: ValueKey<String>('chat:$sessionId'),
              sessionId: sessionId,
            ),
          ),
          state,
        );
      },
    ),
];
