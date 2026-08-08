import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/mcp_server.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/machines_notifier.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/types/remote_feature_failure.dart';
import 'package:happy_flutter/features/mcp/mcp_servers_screen.dart';

class _StubMachinesNotifier extends MachinesNotifier {
  _StubMachinesNotifier(this._initial);

  final Map<String, Machine> _initial;

  @override
  Map<String, Machine> build() => _initial;

  @override
  Future<void> refreshFromSync() async {}
}

Machine _onlineMachine({required String id}) => Machine(
  id: id,
  seq: 1,
  createdAt: 1000,
  updatedAt: 2000,
  active: true,
  // Inside the 120s online window so the screen auto-selects it.
  activeAt: DateTime.now().millisecondsSinceEpoch,
  metadataVersion: 1,
  daemonStateVersion: 1,
  metadata: MachineMetadata(displayName: id),
);

Map<String, dynamic> _snapshot({
  List<Map<String, dynamic>> servers = const [],
  List<String> projects = const [],
  List<String> warnings = const [],
}) => <String, dynamic>{
  'success': true,
  'claudeConfigPath': '/home/dev/.claude.json',
  'userSettingsPath': '/home/dev/.claude/settings.json',
  'projects': projects,
  'servers': servers,
  'warnings': warnings,
  'enableAllProjectMcpServers': false,
};

Map<String, dynamic> _stdioServer({
  required String name,
  String scope = 'user',
  bool enabled = true,
  bool disabled = false,
  String? disabledReason,
  bool shadowed = false,
  bool needsAuth = false,
}) => <String, dynamic>{
  'name': name,
  'scope': scope,
  'transport': 'stdio',
  'command': '$name-mcp',
  'args': <String>['serve'],
  'env': <String, String>{'TOKEN': 'secret'},
  'enabled': enabled,
  'disabled': disabled,
  if (disabledReason != null) 'disabledReason': disabledReason,
  'shadowed': shadowed,
  'needsAuth': needsAuth,
  'sourcePath': '/home/dev/.claude.json',
};

