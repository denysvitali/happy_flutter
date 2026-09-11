// Contract tests for the short-pane chat chrome.
//
// The reported defect: a session opened in Android split screen showed no
// conversation. The pane is roughly half a phone tall, and the app bar, the
// sub-agent banner, the task capsule, the activity bar and a two-row
// composer together stand taller than that — the transcript is what lost.
//
// Pinned invariants:
//   1. The density tier is a pure function of the pane height, with the
//      full-height layout for anything a normal portrait phone gives.
//   2. Dense banner chrome is measurably shorter and keeps every affordance
//      (title, progress copy, "View all", tap-to-expand).
//   3. A tight composer folds its selector row while idle and empty, and
//      restores it on focus or on the first character.
//   4. At a split-screen pane size the transcript keeps a real share of the
//      height rather than a sliver.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/models/todo.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/chat/chat_input.dart';
import 'package:happy_flutter/features/chat/chat_screen.dart';
import 'package:happy_flutter/features/chat/widgets/chat_chrome_density.dart';
import 'package:happy_flutter/features/chat/widgets/input_toolbar.dart';
import 'package:happy_flutter/features/chat/widgets/session_tasks_banner.dart';
import 'package:happy_flutter/features/chat/widgets/thinking_stop_bar.dart';
import 'package:mmkv_platform_interface/mmkv_platform_interface.dart';

import '../../helpers/fake_mmkv_platform.dart';

class _StorageFreeSettingsNotifier extends SettingsNotifier {
  _StorageFreeSettingsNotifier([this._initial]);

  final Settings? _initial;

  @override
  Settings build() => _initial ?? Settings();

  @override
  Future<void> updateSetting<T>(String key, T value) async {
    final json = state.toJson();
    json[key] = value;
    state = Settings.fromJson(json);
  }
}

Session _makeSession({bool thinking = false}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Session(
    id: 'session_1',
    seq: 1,
    createdAt: now - 10000,
    updatedAt: now - 5000,
    active: true,
    activeAt: now - 5000,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: 'online',
  );
}

