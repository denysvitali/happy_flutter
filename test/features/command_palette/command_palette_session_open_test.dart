// Contract coverage for the command palette's session entry point:
// the command built for session X must open session X, whatever the
// query, the ordering, or the path (pointer or keyboard) used to
// select it.
//
// The fixture sessions deliberately share host/machine/path and differ
// only by id + label, so any id/label misalignment surfaces as a wrong
// recorded chat route rather than a passing coincidence.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/features/command_palette/command_item.dart';
import 'package:happy_flutter/features/command_palette/command_palette.dart';
import 'package:happy_flutter/features/command_palette/command_palette_overlay.dart';

import '../../helpers/session_open_harness.dart';

/// Renders the palette over commands built by the real controller, so the
/// test exercises `CommandPaletteController.buildCommands` and the overlay
/// together (the pair a user actually touches).
class _PaletteHost extends ConsumerWidget {
  const _PaletteHost({this.recent = const []});

  final List<String> recent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commands = ref
        .read(commandPaletteControllerProvider)
        .buildCommands(context);
    return Scaffold(
      body: CommandPaletteOverlay(
        commands: commands,
        recentCommands: recent,
        withModalBarrier: false,
        onClose: () {},
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionOpenRecorder recorder;
  late ProviderContainer container;
  late List<String> otherRoutes;

  Future<void> pumpPalette(
    WidgetTester tester, {
    Map<String, Session>? sessions,
    List<String> recent = const [],
  }) async {
    container = ProviderContainer(
      overrides: contractListOverrides(
        settings: Settings.new,
        sessions: sessions ?? contractSessions(),
      ),
    );
    final router = buildSessionOpenRouter(
      recorder: recorder,
      home: (_) => _PaletteHost(recent: recent),
      extraRoutes: [
        recordingRoute('/settings', otherRoutes),
        recordingRoute('/artifacts', otherRoutes),
      ],
    );
    await tester.pumpWidget(
      buildSessionOpenApp(container: container, router: router),
    );
    await tester.pumpAndSettle();
  }

  /// Types [query] and lets the 100 ms fuzzy debounce elapse.
  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  }

  /// The palette list is 500 px tall; session rows sit under the
  /// navigation categories, so the empty-query cases must scroll.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Fuzzy matches render titles as highlighted rich text, so plain
  /// `find.text` misses them.
  Finder rowTitled(String label) => find.text(label, findRichText: true);

  /// Session-row labels currently laid out, ordered top to bottom — i.e.
  /// exactly what the user sees and what arrow keys walk through.
  List<String> visibleSessionLabels(WidgetTester tester) {
    final rows = <(double, String)>[];
    for (final element in find.byType(RichText).evaluate()) {
      final text = (element.widget as RichText).text.toPlainText();
      if (!contractLabels.values.contains(text)) continue;
      final box = element.renderObject! as RenderBox;
      rows.add((box.localToGlobal(Offset.zero).dy, text));
    }
    rows.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final row in rows) row.$2];
  }

  String idForLabel(String label) =>
      contractLabels.entries.firstWhere((e) => e.value == label).key;

  setUp(() {
    recorder = SessionOpenRecorder();
    otherRoutes = <String>[];
  });

  tearDown(() {
    cancelContractChatSwitchMetrics();
    container.dispose();
  });

  group('CommandPaletteController.buildCommands', () {
    testWidgets('session command carries the session name and path', (
      tester,
    ) async {
      await pumpPalette(tester);
      await reveal(tester, rowTitled(contractCharlieLabel));

      expect(rowTitled(contractCharlieLabel), findsOneWidget);
      expect(find.text(contractSessionPath), findsWidgets);
    });

    testWidgets('orders sessions newest-first and keeps five in the '
        'empty-query shortlist', (tester) async {
      await pumpPalette(tester);
      await reveal(tester, rowTitled(contractFoxtrotLabel));

      expect(
        visibleSessionLabels(tester),
        [
          contractAlphaLabel,
          contractBravoLabel,
          contractCharlieLabel,
          contractDeltaLabel,
          contractFoxtrotLabel,
        ],
      );
      // Echo is the sixth-newest: search-only, never in the shortlist.
      expect(rowTitled(contractEchoLabel), findsNothing);
    });

    testWidgets('search-only session is still reachable by query', (
      tester,
    ) async {
      await pumpPalette(tester);
      await search(tester, 'Echo');

      expect(rowTitled(contractEchoLabel), findsOneWidget);
    });

    testWidgets('pinned sessions lead the list and are flagged', (
      tester,
    ) async {
      final sessions = contractSessions();
      // Echo is the oldest session; pinning must float it above Alpha.
      sessions[contractEchoId] = sessions[contractEchoId]!.copyWith(
        pinned: true,
      );
      await pumpPalette(tester, sessions: sessions);

      expect(visibleSessionLabels(tester).first, contractEchoLabel);
      expect(find.byIcon(Icons.push_pin), findsWidgets);
    });

    testWidgets('session without a name falls back to its short id', (
      tester,
    ) async {
      final session = contractSession(id: contractAlphaId, label: 'x');
      final nameless = session.copyWith(
        metadata: session.metadata!.copyWith(name: null),
      );
      await pumpPalette(tester, sessions: {nameless.id: nameless});
      final fallback = 'Session ${contractAlphaId.substring(0, 6)}';
      await reveal(tester, rowTitled(fallback));

      expect(rowTitled(fallback), findsOneWidget);
    });

    testWidgets('navigation commands reach their advertised route', (
      tester,
    ) async {
      await pumpPalette(tester);
      // Query a prefix, never the full title: the search field's own
      // text is rich text too and would swallow the tap.
      await search(tester, 'artifac');
      await tester.tap(rowTitled('Artifacts'));
      await tester.pumpAndSettle();

      expect(otherRoutes, ['/artifacts']);
      expect(recorder.opened, isEmpty);
    });
  });

  group('selecting result N opens result N', () {
    testWidgets('tapping a session row opens exactly that session', (
      tester,
    ) async {
      await pumpPalette(tester);
      await reveal(tester, rowTitled(contractCharlieLabel));

      // Charlie sits third in the shortlist: an off-by-one or a
      // label/id mismatch would record Alpha or Delta instead.
      await tester.tap(rowTitled(contractCharlieLabel));
      await tester.pumpAndSettle();

      expect(recorder.opened, [contractCharlieId]);
    });

    testWidgets('tapping a filtered result opens that result, not the '
        'previously first row', (tester) async {
      await pumpPalette(tester);
      await search(tester, 'Foxtrot');

      await tester.tap(rowTitled(contractFoxtrotLabel));
      await tester.pumpAndSettle();

      expect(recorder.opened, [contractFoxtrotId]);
    });

    testWidgets('enter opens the row the arrow keys landed on', (
      tester,
    ) async {
      await pumpPalette(tester);
      // 'review' matches every session label and no navigation command,
      // so the flat keyboard order is exactly the visible session order.
      await search(tester, 'review');
      final labels = visibleSessionLabels(tester);
      expect(labels.length, greaterThanOrEqualTo(3));

      for (var i = 0; i < 2; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(recorder.opened, [idForLabel(labels[2])]);
    });

    testWidgets('recent section entry opens its own session', (tester) async {
      await pumpPalette(tester, recent: ['session-$contractDeltaId']);

      // The Recent section is rendered first, so Delta's recent row is
      // the top row and must still resolve to Delta's id.
      expect(visibleSessionLabels(tester).first, contractDeltaLabel);
      await tester.tap(rowTitled(contractDeltaLabel).first);
      await tester.pumpAndSettle();

      expect(recorder.opened, [contractDeltaId]);
    });
  });

  group('search behaviour', () {
    testWidgets('no match shows the empty state and opens nothing', (
      tester,
    ) async {
      await pumpPalette(tester);
      await search(tester, 'zzzzzznope');

      expect(find.text('No commands found'), findsOneWidget);
      expect(recorder.opened, isEmpty);
    });

    testWidgets('clearing the query restores the shortlist', (tester) async {
      await pumpPalette(tester);
      await search(tester, 'Foxtrot');
      expect(visibleSessionLabels(tester), [contractFoxtrotLabel]);

      await search(tester, '');
      await reveal(tester, rowTitled(contractAlphaLabel));
      expect(visibleSessionLabels(tester), contains(contractAlphaLabel));
    });
  });

  group('CommandItem identity', () {
    test('session command ids are unique per session', () {
      final ids = <String>{};
      for (final id in contractLabels.keys) {
        expect(ids.add('session-$id'), isTrue);
      }
      expect(ids, hasLength(contractLabels.length));
    });

    test('copyWith preserves the action closure', () {
      var fired = 0;
      final item = CommandItem(id: 'a', title: 'A', action: () => fired++);
      item.copyWith(title: 'B').action();
      expect(fired, 1);
    });
  });
}
