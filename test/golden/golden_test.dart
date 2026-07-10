// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// App fonts are loaded in flutter_test_config.dart so golden text renders
// with the bundled Inter files instead of Ahem.
import 'package:happy_flutter/core/api/socket_io_client.dart'
    show ConnectionStatus;
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart' show GitStatus, Machine;
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/models/profile.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';
import 'package:happy_flutter/features/chat/message_widget.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';
import 'package:happy_flutter/features/chat/widgets/permission_mode_selector.dart';
import 'package:happy_flutter/features/sessions/sessions_screen.dart';
import 'package:happy_flutter/features/settings/settings_screen.dart';

// ─── Stub Notifiers ───────────────────────────────────────────────────────────

class _StubAuthNotifier extends AuthStateNotifier {
  _StubAuthNotifier(this._state);
  final AuthState _state;
  @override
  AuthState build() => _state;
}

class _StubSettingsNotifier extends SettingsNotifier {
  @override
  Settings build() => Settings();
  @override
  Future<void> updateSetting<T>(String key, T value) async {}
}

class _StubSessionsNotifier extends SessionsNotifier {
  _StubSessionsNotifier(this._sessions);
  final Map<String, Session> _sessions;
  @override
  Map<String, Session> build() => _sessions;
  @override
  void loadFromSync() {} // keep stub state
  @override
  Future<void> refreshFromSync({bool includeMachines = false}) async {} // keep stub state
}

class _StubMachinesNotifier extends MachinesNotifier {
  @override
  Map<String, Machine> build() => {};
  @override
  void loadFromSync() {}
  @override
  Future<void> refreshFromSync() async {}
}

class _StubConnectionNotifier extends ConnectionNotifier {
  @override
  ConnectionStatus build() => ConnectionStatus.connected;
}

class _StubNetworkNotifier extends NetworkNotifier {
  @override
  bool build() => true;
}

class _StubProfileNotifier extends ProfileNotifier {
  @override
  Profile? build() => Profile(id: 'user-1', firstName: 'Alex');
  @override
  void loadFromSync() {}
  @override
  Future<void> refreshFromSync() async {}
}

class _StubCurrentSessionNotifier extends CurrentSessionNotifier {
  @override
  Session? build() => null;
}

class _StubSessionGitStatusNotifier extends SessionGitStatusNotifier {
  @override
  Map<String, GitStatus> build() => {};
}

// ─── Test themes (real app themes — fonts loaded via flutter_test_config) ─────

ThemeData _testLightTheme() => ThemeHelper.buildLightTheme();

ThemeData _testDarkTheme() => ThemeHelper.buildDarkTheme();

// ─── Helpers ──────────────────────────────────────────────────────────────────

Session _makeSession({
  required String id,
  String host = 'macbook-pro.local',
  String path = '/Users/user/project',
  String? name,
  bool active = false,
  bool thinking = false,
  String presence = 'offline',
}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1700000000000,
    updatedAt: 1700050000000,
    active: active,
    activeAt: 1700050000000,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: presence,
    metadata: Metadata(host: host, path: path, name: name),
  );
}

// ignore: type_annotate_public_apis
_commonOverrides(Map<String, Session> sessions) => [
      authStateNotifierProvider
          .overrideWith(() => _StubAuthNotifier(AuthState.authenticated)),
      settingsNotifierProvider.overrideWith(() => _StubSettingsNotifier()),
      sessionsNotifierProvider
          .overrideWith(() => _StubSessionsNotifier(sessions)),
      machinesNotifierProvider.overrideWith(() => _StubMachinesNotifier()),
      connectionNotifierProvider.overrideWith(() => _StubConnectionNotifier()),
      networkNotifierProvider.overrideWith(() => _StubNetworkNotifier()),
      profileNotifierProvider.overrideWith(() => _StubProfileNotifier()),
      currentSessionNotifierProvider
          .overrideWith(() => _StubCurrentSessionNotifier()),
      sessionGitStatusNotifierProvider
          .overrideWith(() => _StubSessionGitStatusNotifier()),
    ];

