import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/session_ui_state_notifier.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';
import 'package:happy_flutter/core/utils/utils.dart' show formatRelativeTime;
import 'package:happy_flutter/features/sessions/widgets/mission_control_action_tile.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_types.dart';

Session _session({
  String id = 'alpha-session',
  String? title,
  String host = 'devbox',
  bool thinking = false,
  int? timestamp,
  AgentState? agentState,
}) {
  final at =
      timestamp ??
      DateTime.now()
          .subtract(const Duration(minutes: 5))
          .millisecondsSinceEpoch;
  return Session(
    id: id,
    seq: 1,
    createdAt: at,
    updatedAt: at,
    active: true,
    activeAt: at,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: 'online',
    agentState: agentState,
    metadata: Metadata(
      host: host,
      path: '/home/dev/git/pmos-pixel7',
      summary: title == null ? null : Summary(text: title, updatedAt: at),
    ),
  );
}

Widget _app(Widget child, {bool dark = false, double scale = 1}) =>
    ProviderScope(
      child: MaterialApp(
        theme: dark
            ? ThemeHelper.buildDarkTheme()
            : ThemeHelper.buildLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      '320px row gives title and preview width at 2x text, dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _app(
            MissionActionRow(
              session: _session(title: 'Repair postmarketOS mobile networking'),
              entry: const SessionUiEntry(
                lastMessagePreview:
                    'Investigating the modem initialization failure',
                unreadCount: 23,
              ),
              lane: MissionLane.unread,
              animateActivity: false,
              onTap: () {},
              onLongPress: () {},
              onArchive: () {},
              onSelect: () {},
            ),
            dark: dark,
            scale: 2,
          ),
        );
        final title = find.text('Repair postmarketOS mobile networking');
        final preview = find.text(
          'Investigating the modem initialization failure',
        );
        final titleRect = tester.getRect(title);
        final previewRect = tester.getRect(preview);
        expect(titleRect.width, greaterThan(240));
        expect(previewRect.width, titleRect.width);
        expect(tester.widget<Text>(title).maxLines, 1);
        expect(
          tester.getTopLeft(find.text('23 new')).dy,
          greaterThan(previewRect.top),
        );
        expect(find.byTooltip('Session actions'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'duplicate generic names keep actual titles and distinct identity',
    (tester) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              for (final id in ['same-prefix-aaaa1111', 'same-prefix-bbbb2222'])
                MissionActionRow(
                  session: _session(id: id),
                  entry: SessionUiEntry.empty,
                  lane: MissionLane.quiet,
                  animateActivity: false,
                  onTap: () {},
                  onLongPress: () {},
                ),
            ],
          ),
        ),
      );
      expect(find.text('pmos-pixel7'), findsNWidgets(2));
      expect(find.text('devbox'), findsNWidgets(2));
      expect(find.text('#aaaa1111'), findsOneWidget);
      expect(find.text('#bbbb2222'), findsOneWidget);
      expect(find.textContaining('git/pmos-pixel7'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('host display omits pod noise and retains full identity', (
    tester,
  ) async {
    const host = 'devbox-runner-12345678';
    await tester.pumpWidget(
      _app(
        MissionActionRow(
          session: _session(host: host),
          entry: SessionUiEntry.empty,
          lane: MissionLane.quiet,
          animateActivity: false,
          onTap: () {},
          onLongPress: () {},
        ),
      ),
    );
    expect(find.text('devbox-runner'), findsOneWidget);
    expect(find.text(host), findsNothing);
    expect(find.byTooltip(host), findsOneWidget);
  });

  testWidgets('silent live status shows activity age once', (tester) async {
    final at = DateTime.now()
        .subtract(const Duration(days: 40))
        .millisecondsSinceEpoch;
    await tester.pumpWidget(
      _app(
        MissionActionRow(
          session: _session(timestamp: at, thinking: true),
          entry: SessionUiEntry.empty,
          lane: MissionLane.live,
          animateActivity: false,
          onTap: () {},
          onLongPress: () {},
        ),
      ),
    );
    expect(find.textContaining('silent'), findsOneWidget);
    expect(find.text('40d'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old activity remains compact and relative on every lane', (
    tester,
  ) async {
    final at = DateTime.now()
        .subtract(const Duration(days: 40))
        .millisecondsSinceEpoch;
    for (final lane in MissionLane.values) {
      await tester.pumpWidget(
        _app(
          MissionActionRow(
            session: _session(timestamp: at),
            entry: SessionUiEntry.empty,
            lane: lane,
            animateActivity: false,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      );
      expect(find.text('40d'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('future activity retains shared clock-skew handling', (
    tester,
  ) async {
    final future = DateTime.now().add(const Duration(days: 2));
    await tester.pumpWidget(
      _app(
        MissionActionRow(
          session: _session(timestamp: future.millisecondsSinceEpoch),
          entry: SessionUiEntry.empty,
          lane: MissionLane.quiet,
          animateActivity: false,
          onTap: () {},
          onLongPress: () {},
        ),
      ),
    );
    expect(
      find.text(formatRelativeTime(future, compact: true)),
      findsOneWidget,
    );
    expect(find.text('Just now'), findsNothing);
  });

  testWidgets('board menu exposes preview, select and archive independently', (
    tester,
  ) async {
    var opened = 0;
    var selected = 0;
    var archived = 0;
    var previewed = 0;
    await tester.pumpWidget(
      _app(
        MissionActionRow(
          session: _session(),
          entry: const SessionUiEntry(unreadCount: 3),
          lane: MissionLane.unread,
          animateActivity: false,
          showTriageMenu: false,
          onTap: () => opened++,
          onLongPress: () {},
          onSelect: () => selected++,
          onArchive: () => archived++,
          onPeek: () => previewed++,
          onTogglePin: () {},
          onToggleSnooze: (_) {},
        ),
      ),
    );
    for (final value in ['select', 'peek', 'archive']) {
      await tester.tap(find.byTooltip('Session actions'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<PopupMenuItem<String>>(
              find.byType(PopupMenuItem<String>),
            )
            .map((item) => item.value),
        unorderedEquals(['select', 'archive', 'peek']),
      );
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is PopupMenuItem<String> && widget.value == value,
        ),
      );
      await tester.pumpAndSettle();
      if (value == 'select') {
        expect(selected, 1);
        expect(archived, 0);
        expect(previewed, 0);
        expect(opened, 0);
      }
    }
    expect([selected, archived, previewed, opened], [1, 1, 1, 0]);
  });

  testWidgets('selection hides session actions and cannot mark read', (
    tester,
  ) async {
    var opened = 0;
    var acted = 0;
    await tester.pumpWidget(
      _app(
        MissionActionRow(
          session: _session(),
          entry: const SessionUiEntry(unreadCount: 3),
          lane: MissionLane.unread,
          selected: true,
          animateActivity: false,
          onTap: () => opened++,
          onLongPress: () {},
          onMarkRead: () => acted++,
          onArchive: () => acted++,
          onTogglePin: () => acted++,
        ),
      ),
    );
    expect(find.byTooltip('Session actions'), findsNothing);
    await tester.tap(find.text('pmos-pixel7'));
    expect(opened, 1);
    expect(acted, 0);
  });

  testWidgets('triage callbacks remain separate from opening a session', (
    tester,
  ) async {
    final actions = <String>[];
    await tester.pumpWidget(
      _app(
        MissionActionRow(
          session: _session(),
          entry: const SessionUiEntry(unreadCount: 3),
          lane: MissionLane.unread,
          animateActivity: false,
          isSnoozed: true,
          onTap: () => actions.add('open'),
          onLongPress: () {},
          onMarkRead: () => actions.add('read'),
          onPeek: () => actions.add('peek'),
          onTogglePin: () => actions.add('pin'),
          onToggleSnooze: (value) => actions.add('snooze:$value'),
        ),
      ),
    );
    for (final value in ['read', 'peek', 'pin', 'unsnooze']) {
      await tester.tap(find.byTooltip('Session actions'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is PopupMenuItem<String> && widget.value == value,
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(actions, ['read', 'peek', 'pin', 'snooze:false']);
  });

  testWidgets('semantic row tap opens only the session', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var opened = 0;
      var archived = 0;
      var selected = 0;
      await tester.pumpWidget(
        _app(
          MissionActionRow(
            session: _session(title: 'Semantic session'),
            entry: SessionUiEntry.empty,
            lane: MissionLane.quiet,
            animateActivity: false,
            onTap: () => opened++,
            onLongPress: () {},
            onArchive: () => archived++,
            onSelect: () => selected++,
          ),
        ),
      );
      final row = tester.getSemantics(find.byType(MissionActionRow));
      expect(row, containsSemantics(isButton: true, hasTapAction: true));
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        row.id,
        SemanticsAction.tap,
      );
      await tester.pump();
      expect(opened, 1);
      expect(archived, 0);
      expect(selected, 0);
      expect(
        tester.getSemantics(find.byTooltip('Session actions')),
        containsSemantics(isButton: true, hasTapAction: true),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('screen readers retain triage menu and inline approvals', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final approvals in [false, true]) {
        await tester.pumpWidget(
          _app(
            MissionActionRow(
              session: _session(
                agentState: AgentState(
                  requests: {
                    'request': const RequestInfo(tool: 'Bash', createdAt: 1),
                  },
                ),
              ),
              entry: SessionUiEntry.empty,
              lane: MissionLane.blocked,
              showInlineApproval: approvals,
              animateActivity: false,
              onTap: () {},
              onLongPress: () {},
              onPeek: () {},
            ),
            scale: 2,
          ),
        );
        expect(
          tester.getSemantics(find.byTooltip('Session actions')),
          containsSemantics(
            isButton: true,
            tooltip: 'Session actions',
            hasTapAction: true,
          ),
        );
        if (approvals) {
          expect(find.bySemanticsLabel('Allow'), findsOneWidget);
          expect(find.bySemanticsLabel('Deny'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    } finally {
      semantics.dispose();
    }
  });
}
