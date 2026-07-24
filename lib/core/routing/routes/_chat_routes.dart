part of '../app_router.dart';

/// Chat-adjacent detail routes: session info, files, message detail, agent
/// conversations, loops and workflow runs.
///
/// Order matters: go_router matches routes in declaration order, so
/// these lists are concatenated by [createRouter] in the same order
/// they had when they lived inline in it.
List<RouteBase> get chatRoutes => [
    GoRoute(
      path: '/session/recent',
      name: 'session-recent',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: SessionRecentScreen()), state),
    ),
    GoRoute(
      path: '/chat/:sessionId/info',
      name: 'session-info',
      pageBuilder: (context, state) {
        final id = _pathParameter(state, 'sessionId');
        if (id == null) return _missingPathParameterPage(state, 'sessionId');
        return _slidePage(
          AuthGate(child: SessionInfoScreen(sessionId: id)),
          state,
        );
      },
    ),
    GoRoute(
      path: '/chat/:sessionId/loops',
      name: 'chat-loops',
      pageBuilder: (context, state) {
        final id = _pathParameter(state, 'sessionId');
        if (id == null) return _missingPathParameterPage(state, 'sessionId');
        return _slidePage(
          AuthGate(child: LoopsScreen(sessionId: id)),
          state,
        );
      },
    ),
    GoRoute(
      path: '/chat/:sessionId/files',
      name: 'session-files',
      pageBuilder: (context, state) {
        final id = _pathParameter(state, 'sessionId');
        if (id == null) return _missingPathParameterPage(state, 'sessionId');
        return _slidePage(
          AuthGate(child: SessionFilesScreen(sessionId: id)),
          state,
        );
      },
    ),
    GoRoute(
      path: '/chat/:sessionId/file',
      name: 'session-file',
      pageBuilder: (context, state) {
        final sid = _pathParameter(state, 'sessionId');
        if (sid == null) {
          return _missingPathParameterPage(state, 'sessionId');
        }
        final extra = state.extra as Map<String, dynamic>?;
        final path2 =
            extra?['path'] as String? ??
            state.uri.queryParameters['path'] ??
            '';
        final content =
            extra?['content'] as String? ??
            state.uri.queryParameters['content'];
        return _slidePage(
          AuthGate(
            child: SessionFileViewerScreen(
              path: path2,
              sessionId: sid,
              content: content,
            ),
          ),
          state,
        );
      },
    ),
    GoRoute(
      path: '/chat/:sessionId/message/:messageId',
      name: 'message-detail',
      pageBuilder: (context, state) {
        final sid = _pathParameter(state, 'sessionId');
        if (sid == null) {
          return _missingPathParameterPage(state, 'sessionId');
        }
        final mid = _pathParameter(state, 'messageId');
        if (mid == null) {
          return _missingPathParameterPage(state, 'messageId');
        }
        final extra = state.extra as Map<String, dynamic>?;
        return _slidePage(
          AuthGate(
            child: MessageDetailScreen(
              sessionId: sid,
              messageId: mid,
              messageData: extra,
            ),
          ),
          state,
        );
      },
    ),
    GoRoute(
      path: '/chat/:sessionId/agent/:messageId',
      name: 'agent-conversation',
      pageBuilder: (context, state) {
        final sid = _pathParameter(state, 'sessionId');
        if (sid == null) {
          return _missingPathParameterPage(state, 'sessionId');
        }
        final mid = _pathParameter(state, 'messageId');
        if (mid == null) {
          return _missingPathParameterPage(state, 'messageId');
        }
        final extra = state.extra as Map<String, dynamic>?;
        return _slidePage(
          AuthGate(
            child: AgentConversationScreen(
              sessionId: sid,
              messageId: mid,
              taskData: extra,
            ),
          ),
          state,
        );
      },
    ),
    GoRoute(
      path: '/chat/:sessionId/workflows',
      name: 'chat-workflows',
      pageBuilder: (context, state) {
        final sid = _pathParameter(state, 'sessionId');
        if (sid == null) {
          return _missingPathParameterPage(state, 'sessionId');
        }
        return _slidePage(
          AuthGate(child: WorkflowsScreen(sessionId: sid)),
          state,
        );
      },
    ),
    GoRoute(
      path: '/chat/:sessionId/workflow/:workflowRunId',
      name: 'chat-workflow-run',
      pageBuilder: (context, state) {
        final sid = _pathParameter(state, 'sessionId');
        if (sid == null) {
          return _missingPathParameterPage(state, 'sessionId');
        }
        final runId = _pathParameter(state, 'workflowRunId');
        if (runId == null) {
          return _missingPathParameterPage(state, 'workflowRunId');
        }
        final extra = state.extra as Map<String, dynamic>?;
        return _slidePage(
          AuthGate(
            child: WorkflowRunScreen(
              sessionId: sid,
              runId: runId,
              taskData: extra,
            ),
          ),
          state,
        );
      },
    ),
];
