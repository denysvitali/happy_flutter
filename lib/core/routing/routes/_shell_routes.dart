part of '../app_router.dart';

/// Top-level shell destinations: the auth landing, the sessions tab shell and
/// the chat screen itself.
///
/// Order matters: go_router matches routes in declaration order, so
/// these lists are concatenated by [createRouter] in the same order
/// they had when they lived inline in it.
List<RouteBase> get shellRoutes => [
    GoRoute(
      path: '/',
      name: 'auth',
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
        return _slidePage(
          AuthGate(child: ChatScreen(sessionId: sessionId)),
          state,
        );
      },
    ),
];
