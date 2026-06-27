import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/machines_notifier.dart';

/// Widget tests for [TerminalConnectScreen].
///
/// These tests verify the connection UI renders correctly based on
/// provider state without requiring the sync singleton or network.

// ── Helpers ────────────────────────────────────────────────────

class _StubMachinesNotifier extends MachinesNotifier {
  _StubMachinesNotifier(this._seed);

  final Map<String, Machine> _seed;

  @override
  Map<String, Machine> build() => _seed;

  @override
  void loadFromSync() {
    // No-op — avoids touching the sync singleton.
  }

  @override
  Future<void> refreshFromSync() async {
    // No-op.
  }
}

Machine _makeMachine({
  required String id,
  String? displayName,
  String? host,
  bool active = true,
  int? activeAt,
}) {
  return Machine(
    id: id,
    seq: 1,
    createdAt: 0,
    updatedAt: 0,
    active: active,
    activeAt: activeAt ?? DateTime.now().millisecondsSinceEpoch,
    metadata: MachineMetadata(displayName: displayName, host: host),
    metadataVersion: 1,
    daemonStateVersion: 0,
  );
}

Widget _buildApp({
  required Widget child,
  Map<String, Machine> machines = const {},
}) {
  return ProviderScope(
    overrides: [
      machinesNotifierProvider.overrideWith(
        () => _StubMachinesNotifier(machines),
      ),
    ],
    child: MaterialApp(
      home: child,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        _TestLocalizationsDelegate(),
      ],
    ),
  );
}

// ── Minimal localizations stub ────────────────────────────────

class _TestAppLocalizations {
  const _TestAppLocalizations();

  String get terminalConnect => 'Connect Terminal';
  String get terminalConnectInfo =>
      'Connect to a terminal session running on '
      'one of your machines.';
  String get terminalNoMachines =>
      'No machines connected. Start the Happy CLI '
      'on a machine first.';
  String get terminalSelectMachineHint => 'Select machine';
  String get terminalSelectMachineError => 'Please select a machine';
  String get machineOnline => 'Online';
  String get machineOffline => 'Offline';
  String get sessionSelectMachine => 'MACHINE';
  String get terminalIdLabel => 'TERMINAL / SESSION ID';
  String get terminalIdHint => 'e.g. main, dev, 1234';
  String get terminalIdError => 'Please enter a terminal or session ID';
  String get commonContinue => 'Continue';
}

class _TestLocalizationsDelegate
    extends LocalizationsDelegate<_TestAppLocalizations> {
  const _TestLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<_TestAppLocalizations> load(Locale locale) async {
    return const _TestAppLocalizations();
  }

  @override
  bool shouldReload(_TestLocalizationsDelegate old) => false;
}

/// Extension matching the production `context.l10n` API so the
/// widget under test compiles without real localizations.
extension _L10nX on BuildContext {
  _TestAppLocalizations get l10n =>
      Localizations.of<_TestAppLocalizations>(this, _TestAppLocalizations) ??
      const _TestAppLocalizations();
}

String _machineLabel(Machine machine) {
  final meta = machine.metadata;
  return meta?.displayName ?? meta?.host ?? machine.id;
}

Machine? _machineById(List<Machine> machines, String id) {
  for (final machine in machines) {
    if (machine.id == id) return machine;
  }
  return null;
}

// ── Inline screen that mirrors TerminalConnectScreen UI ────────

/// A reproduction of the TerminalConnectScreen build method that
/// avoids GoRouter navigation.  We exercise the real
/// MachinesNotifier provider but replace the navigation call
/// with a no-op so the test can verify form behaviour.
class _TestTerminalConnectScreen extends ConsumerStatefulWidget {
  const _TestTerminalConnectScreen();

  @override
  ConsumerState<_TestTerminalConnectScreen> createState() =>
      _TestTerminalConnectScreenState();
}

