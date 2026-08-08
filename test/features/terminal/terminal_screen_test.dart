import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';

/// Widget tests for [TerminalScreen].
///
/// The real TerminalScreen depends on GoRouterState.extra for
/// machineId/cwd and on sync.machineBash for command execution.
/// We reproduce the build method as an inline widget to test the
/// terminal UI rendering and interaction logic without those
/// dependencies.

// ── Inline terminal screen ────────────────────────────────────

/// Reproduces the TerminalScreen UI for testing.
///
/// Instead of calling sync.machineBash, this accepts an
/// [onExecuteCommand] callback so tests can control the output.
class _TestTerminalScreen extends ConsumerStatefulWidget {
  const _TestTerminalScreen({
    this.machineId = 'test-machine',
    this.cwd = '/',
    this.onExecuteCommand,
    super.key,
  });

  final String? machineId;
  final String cwd;
  final Future<String> Function(String command)? onExecuteCommand;

  @override
  ConsumerState<_TestTerminalScreen> createState() =>
      _TestTerminalScreenState();
}

class _TestTerminalScreenState extends ConsumerState<_TestTerminalScreen> {
  final List<String> _lines = ['Terminal connected.'];
  final _commandController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  // Cached l10n values — lazily read once the context is available.
  late final String _disconnectLabel;
  late final String _disconnectConfirmLabel;
  late final String _cancelLabel;
  late final String _enterCommandHint;
  bool _l10nReady = false;

  static const _terminalTextStyle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    color: Color(0xFFD4D4D4),
    height: 1.5,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_l10nReady) {
      final l10n = AppLocalizations.of(context);
      _disconnectLabel = l10n.terminalDisconnect;
      _disconnectConfirmLabel = l10n.terminalDisconnectConfirm;
      _cancelLabel = l10n.commonCancel;
      _enterCommandHint = l10n.terminalEnterCommand;
      _l10nReady = true;
    }
  }

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitCommand(String command) async {
    final trimmed = command.trim();
    if (trimmed.isEmpty || _isSending) return;

    setState(() {
      _lines.add('> $trimmed');
      _isSending = true;
    });
    _commandController.clear();

    final machineId = widget.machineId;
    if (machineId == null || machineId.isEmpty) {
      setState(() {
        _lines.add('[No machine connected]');
        _isSending = false;
      });
      return;
    }

    try {
      final handler = widget.onExecuteCommand;
      if (handler != null) {
        final output = await handler(trimmed);
        setState(() {
          if (output.isNotEmpty) {
            _lines.addAll(output.split('\n'));
          } else {
            _lines.add('');
          }
        });
      }
    } catch (e) {
      setState(() => _lines.add('[Error: $e]'));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _confirmDisconnect() {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_disconnectLabel),
        content: Text(_disconnectConfirmLabel),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(_disconnectLabel),
          ),
        ],
      ),
    ).then((confirmed) {
      if ((confirmed ?? false) && mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        foregroundColor: const Color(0xFFD4D4D4),
        title: const Row(
          children: [
            Icon(Icons.terminal, size: 18),
            SizedBox(width: 8),
            Text('Terminal'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new),
            tooltip: _l10nReady ? _disconnectLabel : 'Disconnect',
            onPressed: _confirmDisconnect,
          ),
        ],
      ),
      body: Column(
        children: [
          // Terminal output area.
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: _lines.length,
              itemBuilder: (context, index) {
                final line = _lines[index];
                final isCommand = line.startsWith('> ');
                return Padding(
                  key: ValueKey(index),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    line,
                    style: isCommand
                        ? _terminalTextStyle.copyWith(
                            color: const Color(0xFF569CD6),
                          )
                        : _terminalTextStyle,
                  ),
                );
              },
            ),
          ),

          // Command input bar.
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              border: Border(
                top: BorderSide(color: Color(0xFF3C3C3C), width: 0.5),
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Text(
                  r'$ ',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: Color(0xFF4EC94E),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    style: _terminalTextStyle,
                    enabled: !_isSending,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: _l10nReady
                          ? _enterCommandHint
                          : 'Enter command...',
                    ),
                    textInputAction: TextInputAction.send,
                    autocorrect: false,
                    onSubmitted: _isSending ? null : _submitCommand,
                  ),
                ),
                if (_isSending)
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4EC94E),
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Color(0xFF4EC94E),
                      size: 20,
                    ),
                    onPressed: () => _submitCommand(_commandController.text),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────

