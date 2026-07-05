import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/provider_usage.dart';
import 'package:happy_flutter/features/providers/widgets/provider_payload_debug_sheet.dart';

Widget _pumpSheet(WidgetTester tester, ProviderUsage usage) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ProviderPayloadDebugSheet(usage: usage),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProviderPayloadDebugSheet', () {
    testWidgets('shows provider-specific title for each type', (tester) async {
      for (final type in ProviderUsageType.values) {
        await tester.pumpWidget(_pumpSheet(
          tester,
          ProviderUsage(
            accountId: 'a1',
            type: type,
            extra: const <String, dynamic>{
              'raw_payload': '{"ok": true}',
            },
          ),
        ));

        final expectedName = switch (type) {
          ProviderUsageType.kimi => 'Kimi',
          ProviderUsageType.minimax => 'MiniMax',
          ProviderUsageType.zai => 'Z.AI',
          ProviderUsageType.claudeCode => 'Claude Code',
          ProviderUsageType.codex => 'Codex',
        };
        expect(
          find.text('$expectedName raw response'),
          findsOneWidget,
          reason: 'wrong title for $type',
        );
      }
    });

    testWidgets('renders JSON payload with highlighting', (tester) async {
      await tester.pumpWidget(_pumpSheet(
        tester,
        ProviderUsage(
          accountId: 'a1',
          type: ProviderUsageType.kimi,
          extra: const <String, dynamic>{
            'raw_payload': '{\n  "limit": 100,\n  "used": 30\n}',
          },
        ),
      ));

      // The SyntaxHighlighter renders RichText spans rather than a single
      // SelectableText widget, so presence of RichText proves highlighting
      // is active.
      expect(find.byType(RichText), findsWidgets);
      expect(
        tester.widgetList<RichText>(find.byType(RichText)).any(
          (w) => w.text.toPlainText().contains('"limit"'),
        ),
        isTrue,
      );
      expect(
        find.text('No payload captured for this account yet.'),
        findsNothing,
      );
    });

    testWidgets('shows empty state when payload is missing', (tester) async {
      await tester.pumpWidget(_pumpSheet(
        tester,
        ProviderUsage(
          accountId: 'a1',
          type: ProviderUsageType.minimax,
        ),
      ));

      expect(
        find.text(
          'No payload captured for this account yet. '
          'Pull-to-refresh to retry.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('falls back to compact payload when pretty is missing', (
      tester,
    ) async {
      await tester.pumpWidget(_pumpSheet(
        tester,
        ProviderUsage(
          accountId: 'a1',
          type: ProviderUsageType.zai,
          extra: const <String, dynamic>{
            'raw_payload_compact': '{"ok":true}',
          },
        ),
      ));

      expect(find.byType(RichText), findsWidgets);
      expect(
        find.text('No payload captured for this account yet.'),
        findsNothing,
      );
    });
  });
}