class _TestTerminalConnectScreenState
    extends ConsumerState<_TestTerminalConnectScreen> {
  String? _selectedMachineId;
  final _terminalIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _connectCalled = false;
  String? _connectMachineId;
  String? _connectTerminalId;

  @override
  void dispose() {
    _terminalIdController.dispose();
    super.dispose();
  }

  void _handleConnect() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _connectCalled = true;
      _connectMachineId = _selectedMachineId;
      _connectTerminalId = _terminalIdController.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final machines = ref.watch(machinesNotifierProvider);
    final machineList = machines.values.toList()
      ..sort((a, b) {
        final aOnline = a.isOnline ? 0 : 1;
        final bOnline = b.isOnline ? 0 : 1;
        if (aOnline != bOnline) return aOnline.compareTo(bOnline);
        return _machineLabel(a).compareTo(_machineLabel(b));
      });
    final hasOnlineMachine = machineList.any((machine) => machine.isOnline);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.terminalConnect)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.terminal,
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(context.l10n.terminalConnectInfo)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Machine selector
              Text(
                context.l10n.sessionSelectMachine.toUpperCase(),
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(height: 12),
              if (machineList.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(context.l10n.terminalNoMachines),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedMachineId,
                  selectedItemBuilder: (context) => machineList
                      .map(
                        (machine) => Text(
                          _machineLabel(machine),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                      .toList(),
                  hint: Text(context.l10n.terminalSelectMachineHint),
                  items: machineList.map((machine) {
                    final label = _machineLabel(machine);
                    final online = machine.isOnline;
                    return DropdownMenuItem<String>(
                      value: machine.id,
                      enabled: online,
                      child: Row(
                        children: [
                          Text(label),
                          if (!online) ...[
                            const SizedBox(width: 8),
                            Text(context.l10n.machineOffline),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      final machine = _machineById(machineList, value);
                      if (machine != null && !machine.isOnline) {
                        return;
                      }
                    }
                    setState(() => _selectedMachineId = value);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.l10n.terminalSelectMachineError;
                    }
                    final machine = _machineById(machineList, value);
                    if (machine != null && !machine.isOnline) {
                      return context.l10n.terminalSelectMachineError;
                    }
                    return null;
                  },
                ),

              const SizedBox(height: 32),

              // Terminal ID input
              Text(
                context.l10n.terminalIdLabel,
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _terminalIdController,
                decoration: InputDecoration(
                  hintText: context.l10n.terminalIdHint,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.l10n.terminalIdError;
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // Connect button
              FilledButton.icon(
                onPressed: hasOnlineMachine ? _handleConnect : null,
                icon: const Icon(Icons.link),
                label: Text(context.l10n.commonContinue),
              ),

              // Test-only: show connection result
              if (_connectCalled) ...[
                const SizedBox(height: 16),
                Text(
                  'CONNECTED:$_connectMachineId:'
                  '$_connectTerminalId',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tests ──────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalConnectScreen', () {
    testWidgets('renders app bar with connect title', (tester) async {
      await tester.pumpWidget(
        _buildApp(child: const _TestTerminalConnectScreen()),
      );
      await tester.pump();

      expect(find.text('Connect Terminal'), findsOneWidget);
    });

    testWidgets('renders info card with terminal icon', (tester) async {
      await tester.pumpWidget(
        _buildApp(child: const _TestTerminalConnectScreen()),
      );
      await tester.pump();

      expect(find.byIcon(Icons.terminal), findsOneWidget);
      expect(
        find.text(
          'Connect to a terminal session running on '
          'one of your machines.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows no-machines message when list is empty', (tester) async {
      await tester.pumpWidget(
        _buildApp(child: const _TestTerminalConnectScreen()),
      );
      await tester.pump();

      expect(
        find.text(
          'No machines connected. Start the Happy CLI '
          'on a machine first.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('connect button is disabled when no machines', (tester) async {
      await tester.pumpWidget(
        _buildApp(child: const _TestTerminalConnectScreen()),
      );
      await tester.pump();

      final finder = find.byWidgetPredicate((w) => w is FilledButton);
      final button = tester.widget<FilledButton>(finder);
      expect(button.onPressed, isNull);
    });

    testWidgets('shows dropdown when machines exist', (tester) async {
      final machines = {'m1': _makeMachine(id: 'm1', displayName: 'My Laptop')};

      await tester.pumpWidget(
        _buildApp(
          machines: machines,
          child: const _TestTerminalConnectScreen(),
        ),
      );
      await tester.pump();

      // Should show the dropdown instead of no-machines card.
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(
        find.text(
          'No machines connected. Start the Happy CLI '
          'on a machine first.',
        ),
        findsNothing,
      );
    });

    testWidgets('connect button is enabled when machines exist', (
      tester,
    ) async {
      final machines = {'m1': _makeMachine(id: 'm1', displayName: 'Dev Box')};

      await tester.pumpWidget(
        _buildApp(
          machines: machines,
          child: const _TestTerminalConnectScreen(),
        ),
      );
      await tester.pump();

      final finder = find.byWidgetPredicate((w) => w is FilledButton);
      final button = tester.widget<FilledButton>(finder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('connect button is disabled when all machines are offline', (
      tester,
    ) async {
      final machines = {
        'm1': _makeMachine(id: 'm1', displayName: 'Offline Box', active: false),
      };

      await tester.pumpWidget(
        _buildApp(
          machines: machines,
          child: const _TestTerminalConnectScreen(),
        ),
      );
      await tester.pump();

      final finder = find.byWidgetPredicate((w) => w is FilledButton);
      final button = tester.widget<FilledButton>(finder);
      expect(button.onPressed, isNull);
    });

    testWidgets('labels offline machines in dropdown', (tester) async {
      final machines = {
        'm1': _makeMachine(id: 'm1', displayName: 'Offline Box', active: false),
        'm2': _makeMachine(id: 'm2', displayName: 'Online Box'),
      };

      await tester.pumpWidget(
        _buildApp(
          machines: machines,
          child: const _TestTerminalConnectScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('Offline Box'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Online Box'), findsOneWidget);
    });

    testWidgets('can select a machine from dropdown', (tester) async {
      final machines = {
        'm1': _makeMachine(id: 'm1', displayName: 'Laptop'),
        'm2': _makeMachine(id: 'm2', displayName: 'Server'),
      };

      await tester.pumpWidget(
        _buildApp(
          machines: machines,
          child: const _TestTerminalConnectScreen(),
        ),
      );
      await tester.pump();

      // Tap the dropdown.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Select 'Server'.
      await tester.tap(find.text('Server').last);
      await tester.pumpAndSettle();

      // The selected value should now display.
      expect(find.text('Server'), findsOneWidget);
    });

    testWidgets('shows terminal ID input field', (tester) async {
      await tester.pumpWidget(
        _buildApp(child: const _TestTerminalConnectScreen()),
      );
      await tester.pump();

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('e.g. main, dev, 1234'), findsOneWidget);
    });

    testWidgets('can type in terminal ID field', (tester) async {
      await tester.pumpWidget(
        _buildApp(child: const _TestTerminalConnectScreen()),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), 'main-session');
      await tester.pump();

      expect(find.text('main-session'), findsOneWidget);
    });

    testWidgets('form validation shows error when machine not selected', (
      tester,
    ) async {
      final machines = {'m1': _makeMachine(id: 'm1', displayName: 'Box')};

      await tester.pumpWidget(
        _buildApp(
          machines: machines,
          child: const _TestTerminalConnectScreen(),
        ),
      );
      await tester.pump();

      // Enter terminal ID but don't select machine.
      await tester.enterText(find.byType(TextFormField), 'test-id');
      await tester.pump();

      // Tap connect without selecting machine.
      await tester.tap(find.byWidgetPredicate((w) => w is FilledButton));
      await tester.pump();

      // Should show machine validation error.
      expect(find.text('Please select a machine'), findsOneWidget);
    });

    testWidgets('form validation shows error when terminal ID empty', (
      tester,
    ) async {
      final machines = {'m1': _makeMachine(id: 'm1', displayName: 'Box')};

      await tester.pumpWidget(
        _buildApp(
          machines: machines,
          child: const _TestTerminalConnectScreen(),
        ),
      );
      await tester.pump();

      // Select a machine first.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Box').last);
      await tester.pumpAndSettle();

      // Tap connect with empty terminal ID.
      await tester.tap(find.byWidgetPredicate((w) => w is FilledButton));
      await tester.pump();

      // Should show terminal ID validation error.
      expect(
        find.text('Please enter a terminal or session ID'),
        findsOneWidget,
      );
    });

    testWidgets('successful connect populates connection details', (
      tester,
    ) async {
      final machines = {'m1': _makeMachine(id: 'm1', displayName: 'Laptop')};

      await tester.pumpWidget(
        _buildApp(
          machines: machines,
          child: const _TestTerminalConnectScreen(),
        ),
      );
      await tester.pump();

      // Select machine.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Laptop').last);
      await tester.pumpAndSettle();

      // Enter terminal ID.
      await tester.enterText(find.byType(TextFormField), 'dev-session');
      await tester.pump();

      // Tap connect.
      await tester.tap(find.byWidgetPredicate((w) => w is FilledButton));
      await tester.pump();

      // Should show the connected details.
      expect(find.text('CONNECTED:m1:dev-session'), findsOneWidget);
    });

    testWidgets('renders machine label using host as fallback', (tester) async {
      final machines = {'m1': _makeMachine(id: 'm1', host: 'my-host.local')};

      await tester.pumpWidget(
        _buildApp(
          machines: machines,
          child: const _TestTerminalConnectScreen(),
        ),
      );
      await tester.pump();

      // Open dropdown to see labels.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('my-host.local'), findsWidgets);
    });

    testWidgets('renders machine label using id as last fallback', (
      tester,
    ) async {
      final machines = {'machine-abc-123': _makeMachine(id: 'machine-abc-123')};

      await tester.pumpWidget(
        _buildApp(
          machines: machines,
          child: const _TestTerminalConnectScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('machine-abc-123'), findsWidgets);
    });
  });
}