Widget _buildApp({required Widget child}) {
  return ProviderScope(
    child: MaterialApp(
      home: child,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

// ── Tests ──────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalScreen', () {
    testWidgets('renders dark background', (tester) async {
      await tester.pumpWidget(_buildApp(child: const _TestTerminalScreen()));
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF1E1E1E));
    });

    testWidgets('renders app bar with terminal title', (tester) async {
      await tester.pumpWidget(_buildApp(child: const _TestTerminalScreen()));
      await tester.pump();

      expect(find.text('Terminal'), findsOneWidget);
      expect(find.byIcon(Icons.terminal), findsOneWidget);
    });

    testWidgets('renders disconnect button in app bar', (tester) async {
      await tester.pumpWidget(_buildApp(child: const _TestTerminalScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.power_settings_new), findsOneWidget);
    });

    testWidgets('shows initial connected message', (tester) async {
      await tester.pumpWidget(_buildApp(child: const _TestTerminalScreen()));
      await tester.pump();

      expect(find.text('Terminal connected.'), findsOneWidget);
    });

    testWidgets('renders command input field', (tester) async {
      await tester.pumpWidget(_buildApp(child: const _TestTerminalScreen()));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('renders dollar sign prompt', (tester) async {
      await tester.pumpWidget(_buildApp(child: const _TestTerminalScreen()));
      await tester.pump();

      expect(find.text(r'$ '), findsOneWidget);
    });

    testWidgets('renders send button', (tester) async {
      await tester.pumpWidget(_buildApp(child: const _TestTerminalScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('typing command and pressing send adds output', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: _TestTerminalScreen(
            onExecuteCommand: (cmd) async => 'output for $cmd',
          ),
        ),
      );
      await tester.pump();

      // Type a command.
      await tester.enterText(find.byType(TextField), 'ls -la');
      await tester.pump();

      // Press send button.
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pumpAndSettle();

      // Command echo should appear.
      expect(find.text('> ls -la'), findsOneWidget);
      // Output should appear.
      expect(find.text('output for ls -la'), findsOneWidget);
    });

    testWidgets('submitting command clears input field', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: _TestTerminalScreen(onExecuteCommand: (_) async => 'done'),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'echo hello');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pumpAndSettle();

      // Text field should be empty.
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text ?? '', isEmpty);
    });

    testWidgets('empty command is not submitted', (tester) async {
      var executed = false;
      await tester.pumpWidget(
        _buildApp(
          child: _TestTerminalScreen(
            onExecuteCommand: (_) async {
              executed = true;
              return 'output';
            },
          ),
        ),
      );
      await tester.pump();

      // Press send with empty input.
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(executed, isFalse);
    });

    testWidgets('shows no machine message when machineId is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(child: const _TestTerminalScreen(machineId: null)),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('[No machine connected]'), findsOneWidget);
    });

    testWidgets('shows no machine message when machineId empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(child: const _TestTerminalScreen(machineId: '')),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('[No machine connected]'), findsOneWidget);
    });

    testWidgets('error during command shows error line', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: _TestTerminalScreen(
            onExecuteCommand: (_) async {
              throw Exception('connection refused');
            },
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'bad-cmd');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('[Error:'), findsOneWidget);
    });

    testWidgets('shows loading spinner while command executes', (tester) async {
      final completer = Completer<String>();

      await tester.pumpWidget(
        _buildApp(
          child: _TestTerminalScreen(onExecuteCommand: (_) => completer.future),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'sleep-cmd');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // Spinner should be visible during execution.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Send button should be hidden.
      expect(find.byIcon(Icons.send), findsNothing);

      // Resolve the command.
      completer.complete('output');
      await tester.pumpAndSettle();

      // Spinner gone, send button back.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('input disabled while command is sending', (tester) async {
      final completer = Completer<String>();

      await tester.pumpWidget(
        _buildApp(
          child: _TestTerminalScreen(onExecuteCommand: (_) => completer.future),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'long-cmd');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // TextField should be disabled.
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);

      completer.complete('done');
      await tester.pumpAndSettle();
    });

    testWidgets('tapping disconnect shows confirmation dialog', (tester) async {
      await tester.pumpWidget(_buildApp(child: const _TestTerminalScreen()));
      await tester.pump();

      // Tap disconnect button.
      await tester.tap(find.byIcon(Icons.power_settings_new));
      await tester.pumpAndSettle();

      // Dialog should appear.
      expect(find.text('Close'), findsWidgets);
      expect(find.text('Close the command runner?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('cancel dismisses disconnect dialog', (tester) async {
      await tester.pumpWidget(_buildApp(child: const _TestTerminalScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.power_settings_new));
      await tester.pumpAndSettle();

      // Tap cancel.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be gone.
      expect(find.text('Close the command runner?'), findsNothing);
    });

    testWidgets('multiline output renders all lines', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: _TestTerminalScreen(
            onExecuteCommand: (_) async => 'line1\nline2\nline3',
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'multi');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('line1'), findsOneWidget);
      expect(find.text('line2'), findsOneWidget);
      expect(find.text('line3'), findsOneWidget);
    });

    testWidgets('command lines are styled differently', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: _TestTerminalScreen(onExecuteCommand: (_) async => 'result'),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'whoami');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pumpAndSettle();

      // Find the command line text widget.
      final commandText = tester.widget<Text>(find.text('> whoami'));
      // Command lines use blue color (0xFF569CD6).
      expect(commandText.style?.color, const Color(0xFF569CD6));

      // Output uses the default terminal color.
      final outputText = tester.widget<Text>(find.text('result'));
      expect(outputText.style?.color, const Color(0xFFD4D4D4));
    });

    testWidgets('command output appears in terminal output list', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          child: _TestTerminalScreen(
            onExecuteCommand: (cmd) async => 'output of $cmd',
          ),
        ),
      );
      await tester.pump();

      // Initial connected message.
      expect(find.text('Terminal connected.'), findsOneWidget);

      // Send first command.
      await tester.enterText(find.byType(TextField), 'pwd');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pumpAndSettle();

      // Send second command.
      await tester.enterText(find.byType(TextField), 'whoami');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pumpAndSettle();

      // Both commands and outputs should be visible.
      expect(find.text('> pwd'), findsOneWidget);
      expect(find.text('output of pwd'), findsOneWidget);
      expect(find.text('> whoami'), findsOneWidget);
      expect(find.text('output of whoami'), findsOneWidget);
      // Initial message still present.
      expect(find.text('Terminal connected.'), findsOneWidget);
    });

    testWidgets('empty output adds blank line', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: _TestTerminalScreen(onExecuteCommand: (_) async => ''),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'clear');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pumpAndSettle();

      // Command should appear.
      expect(find.text('> clear'), findsOneWidget);
      // Should have 3 items: connected msg, command, blank.
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.semanticChildCount, 3);
    });
  });
}
