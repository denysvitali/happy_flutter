import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/known_tools.dart';
import 'package:happy_flutter/features/chat/tools/tool_view_registry.dart';
import 'package:happy_flutter/features/chat/tools/views/codex_mcp_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CodexMcpView', () {
    testWidgets('renders full prompt and session config chips', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CodexMcpView(
            tool: {
              'name': 'mcp__codex__codex',
              'state': 'completed',
              'input': {
                'approval-policy': 'never',
                'cwd': '/home/workspace/git/happy_flutter',
                'model': 'gpt-5.3-codex-spark',
                'sandbox': 'read-only',
                'prompt':
                    'Review the core-layer files.\n\n'
                    'Hunt for correctness bugs.\n\n'
                    'RETURN: numbered findings.',
              },
              'result': {
                'content': [
                  {'type': 'text', 'text': '1. foo.dart:10 — bug — fix it'},
                  {'type': 'text', 'text': 'Verdict: looks good.'},
                ],
              },
            },
          ),
        ),
      );

      // Config chips.
      expect(find.text('gpt-5.3-codex-spark'), findsOneWidget);
      expect(find.text('read-only'), findsOneWidget);
      expect(find.text('never'), findsOneWidget);
      expect(find.text('model'), findsOneWidget);
      expect(find.text('sandbox'), findsOneWidget);
      expect(find.text('approval'), findsOneWidget);

      // Working directory row.
      expect(
        find.text('/home/workspace/git/happy_flutter'),
        findsOneWidget,
      );

      // Full prompt — head and tail both visible, not truncated.
      expect(find.text('PROMPT'), findsOneWidget);
      expect(find.textContaining('Review the core-layer files.'), findsOne);
      expect(find.textContaining('RETURN: numbered findings.'), findsOne);

      // Response text blocks are joined and rendered.
      expect(find.text('RESPONSE'), findsOneWidget);
      expect(find.textContaining('foo.dart:10'), findsOneWidget);
      expect(find.textContaining('Verdict: looks good.'), findsOneWidget);
    });

    testWidgets('codex-reply shape renders prompt without chips', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CodexMcpView(
            tool: {
              'name': 'mcp__codex__codex-reply',
              'state': 'completed',
              'input': {
                'threadId': 'thread-123',
                'prompt': 'Now also check the test file.',
              },
            },
          ),
        ),
      );

      expect(find.textContaining('Now also check the test file.'), findsOne);
      expect(find.text('model'), findsNothing);
      expect(find.text('sandbox'), findsNothing);
      expect(find.text('RESPONSE'), findsNothing);
    });

    testWidgets('running state shows working indicator, no response', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CodexMcpView(
            tool: {
              'name': 'mcp__codex__codex',
              'state': 'running',
              'input': {'prompt': 'Do the thing.'},
            },
          ),
        ),
      );

      expect(find.text('Codex is working…'), findsOneWidget);
      expect(find.textContaining('Do the thing.'), findsOneWidget);
      expect(find.text('RESPONSE'), findsNothing);
    });

    testWidgets('empty input renders without crashing', (tester) async {
      await tester.pumpWidget(
        _wrap(CodexMcpView(tool: {'state': 'completed'})),
      );

      expect(find.text('PROMPT'), findsNothing);
      expect(find.text('RESPONSE'), findsNothing);
      expect(find.text('model'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('non-text result blocks hide the response section', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CodexMcpView(
            tool: {
              'name': 'mcp__codex__codex',
              'state': 'completed',
              'input': {'prompt': 'Hi'},
              'result': {
                'content': [
                  {'type': 'image', 'data': 'aGVsbG8='},
                ],
              },
            },
          ),
        ),
      );

      expect(find.text('PROMPT'), findsOneWidget);
      expect(find.text('RESPONSE'), findsNothing);
    });
  });

  group('Codex MCP registration', () {
    test('KnownTools marks codex MCP tools non-minimal with subtitle', () {
      for (final name in ['mcp__codex__codex', 'mcp__codex__codex-reply']) {
        final definition = KnownTools.get(name);
        expect(definition, isNotNull, reason: name);
        expect(definition!.minimal, isFalse, reason: name);
      }

      final subtitle = KnownTools.get('mcp__codex__codex')!.extractSubtitle!(
        {
          'input': {'prompt': '\nFirst line of task.\nSecond line.'},
        },
        null,
      );
      expect(subtitle, 'First line of task.');
    });

    test('subtitle truncates long first lines', () {
      final longLine = 'x' * 120;
      final subtitle = KnownTools.get('mcp__codex__codex')!.extractSubtitle!(
        {
          'input': {'prompt': longLine},
        },
        null,
      );
      expect(subtitle, '${'x' * 80}…');
    });

    test('subtitle is null without a prompt', () {
      final subtitle = KnownTools.get('mcp__codex__codex')!.extractSubtitle!(
        {'input': {}},
        null,
      );
      expect(subtitle, isNull);
    });

    test('ToolViewRegistry resolves a builder for codex MCP tools', () {
      for (final name in ['mcp__codex__codex', 'mcp__codex__codex-reply']) {
        expect(ToolViewRegistry.has(name), isTrue, reason: name);
        expect(
          ToolViewRegistry.resolve(name, onNavigate: () {}),
          isNotNull,
          reason: name,
        );
      }
    });
  });
}
