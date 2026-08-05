part of '../app_router.dart';

/// Remaining feature routes: machines, artifacts, terminal, SFTP, voice,
/// friends and the changelog.
///
/// Order matters: go_router matches routes in declaration order, so
/// these lists are concatenated by [createRouter] in the same order
/// they had when they lived inline in it.
List<RouteBase> get featureRoutes => [
    GoRoute(
      path: '/machine/:machineId',
      name: 'machine-detail',
      pageBuilder: (context, state) {
        final id = _pathParameter(state, 'machineId');
        if (id == null) return _missingPathParameterPage(state, 'machineId');
        return _slidePage(
          AuthGate(child: MachineDetailScreen(machineId: id)),
          state,
        );
      },
    ),
    GoRoute(
      path: '/goal-loops',
      name: 'goal-loops',
      pageBuilder: (context, state) =>
          _fadePage(const AuthGate(child: GoalLoopsScreen()), state),
    ),
    GoRoute(
      path: '/artifacts',
      name: 'artifacts',
      pageBuilder: (context, state) =>
          _fadePage(const AuthGate(child: ArtifactsListScreen()), state),
    ),
    GoRoute(
      path: '/artifacts/new',
      name: 'artifact-new',
      pageBuilder: (context, state) =>
          _slideUpPage(const AuthGate(child: NewArtifactScreen()), state),
    ),
    GoRoute(
      path: '/artifacts/:artifactId',
      name: 'artifact-detail',
      pageBuilder: (context, state) {
        final id = _pathParameter(state, 'artifactId');
        if (id == null) {
          return _missingPathParameterPage(state, 'artifactId');
        }
        return _slidePage(
          AuthGate(child: ArtifactDetailScreen(artifactId: id)),
          state,
        );
      },
    ),
    GoRoute(
      path: '/artifacts/:artifactId/edit',
      name: 'artifact-edit',
      pageBuilder: (context, state) {
        final id = _pathParameter(state, 'artifactId');
        if (id == null) {
          return _missingPathParameterPage(state, 'artifactId');
        }
        return _slidePage(
          AuthGate(child: EditArtifactScreen(artifactId: id)),
          state,
        );
      },
    ),
    GoRoute(
      path: '/terminal/connect',
      name: 'terminal-connect',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: TerminalConnectScreen()), state),
    ),
    GoRoute(
      path: '/terminal',
      name: 'terminal',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: TerminalScreen()), state),
    ),
    GoRoute(
      path: '/settings/server',
      name: 'server-settings',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: ServerSettingsScreen()), state),
    ),
    GoRoute(
      path: '/settings/voice/language',
      name: 'voice-language',
      pageBuilder: (context, state) => _slidePage(
        const AuthGate(child: VoiceLanguageSettingsScreen()),
        state,
      ),
    ),
    GoRoute(
      path: '/settings/voice/offline',
      name: 'voice-offline',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: OfflineVoicesScreen()), state),
    ),
    GoRoute(
      path: '/settings/voice/stt-models',
      name: 'offline-stt-models',
      pageBuilder: (context, state) => _slidePage(
        const AuthGate(child: OfflineSttModelsScreen()),
        state,
      ),
    ),
    GoRoute(
      path: '/sftp/logs',
      name: 'sftp-logs',
      pageBuilder: (context, state) {
        final deviceId = state.uri.queryParameters['deviceId'];
        return _slidePage(
          AuthGate(child: SftpLogViewerScreen(initialDeviceId: deviceId)),
          state,
        );
      },
    ),
    GoRoute(
      path: '/sftp/directory',
      name: 'sftp-directory',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final directory = extra?['directory'] as SftpDirectory?;
        if (directory == null) {
          return _slidePage(
            const Scaffold(
              body: Center(child: Text('Missing directory parameter')),
            ),
            state,
          );
        }
        return _slidePage(
          AuthGate(child: SftpDirectoryManagerScreen(directory: directory)),
          state,
        );
      },
    ),
    GoRoute(
      path: '/sftp/connections',
      name: 'sftp-connections',
      pageBuilder: (context, state) {
        final deviceId = state.uri.queryParameters['deviceId'];
        return _slidePage(
          AuthGate(child: SftpConnectionHistoryScreen(deviceId: deviceId)),
          state,
        );
      },
    ),
    GoRoute(
      path: '/friends',
      name: 'friends',
      pageBuilder: (context, state) {
        return _slidePage(const AuthGate(child: FriendsScreen()), state);
      },
    ),
    GoRoute(
      path: '/friends/search',
      name: 'friend-search',
      pageBuilder: (context, state) {
        return _slideUpPage(
          const AuthGate(child: FriendSearchScreen()),
          state,
        );
      },
    ),
    GoRoute(
      path: '/changelog',
      name: 'changelog',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final fromVersion = extra?['fromVersion'] as String?;
        final toVersion = extra?['toVersion'] as String? ?? '';
        return _slidePage(
          AuthGate(
            child: ChangelogScreen(
              fromVersion: fromVersion,
              toVersion: toVersion,
            ),
          ),
          state,
        );
      },
    ),
];
