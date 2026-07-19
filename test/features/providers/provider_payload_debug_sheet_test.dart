import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/provider_usage.dart';
import 'package:happy_flutter/core/theme/app_scroll_behavior.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/features/providers/widgets/provider_payload_debug_sheet.dart';

Widget _pumpSheet(WidgetTester tester, ProviderUsage usage) => MaterialApp(
      // Install the app's real scroll behavior. The payload scroll bug only
      // reproduces under AppScrollBehavior (Bouncing + AlwaysScrollable): that
      // is what lets SelectableText's zero-extent inner Scrollable steal the
      // vertical drag and spring back to the top. The default test behavior is
      // clamping, which masks the bug — so a regression test that omits this
      // would pass on CI while still broken on a device.
      scrollBehavior: const AppScrollBehavior(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ProviderPayloadDebugSheet(usage: usage),
      ),
    );

/// The payload's scroll view. `SelectableText` (and the
/// `DraggableScrollableSheet`) also install zero-extent scrollables, so filter
/// for the one that actually has content to scroll.
ScrollableState _payloadScrollable(WidgetTester tester) {
  final states = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .where(
        (state) =>
            state.position.axis == Axis.vertical &&
            state.position.maxScrollExtent > 0,
      )
      .toList(growable: false);
  expect(states, isNotEmpty);
  return states.first;
}

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
          ProviderUsageType.grok => 'Grok',
          ProviderUsageType.qwen => 'Qwen',
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

      final selectable = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .firstWhere((w) => (w.data ?? '').contains('"limit"'));
      expect(selectable.style, isNotNull);
      expect(selectable.style!.height, AppLineHeight.relaxed);
    });

    testWidgets(
      'payload scrolls on a vertical drag over the text (device '
      'scroll behavior)',
      (tester) async {
        final payload = List<String>.generate(
          200,
          (i) => 'raw payload line $i with enough text to wrap',
        ).join('\n');
        await tester.pumpWidget(_pumpSheet(
          tester,
          ProviderUsage(
            accountId: 'a1',
            type: ProviderUsageType.qwen,
            extra: <String, dynamic>{'raw_payload': payload},
          ),
        ));
        await tester.pumpAndSettle();

        final sheetRect = tester.getRect(find.byType(DraggableScrollableSheet));
        final pane = _payloadScrollable(tester);
        final before = pane.position.pixels;

        // Drag inside the payload box (lower part of the sheet), on the
        // selectable text rather than the metadata rows above it.
        final gesture = await tester.startGesture(
          Offset(sheetRect.center.dx, sheetRect.top + sheetRect.height * 0.6),
        );
        for (var i = 0; i < 6; i++) {
          await gesture.moveBy(const Offset(0, -32));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(
          pane.position.pixels,
          greaterThan(before),
          reason: 'A drag on the payload text must scroll the pane, not be '
              "stolen by SelectableText's zero-extent inner scrollable.",
        );
      },
    );

    testWidgets(
      'shows Problem + Content-Type rows for a non-json body',
      (tester) async {
        const problem = 'Endpoint returned HTML instead of JSON.';
        await tester.pumpWidget(_pumpSheet(
          tester,
          ProviderUsage(
            accountId: 'q1',
            type: ProviderUsageType.qwen,
            extra: const <String, dynamic>{
              'status': 200,
              'content_type': 'text/html',
              'parse_error': problem,
              'raw_payload': '<!doctype html><html></html>',
            },
          ),
        ));

        // Labels are plain Text widgets; values are SelectableText, so match
        // them with textContaining (the payload also contains "html", but not
        // "text/html", so the content-type value stays unambiguous).
        expect(find.text('Problem'), findsOneWidget);
        expect(find.textContaining(problem), findsOneWidget);
        expect(find.text('Content-Type'), findsOneWidget);
        expect(find.textContaining('text/html'), findsOneWidget);
      },
    );
  });
}