TodoItem _todo(String id, TodoState status) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return TodoItem(
    id: id,
    content: 'item-$id',
    status: status,
    priority: 'medium',
    order: 0,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _scoped(Widget child, ChatChromeDensity density) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ChatChromeScope(
        density: density,
        child: Column(children: [child]),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MMKVPluginPlatform? originalMMKVPlatform;

  setUpAll(() {
    originalMMKVPlatform = MMKVPluginPlatform.instance;
    MMKVPluginPlatform.instance = FakeMmkvPlatform();
  });

  tearDownAll(() {
    MMKVPluginPlatform.instance = originalMMKVPlatform;
  });

  tearDown(() {
    sync.testClearSessionMessageState('session_1');
    sync.testSessions.remove('session_1');
  });

  group('ChatChromeDensity.fromPaneHeight', () {
    test('full-height panes keep the designed chrome', () {
      expect(ChatChromeDensity.fromPaneHeight(800), ChatChromeDensity.regular);
      expect(
        ChatChromeDensity.fromPaneHeight(ChatChromeDensity.compactMaxHeight),
        ChatChromeDensity.regular,
      );
    });

    test('split-screen panes flatten the banners', () {
      expect(
        ChatChromeDensity.fromPaneHeight(
          ChatChromeDensity.compactMaxHeight - 1,
        ),
        ChatChromeDensity.compact,
      );
      expect(
        ChatChromeDensity.fromPaneHeight(ChatChromeDensity.tightMaxHeight - 1),
        ChatChromeDensity.tight,
      );
    });

    test('unbounded panes never degrade', () {
      // The chat can be laid out inside an unbounded parent (a master-detail
      // column measuring its intrinsic height). That is not a short pane.
      expect(
        ChatChromeDensity.fromPaneHeight(double.infinity),
        ChatChromeDensity.regular,
      );
    });

    test('an unsized scope reads as regular', () {
      expect(ChatChromeDensity.regular.isDense, isFalse);
      expect(ChatChromeDensity.compact.isDense, isTrue);
      expect(ChatChromeDensity.tight.isTight, isTrue);
    });
  });

  group('SessionTasksBanner density', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      container
          .read(todoStateNotifierProvider.notifier)
          .setItemsForSession('session_1', [
            _todo('a', TodoState.completed),
            _todo('b', TodoState.inProgress),
            _todo('c', TodoState.pending),
          ]);
    });

    tearDown(() => container.dispose());

    Future<double> pumpBanner(
      WidgetTester tester,
      ChatChromeDensity density,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _scoped(
            const SessionTasksBanner(sessionId: 'session_1'),
            density,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getSize(find.byType(SessionTasksBanner)).height;
    }

    testWidgets('a full-height pane keeps the tile, labels and meter', (
      tester,
    ) async {
      await pumpBanner(tester, ChatChromeDensity.regular);

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('1 of 3 complete · 1 running'), findsOneWidget);
      expect(find.byKey(const ValueKey('session-tasks-progress')), findsOne);
      expect(find.byIcon(Icons.checklist_rounded), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);
    });

    testWidgets('a short pane drops the meter but keeps every affordance', (
      tester,
    ) async {
      final regular = await pumpBanner(tester, ChatChromeDensity.regular);
      final dense = await pumpBanner(tester, ChatChromeDensity.compact);

      expect(
        dense,
        lessThan(regular),
        reason: 'the dense header must actually buy transcript height',
      );
      // Same copy, same entry points — only the geometry changed.
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('1 of 3 complete · 1 running'), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Tasks, 1 of 3 complete · 1 running'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('session-tasks-progress')),
        findsNothing,
      );

      // Tap-to-expand still works on the dense row.
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.text('item-a'), findsOneWidget);
    });

    testWidgets('a tight pane never renders taller than a compact one', (
      tester,
    ) async {
      final compact = await pumpBanner(tester, ChatChromeDensity.compact);
      final tight = await pumpBanner(tester, ChatChromeDensity.tight);
      expect(tight, lessThanOrEqualTo(compact));
    });
  });

  group('ThinkingStopBar density', () {
    Future<double> pumpBar(
      WidgetTester tester,
      ChatChromeDensity density,
    ) async {
      await tester.pumpWidget(_scoped(ThinkingStopBar(onStop: () {}), density));
      // The breathing dot repeats forever — settle would time out.
      await tester.pump(const Duration(milliseconds: 50));
      return tester.getSize(find.byType(ThinkingStopBar)).height;
    }

    testWidgets('a short pane trims the bar without dropping Stop', (
      tester,
    ) async {
      final regular = await pumpBar(tester, ChatChromeDensity.regular);
      final dense = await pumpBar(tester, ChatChromeDensity.tight);

      expect(dense, lessThan(regular));
      // The Stop affordance and the single live-state label both survive.
      expect(find.text('Stop'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });
  });

  group('ChatInput density', () {
    Widget buildComposer(
      TextEditingController controller,
      ChatChromeDensity density,
    ) {
      return ProviderScope(
        child: _scoped(
          ChatInput(
            sessionId: 'session_1',
            controller: controller,
            onSend: () {},
          ),
          density,
        ),
      );
    }

    testWidgets('a full-height pane always shows the selector row', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildComposer(controller, ChatChromeDensity.regular),
      );
      await tester.pump();

      expect(find.byType(InputToolbar), findsOneWidget);
    });

    testWidgets('a tight pane folds the selector row while idle', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildComposer(controller, ChatChromeDensity.tight),
      );
      await tester.pump();

      final idle = tester.getSize(find.byType(ChatInput)).height;
      expect(find.byType(InputToolbar), findsNothing);

      // The first character brings the row back — the controls stay one
      // keystroke (or one tap, via focus) away.
      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pump();
      expect(find.byType(InputToolbar), findsOneWidget);

      final composing = tester.getSize(find.byType(ChatInput)).height;
      expect(
        composing,
        greaterThan(idle),
        reason: 'the folded row has to actually give the height back',
      );

      // Emptying the draft keeps the row — the field is still focused, and
      // the chips are what you reach for next. Blurring folds it again.
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.byType(InputToolbar), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(find.byType(InputToolbar), findsNothing);
    });

    testWidgets('focus alone reveals the selector row in a tight pane', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildComposer(controller, ChatChromeDensity.tight),
      );
      await tester.pump();
      expect(find.byType(InputToolbar), findsNothing);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(find.byType(InputToolbar), findsOneWidget);
    });
  });

  group('ChatScreen split screen', () {
    Future<void> pumpChat(WidgetTester tester, {required Size surface}) async {
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      sync.isInitialized = true;
      sync.testSetSessionMessages('session_1', const []);
      sync.testSessions['session_1'] = _makeSession(thinking: true);

      final container = ProviderContainer(
        overrides: [
          settingsNotifierProvider.overrideWith(
            () => _StorageFreeSettingsNotifier(),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(todoStateNotifierProvider.notifier)
          .setItemsForSession('session_1', [
            _todo('a', TodoState.completed),
            _todo('b', TodoState.inProgress),
            _todo('c', TodoState.pending),
          ]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ChatScreen(sessionId: 'session_1'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('a half-height pane still shows the conversation', (
      tester,
    ) async {
      const surface = Size(412, 420);
      await pumpChat(tester, surface: surface);

      expect(tester.takeException(), isNull);
      final transcript = tester.getSize(find.byType(Scrollable).first).height;
      expect(
        transcript,
        greaterThan(surface.height * 0.4),
        reason:
            'the transcript must keep a real share of a split-screen pane, '
            'not the sliver the fixed chrome used to leave',
      );
    });

    testWidgets('a full-height pane is unchanged by the dense tiers', (
      tester,
    ) async {
      await pumpChat(tester, surface: const Size(412, 800));

      // The task capsule still renders its full-height header.
      expect(find.byKey(const ValueKey('session-tasks-progress')), findsOne);
      expect(find.byType(InputToolbar), findsOneWidget);
    });
  });
}