Future<void> _pumpScreen(
  WidgetTester tester, {
  Map<String, Machine>? machines,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        machinesNotifierProvider.overrideWith(
          () => _StubMachinesNotifier(
            machines ?? {'m1': _onlineMachine(id: 'm1')},
          ),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const McpServersScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  test('failed daemon snapshots retain a stable failure kind', () {
    final response = McpConfigResponse.fromJson(const <String, dynamic>{
      'success': false,
      'error': 'arbitrary prose',
    });

    expect(response.failureKind, RemoteFeatureFailureKind.rejected);
  });

  late Sync sync;
  late List<({String method, Map<String, dynamic> params})> calls;

  setUp(() {
    sync = Sync();
    calls = [];
  });

  tearDown(() {
    sync.testMachineRPCOverride = null;
  });

  void stubRpc(Map<String, dynamic> Function(String method) respond) {
    sync.testMachineRPCOverride = (machineId, method, params) async {
      calls.add((method: method, params: params));
      return respond(method);
    };
  }

  group('McpServersScreen', () {
    testWidgets('lists servers grouped by scope with their target', (
      tester,
    ) async {
      stubRpc(
        (_) => _snapshot(
          servers: [
            _stdioServer(name: 'search'),
            _stdioServer(name: 'chromium', scope: 'local'),
          ],
          projects: ['/home/dev/git/proj'],
        ),
      );

      await _pumpScreen(tester);

      expect(calls.single.method, 'mcp-list');
      expect(find.text('search'), findsOneWidget);
      expect(find.text('chromium'), findsOneWidget);
      expect(find.text('search-mcp serve'), findsOneWidget);
      // Two scopes present -> two switches, one per server row.
      expect(find.byType(Switch), findsNWidgets(2));
    });

    testWidgets('shows an empty state when the machine declares no servers', (
      tester,
    ) async {
      stubRpc((_) => _snapshot());

      await _pumpScreen(tester);

      expect(find.text('No MCP servers'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('surfaces a daemon failure with a retry affordance', (
      tester,
    ) async {
      stubRpc(
        (_) => <String, dynamic>{'success': false, 'error': 'machine offline'},
      );

      await _pumpScreen(tester);

      expect(
        find.text(
          'The machine rejected the request. Check the values and try again.',
        ),
        findsOneWidget,
      );
      // The machine picker stays reachable so the user can switch machines.
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('toggling a server sends mcp-toggle with its scope and name', (
      tester,
    ) async {
      stubRpc(
        (method) => switch (method) {
          'mcp-toggle' => _snapshot(
            servers: [
              _stdioServer(
                name: 'search',
                enabled: false,
                disabled: true,
                disabledReason: 'sidecar',
              ),
            ],
          ),
          _ => _snapshot(servers: [_stdioServer(name: 'search')]),
        },
      );

      await _pumpScreen(tester);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final toggle = calls.last;
      expect(toggle.method, 'mcp-toggle');
      expect(toggle.params['scope'], 'user');
      expect(toggle.params['name'], 'search');
      expect(toggle.params['enabled'], isFalse);
      // The response snapshot is authoritative — the row reflects it.
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('enabling a server requires reviewing its trust details', (
      tester,
    ) async {
      stubRpc(
        (method) => _snapshot(
          servers: [
            _stdioServer(name: 'search', enabled: method == 'mcp-toggle'),
          ],
        ),
      );

      await _pumpScreen(tester);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('Enable search?'), findsOneWidget);
      expect(calls.where((call) => call.method == 'mcp-toggle'), isEmpty);

      await tester.tap(find.text('Enable server'));
      await tester.pumpAndSettle();

      expect(calls.last.method, 'mcp-toggle');
      expect(calls.last.params['enabled'], isTrue);
    });

    testWidgets('renders shadowed, needs-auth, and approval badges', (
      tester,
    ) async {
      stubRpc(
        (_) => _snapshot(
          servers: [
            _stdioServer(name: 'dup', shadowed: true, needsAuth: true),
            _stdioServer(
              name: 'shared',
              scope: 'project',
              enabled: false,
              disabledReason: 'awaiting-approval',
            ),
          ],
        ),
      );

      await _pumpScreen(tester);

      expect(find.text('Shadowed'), findsOneWidget);
      expect(find.text('Needs auth'), findsOneWidget);
      expect(find.text('Not approved'), findsOneWidget);
    });

    testWidgets('shows daemon warnings without hiding the server list', (
      tester,
    ) async {
      stubRpc(
        (_) => _snapshot(
          servers: [_stdioServer(name: 'search')],
          warnings: ['parse /home/dev/git/proj/.mcp.json: unexpected end'],
        ),
      );

      await _pumpScreen(tester);

      expect(find.textContaining('unexpected end'), findsOneWidget);
      expect(find.text('search'), findsOneWidget);
    });

    testWidgets('selecting a project re-reads with that projectDir', (
      tester,
    ) async {
      stubRpc(
        (_) => _snapshot(
          servers: [_stdioServer(name: 'search')],
          projects: ['/home/dev/git/proj'],
        ),
      );

      await _pumpScreen(tester);
      expect(calls.single.params.containsKey('projectDir'), isFalse);

      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('/home/dev/git/proj').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(calls.last.method, 'mcp-list');
      expect(calls.last.params['projectDir'], '/home/dev/git/proj');
    });
  });

  group('McpServer model', () {
    test('infers identity from scope, project, and name', () {
      const server = McpServer(
        name: 'search',
        scope: McpServerScope.local,
        transport: McpTransport.stdio,
        projectDir: '/home/dev/git/proj',
      );
      expect(server.identity, 'local:/home/dev/git/proj:search');
    });

    test('parses a stdio declaration off the wire', () {
      final server = McpServer.fromJson(
        _stdioServer(name: 'search', scope: 'userSettings'),
      );
      expect(server.scope, McpServerScope.userSettings);
      expect(server.transport, McpTransport.stdio);
      expect(server.target, 'search-mcp serve');
      expect(server.env['TOKEN'], mcpRedactedValue);
      expect(server.enabled, isTrue);
    });

    test('parses an http declaration and reports the url as its target', () {
      final server = McpServer.fromJson(<String, dynamic>{
        'name': 'remote',
        'scope': 'user',
        'transport': 'http',
        'url': 'https://mcp.example/v1',
        'headers': <String, String>{'Authorization': 'Bearer t'},
        'enabled': true,
      });
      expect(server.transport, McpTransport.http);
      expect(server.target, 'https://mcp.example/v1');
      expect(server.headers['Authorization'], mcpRedactedValue);
    });

    test('treats an unknown scope as user rather than dropping the row', () {
      final server = McpServer.fromJson(<String, dynamic>{
        'name': 'future',
        'scope': 'enterprise',
        'transport': 'stdio',
        'command': 'x',
      });
      expect(server.scope, McpServerScope.user);
    });

    test('awaitingApproval only for the approval-pending reason', () {
      final pending = McpServer.fromJson(
        _stdioServer(
          name: 'shared',
          scope: 'project',
          enabled: false,
          disabledReason: 'awaiting-approval',
        ),
      );
      final userDisabled = McpServer.fromJson(
        _stdioServer(
          name: 'shared',
          scope: 'project',
          enabled: false,
          disabled: true,
          disabledReason: 'user',
        ),
      );
      expect(pending.awaitingApproval, isTrue);
      expect(userDisabled.awaitingApproval, isFalse);
    });
  });

  group('McpConfigResponse', () {
    test('drops nameless server entries', () {
      final response = McpConfigResponse.fromJson(
        _snapshot(
          servers: [
            _stdioServer(name: 'search'),
            <String, dynamic>{'scope': 'user', 'transport': 'stdio'},
          ],
        ),
      );
      expect(response.servers.map((s) => s.name), ['search']);
    });

    test('reports failure payloads', () {
      final response = McpConfigResponse.fromJson(<String, dynamic>{
        'success': false,
        'error': 'unsupported scope "global"',
      });
      expect(response.success, isFalse);
      expect(response.error, 'unsupported scope "global"');
      expect(response.servers, isEmpty);
    });
  });
}