Widget _buildApp(
  Widget child, {
  bool dark = false,
  Map<String, Session> sessions = const {},
}) {
  return ProviderScope(
    overrides: _commonOverrides(sessions),
    child: MaterialApp(
      theme: _testLightTheme(),
      darkTheme: _testDarkTheme(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  );
}

// ─── Mock data ────────────────────────────────────────────────────────────────

final _mockSessions = {
  's1': _makeSession(
    id: 's1',
    host: 'mbp-work.local',
    path: '/Users/alex/work/backend-api',
    active: true,
    presence: 'online',
  ),
  's2': _makeSession(
    id: 's2',
    host: 'mbp-work.local',
    path: '/Users/alex/work/frontend',
    thinking: true,
  ),
  's3': _makeSession(
    id: 's3',
    host: 'ubuntu-server',
    path: '/home/alex/infra/terraform',
  ),
  's4': _makeSession(
    id: 's4',
    host: 'ubuntu-server',
    path: '/home/alex/scripts/deploy',
  ),
  's5': _makeSession(
    id: 's5',
    host: 'macbook-air.local',
    path: '/Users/alex/personal/side-project',
  ),
};

// ─── Mock chat conversation widget ────────────────────────────────────────────

/// A fully self-contained mock of the chat screen used for golden tests.
/// Shows: user bubble, thinking block (collapsed), tool view, bot response.
/// Does NOT depend on Sync or MMKV — safe to render in tests.
class _MockChatView extends StatelessWidget {
  const _MockChatView();

  static const _messages = [
    {
      'id': 'm1',
      'kind': 'text',
      'role': 'user',
      'content':
          'Implement a binary search function in Python with proper error handling and docstrings.',
    },
    {
      'id': 'm2',
      'kind': 'text',
      'role': 'assistant',
      'isThinking': true,
      'content':
          'The user wants a binary search implementation. I should create a clean, well-documented function that handles edge cases — empty lists, out-of-bounds. I\'ll use type hints for clarity.',
    },
    {
      'id': 'm3',
      'kind': 'tool-call',
      'role': 'assistant',
      'name': 'Read',
      'input': {'file_path': '/home/alex/project/algorithms.py'},
      'state': 'completed',
      'result': '# algorithms.py\n# (empty — no existing implementation)',
    },
    {
      'id': 'm4',
      'kind': 'text',
      'role': 'assistant',
      'content':
          "Here's a clean implementation:\n\n```python\ndef binary_search(arr: list[int], target: int) -> int:\n    \"\"\"Search for target in sorted array.\n    Returns index or -1 if not found.\n    \"\"\"\n    left, right = 0, len(arr) - 1\n    while left <= right:\n        mid = (left + right) // 2\n        if arr[mid] == target:\n            return mid\n        elif arr[mid] < target:\n            left = mid + 1\n        else:\n            right = mid - 1\n    return -1\n```\n\nRuns in **O(log n)** time with no recursion overhead.",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backend API',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Working on it...',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
        // No Stop button here — it's in the toolbar only.
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onPressed: null,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: _messages.map((msg) {
                if (msg['kind'] == 'tool-call') {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: ToolView(
                      tool: Map<String, dynamic>.from(msg),
                      sessionId: 'mock',
                    ),
                  );
                }
                return MessageWidget(
                  messageData: Map<String, dynamic>.from(msg),
                  isFromCurrentUser: msg['role'] == 'user',
                );
              }).toList(),
            ),
          ),
          // Toolbar row — mirrors _InputToolbar layout.
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(color: cs.outlineVariant, width: 0.5),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Permission mode selector (Claude modes only).
                  PermissionModeSelector(
                    selectedMode: PermissionMode.defaultMode,
                    availableModes:
                        PermissionModeExtension.claudeGeminiModes,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  // Model selector pill.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          size: 12,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Default',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Stop button (only in toolbar, NOT in AppBar).
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs + 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: cs.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.stop_rounded,
                          size: 14,
                          color: cs.onErrorContainer,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Stop',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onErrorContainer,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {});

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
  }

  // ── Sessions Screen ─────────────────────────────────────────────────────────

  group('Sessions Screen', () {
    testWidgets('light mode - with sessions', (tester) async {
      setPhoneSize(tester);

      await tester.pumpWidget(
        _buildApp(const SessionsScreen(), sessions: _mockSessions),
      );
      // Pump in increments so Future.delayed stagger timers fire and
      // animations fully settle before capturing the golden screenshot.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/sessions_light.png'),
      );
    });

    testWidgets('dark mode - with sessions', (tester) async {
      setPhoneSize(tester);

      await tester.pumpWidget(
        _buildApp(
          const SessionsScreen(),
          sessions: _mockSessions,
          dark: true,
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/sessions_dark.png'),
      );
    });
  });

  // ── Settings Screen ─────────────────────────────────────────────────────────

  group('Settings Screen', () {
    testWidgets('light mode', (tester) async {
      setPhoneSize(tester);

      await tester.pumpWidget(_buildApp(const SettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/settings_light.png'),
      );
    });

    testWidgets('dark mode', (tester) async {
      setPhoneSize(tester);

      await tester.pumpWidget(_buildApp(const SettingsScreen(), dark: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/settings_dark.png'),
      );
    });
  });

  // ── Tool View ───────────────────────────────────────────────────────────────

  group('Tool View', () {
    Widget _toolApp(Map<String, dynamic> tool, {bool dark = false}) {
      return ProviderScope(
        child: MaterialApp(
          theme: _testLightTheme(),
          darkTheme: _testDarkTheme(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: ToolView(tool: tool, sessionId: 's1'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('bash completed - light', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 500 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _toolApp({
          'name': 'Bash',
          'input': {'command': 'ls -la /home/user/project'},
          'result':
              'total 48\ndrwxr-xr-x  8 user user 4096 Nov 14 .\ndrwxr-xr-x 24 user user 4096 Nov 14 ..\n-rw-r--r--  1 user user  220 Nov 14 .env\ndrwxr-xr-x  2 user user 4096 Nov 14 src\ndrwxr-xr-x  3 user user 4096 Nov 14 lib',
          'state': 'completed',
        }),
      );
      await tester.pump();
      // Tap header to expand (completed tools start collapsed).
      await tester.tap(find.byType(ToolView));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tool_bash_completed_light.png'),
      );
    });

    testWidgets('bash running - light', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 300 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _toolApp({
          'name': 'Bash',
          'input': {'command': 'npm run build --production'},
          'state': 'running',
        }),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tool_bash_running_light.png'),
      );
    });

    testWidgets('bash error - dark', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 400 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _toolApp(
          {
            'name': 'Bash',
            'input': {'command': 'npm run build'},
            'result':
                "npm ERR! Missing script: \"build\"\nnpm ERR! \nnpm ERR! Did you mean one of these?\nnpm ERR!   npm run start",
            'state': 'error',
          },
          dark: true,
        ),
      );
      await tester.pump();
      // Tap header to expand (error tools start collapsed).
      await tester.tap(find.byType(ToolView));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tool_bash_error_dark.png'),
      );
    });

    testWidgets('permission pending - light', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 230 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _toolApp({
          'name': 'Bash',
          'input': {'command': 'rm -rf build/ && flutter pub get'},
          'state': 'pending',
          'permission': {'id': 'perm-1', 'status': 'pending'},
        }),
      );
      await tester.pump();
      // Pending permission auto-expands; settle the footer animation.
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tool_permission_pending_light.png'),
      );
    });

    testWidgets('multi edit - light', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 380 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _toolApp({
          'name': 'MultiEdit',
          'input': {
            'file_path': '/home/user/project/lib/config.dart',
            'edits': [
              {
                'old_string': "const apiUrl = 'https://api.dev.example.com';",
                'new_string': "const apiUrl = 'https://api.example.com';",
              },
              {
                'old_string': 'const retries = 1;',
                'new_string': 'const retries = 3;\nconst timeoutSeconds = 30;',
              },
            ],
          },
          'state': 'completed',
        }),
      );
      await tester.pump();
      // Tap header to expand (completed tools start collapsed).
      await tester.tap(find.byType(ToolView));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tool_multi_edit_light.png'),
      );
    });

    // Sample edit exercising the unified diff renderer: indented lines,
    // small in-line word changes, and an added line — the paths covered
    // by the inline word-diff and tab-expansion logic.
    const _editInput = {
      'file_path': '/home/user/project/lib/auth.dart',
      'old_string':
          'Future<User> login(String email, String password) async {\n'
              '  final response = await client.post(\n'
              "    Uri.parse('\$baseUrl/login'),\n"
              "    body: {'email': email, 'password': password},\n"
              '  );\n'
              '  return User.fromJson(response.body);\n'
              '}',
      'new_string':
          'Future<User> login(String email, String password) async {\n'
              '  final response = await client.post(\n'
              "    Uri.parse('\$baseUrl/v2/login'),\n"
              "    body: {'email': email, 'password': password},\n"
              '  );\n'
              '  _checkStatus(response);\n'
              '  return User.fromJson(response.body);\n'
              '}',
    };

    testWidgets('edit diff - light', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 700 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _toolApp({
          'name': 'Edit',
          'input': _editInput,
          'state': 'completed',
        }),
      );
      await tester.pump();
      // Tap header to expand (completed tools start collapsed).
      await tester.tap(find.byType(ToolView));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tool_edit_diff_light.png'),
      );
    });

    testWidgets('edit diff - dark', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 700 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _toolApp(
          {
            'name': 'Edit',
            'input': _editInput,
            'state': 'completed',
          },
          dark: true,
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(ToolView));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tool_edit_diff_dark.png'),
      );
    });

    testWidgets('read file - light', (tester) async {
      // Taller than the other tool-view goldens: the expanded Read view
      // now renders the file content in a bounded 400dp scrollable pane
      // (see read_view.dart `_kContentMaxHeight`) plus header chrome,
      // so the captured viewport needs to fit the whole expanded card.
      tester.view.physicalSize = const Size(390 * 2, 900 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _toolApp({
          'name': 'Read',
          'input': {'file_path': '/home/user/project/lib/main.dart'},
          'result':
              "import 'package:flutter/material.dart';\n\nvoid main() {\n  runApp(const MyApp());\n}\n\nclass MyApp extends StatelessWidget {\n  const MyApp({super.key});\n\n  @override\n  Widget build(BuildContext context) {\n    return MaterialApp(\n      title: 'Flutter Demo',\n      home: const MyHomePage(),\n    );\n  }\n}",
          'state': 'completed',
        }),
      );
      await tester.pump();
      // Tap header to expand (completed tools start collapsed).
      await tester.tap(find.byType(ToolView));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tool_read_completed_light.png'),
      );
    });
  });

  // ── Chat Screen (mocked conversation) ──────────────────────────────────────

  group('Chat Screen', () {
    Widget _chatApp({bool dark = false}) {
      return MaterialApp(
        theme: _testLightTheme(),
        darkTheme: _testDarkTheme(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        debugShowCheckedModeBanner: false,
        home: const _MockChatView(),
      );
    }

    testWidgets('light mode - running conversation', (tester) async {
      setPhoneSize(tester);

      await tester.pumpWidget(_chatApp());
      // Settle message entrance animations.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/chat_running_light.png'),
      );
    });

    testWidgets('dark mode - running conversation', (tester) async {
      setPhoneSize(tester);

      await tester.pumpWidget(_chatApp(dark: true));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/chat_running_dark.png'),
      );
    });

    testWidgets('light mode - thinking block expanded', (tester) async {
      setPhoneSize(tester);

      await tester.pumpWidget(_chatApp());
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Tap the "Thinking" header label to expand the thinking block.
      await tester.tap(find.text('Thinking').first);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 80));
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/chat_thinking_expanded_light.png'),
      );
    });
  });
}
