part of '../app_router.dart';

/// Settings and developer-tools routes, including the nested dev-tools
/// subtree under /settings/developer.
///
/// Order matters: go_router matches routes in declaration order, so
/// these lists are concatenated by [createRouter] in the same order
/// they had when they lived inline in it.
List<RouteBase> get settingsRoutes => [
    GoRoute(
      path: '/settings',
      name: 'settings',
      pageBuilder: (context, state) =>
          _fadePage(const AuthGate(child: SettingsScreen()), state),
    ),
    GoRoute(
      path: '/tasks',
      name: 'tasks',
      pageBuilder: (context, state) {
        final sessionId = state.uri.queryParameters['session'];
        return _fadePage(
          AuthGate(
            child: ZenHomeScreen(
              sessionId: sessionId != null && sessionId.isNotEmpty
                  ? sessionId
                  : null,
            ),
          ),
          state,
        );
      },
    ),
    GoRoute(
      path: '/settings/account',
      name: 'account',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: AccountScreen()), state),
    ),
    GoRoute(
      path: '/settings/account/restore',
      name: 'restore',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: RestoreAccountScreen()), state),
    ),
    GoRoute(
      path: '/settings/account/link',
      name: 'link',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: LinkDeviceScreen()), state),
    ),
    GoRoute(
      path: '/settings/account/devices',
      name: 'devices',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: LinkedDevicesScreen()), state),
    ),
    GoRoute(
      path: '/settings/machines',
      name: 'machines',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: MachinesScreen()), state),
    ),
    GoRoute(
      path: '/settings/sessions/folders',
      name: 'sessions-folders',
      pageBuilder: (context, state) => _slidePage(
        const AuthGate(child: SessionsFoldersSettingsScreen()),
        state,
      ),
    ),
    GoRoute(
      path: '/settings/sessions/auto-archive',
      name: 'sessions-auto-archive',
      pageBuilder: (context, state) => _slidePage(
        const AuthGate(child: AutoArchiveSettingsScreen()),
        state,
      ),
    ),
    GoRoute(
      path: '/settings/voice',
      name: 'voice',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: VoiceSettingsScreen()), state),
    ),
    GoRoute(
      path: '/settings/features',
      name: 'features',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: FeaturesSettingsScreen()), state),
    ),
    GoRoute(
      path: '/settings/profiles',
      name: 'profiles',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: ProfilesScreen()), state),
    ),
    GoRoute(
      path: '/settings/profiles/edit',
      name: 'profile-editor',
      pageBuilder: (context, state) {
        final extra = state.extra as AIBackendProfile?;
        return _slidePage(
          AuthGate(child: ProfileEditorScreen(existing: extra)),
          state,
        );
      },
    ),
    GoRoute(
      path: '/settings/profiles/wizard',
      name: 'profile-wizard',
      pageBuilder: (context, state) =>
          _slideUpPage(const AuthGate(child: ProfileWizardScreen()), state),
    ),
    GoRoute(
      path: '/settings/usage',
      name: 'usage',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: UsageScreen()), state),
    ),
    GoRoute(
      // The screen takes an optional project directory through `extra`, so a
      // session can jump straight to its own policy; a deep link with none
      // lands on the machine's project list instead.
      path: '/settings/sandbox',
      name: 'sandbox',
      pageBuilder: (context, state) {
        final directory = state.extra;
        return _slidePage(
          AuthGate(
            child: SandboxScreen(
              initialDirectory: directory is String && directory.isNotEmpty
                  ? directory
                  : null,
            ),
          ),
          state,
        );
      },
    ),
    GoRoute(
      path: '/settings/mcp-servers',
      name: 'mcp-servers',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: McpServersScreen()), state),
    ),
    GoRoute(
      // Non-URL payload (machine id, known projects, the server being
      // edited) travels via `extra`; a missing payload means the route was
      // deep-linked, so fall back to the picker screen.
      path: '/settings/mcp-servers/edit',
      name: 'mcp-server-edit',
      pageBuilder: (context, state) {
        final args = state.extra;
        if (args is! McpServerEditArgs) {
          return _slidePage(const AuthGate(child: McpServersScreen()), state);
        }
        return _slideUpPage(
          AuthGate(child: McpServerEditScreen(args: args)),
          state,
        );
      },
    ),
    GoRoute(
      path: '/settings/claude-limits',
      name: 'claude-limits',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: ClaudeLimitsScreen()), state),
    ),
    GoRoute(
      path: '/settings/codex-usage',
      name: 'codex-usage',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: CodexUsageScreen()), state),
    ),
    GoRoute(
      path: '/settings/grok-usage',
      name: 'grok-usage',
      pageBuilder: (context, state) =>
          _slidePage(const AuthGate(child: GrokUsageScreen()), state),
    ),
    GoRoute(
      path: '/settings/developer',
      name: 'developer',
      pageBuilder: (context, state) =>
          _slidePage(AuthGate(child: DeveloperScreen()), state),
      routes: [
        GoRoute(
          path: 'logs',
          name: 'dev-logs',
          pageBuilder: (context, state) =>
              _slidePage(AuthGate(child: const DevLogsScreen()), state),
        ),
        GoRoute(
          path: 'network',
          name: 'dev-network',
          pageBuilder: (context, state) => _slidePage(
            const AuthGate(child: NetworkInspectorScreen()),
            state,
          ),
        ),
        GoRoute(
          path: 'power',
          name: 'dev-power',
          pageBuilder: (context, state) => _slidePage(
            const AuthGate(child: PowerDiagnosticsScreen()),
            state,
          ),
        ),
        GoRoute(
          path: 'encryption',
          name: 'dev-encryption',
          pageBuilder: (context, state) => _slidePage(
            const AuthGate(child: EncryptionDebugScreen()),
            state,
          ),
        ),
        GoRoute(
          path: 'session',
          name: 'dev-session',
          pageBuilder: (context, state) =>
              _slidePage(const AuthGate(child: SessionDebugScreen()), state),
        ),
        GoRoute(
          path: 'notifications',
          name: 'dev-notifications',
          pageBuilder: (context, state) => _slidePage(
            const AuthGate(child: NotificationTestScreen()),
            state,
          ),
        ),
      ],
    ),
];
