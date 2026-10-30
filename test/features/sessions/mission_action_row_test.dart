import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/app_status_dot.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/session_ui_state_notifier.dart';
import 'package:happy_flutter/core/ui/agent_identity.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';
import 'package:happy_flutter/core/utils/utils.dart' show formatRelativeTime;
import 'package:happy_flutter/features/sessions/widgets/mission_control_action_tile.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_types.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_heartbeat.dart';

Session _session({
  String id = 'alpha-session',
  String? title,
  String? host = 'devbox',
  String? flavor,
  String path = '/home/dev/git/pmos-pixel7',
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
      host: host ?? '',
      flavor: flavor,
      path: path,
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
  testWidgets('inbox fallback identifies providers sharing a workspace', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            for (final flavor in ['codex', 'opencode'])
              MissionActionRow(
                inbox: true,
                session: _session(flavor: flavor),
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
    expect(find.text('Codex · devbox'), findsOneWidget);
    expect(find.text('OpenCode · devbox'), findsOneWidget);
    expect(find.textContaining('alpha-session'), findsNothing);
    expect(find.textContaining('git/pmos-pixel7'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inbox preserves workspace and keeps updates to one line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const longPreview =
        'The modem is connected and registration completed. '
        'Checking mobile data routing before restarting the networking '
        'service on the phone.';
    for (final preview in [longPreview, 'Mobile data is connected']) {
      await tester.pumpWidget(
        _app(
          MissionActionRow(
            inbox: true,
            session: _session(title: 'Repair networking'),
            entry: SessionUiEntry(lastMessagePreview: preview),
            lane: MissionLane.quiet,
            animateActivity: false,
            onTap: () {},
            onLongPress: () {},
            onArchive: () {},
          ),
        ),
      );
      final update = tester.getRect(find.text(preview));
      final workspace = tester.getRect(find.text('git/pmos-pixel7'));
      expect(update.top, greaterThan(workspace.bottom));
      expect(update.width, greaterThan(350));
      // Roster rows: one outcome line regardless of length, so long and
      // short updates give the same row height; the full text stays in the
      // tooltip.
      final height = tester.getSize(find.byType(MissionActionRow)).height;
      expect(tester.widget<Text>(find.text(preview)).maxLines, 1);
      expect(update.height, lessThan(25));
      expect(height, inInclusiveRange(64, 76));
      expect(find.byTooltip(preview), findsOneWidget);
      expect(find.text('devbox'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  for (final dark in [false, true]) {
    testWidgets('inbox protects preview width at 320px/2x, dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = 0;
      var read = 0;
      const preview = 'Investigating the modem initialization failure';
      await tester.pumpWidget(
        _app(
          MissionActionRow(
            inbox: true,
            session: _session(title: 'Repair mobile networking'),
            entry: const SessionUiEntry(
              lastMessagePreview: preview,
              unreadCount: 23,
            ),
            lane: MissionLane.unread,
            animateActivity: false,
            onTap: () => opened++,
            onLongPress: () {},
            onArchive: () {},
            onMarkRead: () => read++,
          ),
          dark: dark,
          scale: 2,
        ),
      );
      final update = tester.getRect(find.text(preview));
      final title = tester.getRect(find.text('Repair mobile networking'));
      expect(update.width, greaterThan(200));
      expect(update.width, closeTo(title.width, 1));
      // One line even at 2x text; the outcome pill stacks underneath.
      expect(tester.widget<Text>(find.text(preview)).maxLines, 1);
      expect(update.height, lessThan(50));
      expect(
        tester.getRect(find.text('23 new')).top,
        greaterThan(update.bottom),
      );
      expect(
        tester.getSize(find.byTooltip('Session actions')),
        const Size(44, 44),
      );
      await tester.tap(find.text('23 new'));
      expect([opened, read], [0, 1]);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'phone-width row keeps age off the title and one-line preview',
      (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _app(
            MissionActionRow(
              session: _session(title: 'Investigate and fix charging gaps'),
              entry: SessionUiEntry(
                lastMessagePreview:
                    'The battery logo was from the CPU I think, not the '
                    'charger, so the earlier fix did not apply here',
                lastMessageTimestamp: DateTime.now().millisecondsSinceEpoch,
                unreadCount: 2,
              ),
              lane: MissionLane.unread,
              animateActivity: false,
              onTap: () {},
              onLongPress: () {},
              onArchive: () {},
            ),
            dark: dark,
          ),
        );
        final title = tester.getRect(
          find.text('Investigate and fix charging gaps'),
        );
        final age = tester.getRect(find.text('Just now'));
        final preview = find.textContaining('battery logo');
        expect(age.left, greaterThan(title.right));
        expect(tester.widget<Text>(preview).maxLines, 1);
        expect(tester.getSize(preview).height, lessThan(25));
        expect(tester.takeException(), isNull);
      },
    );

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
        expect(titleRect.width, greaterThan(180));
        expect(previewRect.width, greaterThan(80));
        expect(previewRect.top, greaterThan(titleRect.top));
        expect(
          tester.getSize(find.byType(MissionActionRow)).height,
          lessThan(110),
        );
        expect(tester.widget<Text>(title).maxLines, 1);
        expect(
          tester.getCenter(find.text('23 new')).dy,
          closeTo(previewRect.center.dy, 1),
        );
        final menuRect = tester.getRect(find.byTooltip('Session actions'));
        expect(menuRect.size, const Size(44, 44));
        expect(menuRect.left, greaterThan(titleRect.right));
        expect(find.byTooltip('Session actions'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('duplicate generic names omit raw session identifiers', (
    tester,
  ) async {
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
    expect(find.textContaining('aaaa1111'), findsNothing);
    expect(find.textContaining('bbbb2222'), findsNothing);
    expect(find.byTooltip('same-prefix-aaaa1111'), findsNothing);
    expect(find.textContaining('git/pmos-pixel7'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ordinary two-line row has no footer or empty action space', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        MissionActionRow(
          session: _session(title: 'Fix mobile networking'),
          entry: const SessionUiEntry(lastMessagePreview: 'Modem is connected'),
          lane: MissionLane.quiet,
          animateActivity: false,
          onTap: () {},
          onLongPress: () {},
          onArchive: () {},
        ),
      ),
    );
    final row = tester.getRect(find.byType(MissionActionRow));
    final title = tester.getRect(find.text('Fix mobile networking'));
    final preview = tester.getRect(find.text('Modem is connected'));
    final menu = tester.getRect(find.byTooltip('Session actions'));
    expect(row.height, lessThanOrEqualTo(64));
    expect(preview.top - title.bottom, closeTo(2, 1));
    expect(menu.size, const Size(44, 44));
    expect(menu.center.dy, closeTo(row.center.dy, 1));
    expect(find.text('devbox'), findsNothing);
    expect(find.textContaining('alpha-session'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fallback omits placeholder hosts and repeated workspace', (
    tester,
  ) async {
    for (final host in [null, '', '(none)', 'null', 'dev@(none)']) {
      await tester.pumpWidget(
        _app(
          MissionActionRow(
            inbox: true,
            session: _session(host: host, flavor: 'opencode'),
            entry: SessionUiEntry.empty,
            lane: MissionLane.quiet,
            animateActivity: false,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      );
      expect(find.text('pmos-pixel7'), findsOneWidget);
      expect(find.text('OpenCode'), findsOneWidget);
      expect(find.textContaining('(none)'), findsNothing);
      expect(find.text('null'), findsNothing);
      expect(find.textContaining('git/pmos-pixel7'), findsNothing);
      expect(
        tester.getSize(find.byType(MissionActionRow)).height,
        lessThanOrEqualTo(64),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('workspace supplements a summary when there is no preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        MissionActionRow(
          inbox: true,
          session: _session(title: 'Repair networking', host: '(none)'),
          entry: SessionUiEntry.empty,
          lane: MissionLane.quiet,
          animateActivity: false,
          onTap: () {},
          onLongPress: () {},
        ),
      ),
    );
    expect(find.text('Repair networking'), findsOneWidget);
    expect(find.text('Claude · git/pmos-pixel7'), findsOneWidget);
    expect(find.textContaining('(none)'), findsNothing);
  });

  testWidgets('host display omits pod noise and retains full identity', (
    tester,
  ) async {
    const host = 'devbox-runner-12345678';
    await tester.pumpWidget(
      _app(
        MissionActionRow(
          inbox: true,
          session: _session(host: host),
          entry: SessionUiEntry.empty,
          lane: MissionLane.quiet,
          animateActivity: false,
          onTap: () {},
          onLongPress: () {},
        ),
      ),
    );
    expect(find.text('Claude · devbox-runner'), findsOneWidget);
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
    for (final lane in MissionLane.values) {
      final at = tester.binding.clock
          .now()
          .subtract(const Duration(days: 40))
          .millisecondsSinceEpoch;
      await tester.pumpWidget(
        _app(
          MissionClock(
            live: false,
            relativeTimestamps: [at],
            now: tester.binding.clock.now,
            child: MissionActionRow(
              session: _session(timestamp: at),
              entry: SessionUiEntry.empty,
              lane: lane,
              animateActivity: false,
              onTap: () {},
              onLongPress: () {},
            ),
          ),
        ),
      );
      expect(find.text('40d'), findsOneWidget);
      await tester.pump(const Duration(days: 1));
      expect(find.text('41d'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
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
          inbox: true,
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

  testWidgets('row tap and long press preserve their callbacks', (
    tester,
  ) async {
    final actions = <String>[];
    await tester.pumpWidget(
      _app(
        MissionActionRow(
          session: _session(title: 'Open this conversation'),
          entry: SessionUiEntry.empty,
          lane: MissionLane.quiet,
          animateActivity: false,
          onTap: () => actions.add('open'),
          onLongPress: () => actions.add('select'),
          onArchive: () => actions.add('archive'),
        ),
      ),
    );
    await tester.tap(find.text('Open this conversation'));
    await tester.longPress(find.text('Open this conversation'));
    expect(actions, ['open', 'select']);
  });

  testWidgets('selection hides session actions and cannot mark read', (
    tester,
  ) async {
    var opened = 0;
    var acted = 0;
    await tester.pumpWidget(
      _app(
        MissionActionRow(
          inbox: true,
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

  testWidgets('inline unread action marks read without opening the row', (
    tester,
  ) async {
    var opened = 0;
    var read = 0;
    await tester.pumpWidget(
      _app(
        MissionActionRow(
          session: _session(),
          entry: const SessionUiEntry(unreadCount: 3),
          lane: MissionLane.unread,
          animateActivity: false,
          onTap: () => opened++,
          onLongPress: () {},
          onMarkRead: () => read++,
        ),
      ),
    );
    await tester.tap(find.text('3 new'));
    expect(read, 1);
    expect(opened, 0);
  });

  testWidgets('pinned row retains unpin and snooze menu actions', (
    tester,
  ) async {
    final actions = <String>[];
    await tester.pumpWidget(
      _app(
        MissionActionRow(
          session: _session(),
          entry: SessionUiEntry.empty,
          lane: MissionLane.quiet,
          animateActivity: false,
          isPinned: true,
          onTap: () => actions.add('open'),
          onLongPress: () {},
          onTogglePin: () => actions.add('unpin'),
          onToggleSnooze: (value) => actions.add('snooze:$value'),
        ),
      ),
    );
    expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    for (final value in ['pin', 'snooze']) {
      await tester.tap(find.byTooltip('Session actions'));
      await tester.pumpAndSettle();
      expect(find.text('Unpin'), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is PopupMenuItem<String> && widget.value == value,
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(actions, ['unpin', 'snooze:true']);
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
            entry: const SessionUiEntry(lastMessagePreview: 'Ready for review'),
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
      final spokenPreview = find.bySemanticsLabel(RegExp('Ready for review'));
      expect(spokenPreview, findsOneWidget);
      expect(
        'Ready for review'.allMatches(
          tester.getSemantics(spokenPreview).getSemanticsData().label,
        ),
        hasLength(1),
      );
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
              inbox: true,
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
          // The request reads as a decision, not a bare tool label.
          expect(
            find.textContaining('Claude wants to use Bash', findRichText: true),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('pending command reads as a decision with the agent name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        MissionActionRow(
          session: _session(
            title: 'Roll out config',
            flavor: 'codex',
            agentState: AgentState(
              requests: {
                'a': const RequestInfo(
                  tool: 'Bash',
                  arguments: {
                    'command': 'kubectl rollout restart deploy/api\necho done',
                  },
                  createdAt: 1,
                ),
                'b': const RequestInfo(tool: 'Read', createdAt: 2),
              },
            ),
          ),
          entry: const SessionUiEntry(
            lastMessagePreview: 'Replicas are healthy on the old hash',
          ),
          lane: MissionLane.blocked,
          showInlineApproval: true,
          animateActivity: false,
          onTap: () {},
          onLongPress: () {},
        ),
      ),
    );
    final decision = find.textContaining(
      'Codex wants to run kubectl rollout restart deploy/api',
      findRichText: true,
    );
    expect(decision, findsOneWidget);
    // Only the first line of a multi-line command, plus the extra count.
    expect(find.textContaining('echo done', findRichText: true), findsNothing);
    expect(find.textContaining('+1 more', findRichText: true), findsOneWidget);
    // The agent's latest update moves beside the buttons as context, and
    // the old bare tool label is gone.
    expect(find.text('Replicas are healthy on the old hash'), findsOneWidget);
    expect(find.text('Bash'), findsNothing);
    expect(find.byIcon(Icons.shield_outlined), findsNothing);
    // Allow is a calm tonal button, not the solid warning fill.
    final allow = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Allow'),
        matching: find.byType(FilledButton),
      ),
    );
    final theme = Theme.of(tester.element(find.text('Allow')));
    final background = allow.style?.backgroundColor?.resolve({});
    expect(background, isNot(theme.colorScheme.error));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rows lead with the session identity avatar and state dot', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            MissionActionRow(
              session: _session(id: 'live-one', flavor: 'claude'),
              entry: SessionUiEntry.empty,
              lane: MissionLane.live,
              animateActivity: false,
              onTap: () {},
              onLongPress: () {},
            ),
            MissionActionRow(
              session: _session(id: 'quiet-one', flavor: 'codex'),
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
    final avatars = tester
        .widgetList<AgentAvatar>(find.byType(AgentAvatar))
        .toList();
    expect(avatars.map((a) => a.identity.seed), ['live-one', 'quiet-one']);
    expect(avatars.map((a) => a.identity.flavor), ['claude', 'codex']);
    // Working teammates carry a state dot; quiet ones do not.
    expect(
      find.descendant(
        of: find.byType(MissionActionRow).first,
        matching: find.byType(AppStatusDot),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(MissionActionRow).last,
        matching: find.byType(AppStatusDot),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
