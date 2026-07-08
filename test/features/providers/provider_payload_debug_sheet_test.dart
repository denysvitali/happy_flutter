import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/provider_usage.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
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

    testWidgets('renders JSON payload as selectable text', (tester) async {
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

      expect(find.textContaining('"limit"'), findsOneWidget);
      expect(find.byType(SelectableText), findsWidgets);
      expect(
        find.text('No payload captured for this account yet.'),
        findsNothing,
      );
    });

    testWidgets(
      'preserves real line breaks in multi-line JSON',
      (tester) async {
        const payload = '{\n  "limit": 100,\n  "used": 30\n}';
        await tester.pumpWidget(_pumpSheet(
          tester,
          ProviderUsage(
            accountId: 'a1',
            type: ProviderUsageType.kimi,
            extra: const <String, dynamic>{
              'raw_payload': payload,
            },
          ),
        ));

        final selectable = tester.widgetList<SelectableText>(
          find.byType(SelectableText),
        );
        final rendered = selectable.map((w) => w.data ?? '').join();
        expect(rendered, contains('\n'));
        expect(rendered, isNot(contains(r'\n')));
      },
    );

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

      expect(find.byType(SelectableText), findsWidgets);
      expect(
        find.text('No payload captured for this account yet.'),
        findsNothing,
      );
    });

    testWidgets('uses a readable line height for the JSON payload', (
      tester,
    ) async {
      const payload = '{\n  "limit": 100,\n  "used": 30\n}';
      await tester.pumpWidget(_pumpSheet(
        tester,
        ProviderUsage(
          accountId: 'a1',
          type: ProviderUsageType.kimi,
          extra: const <String, dynamic>{
            'raw_payload': payload,
          },
        ),
      ));

      final selectable = tester.widget<SelectableText>(
        find.widgetWithText(SelectableText, '"limit"'),
      );
      expect(selectable.style, isNotNull);
      expect(selectable.style!.height, AppLineHeight.relaxed);
    });
  });
}
