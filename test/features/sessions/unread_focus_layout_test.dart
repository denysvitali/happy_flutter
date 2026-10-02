import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/todo.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';
import 'package:happy_flutter/features/sessions/widgets/session_badges.dart';
import 'package:happy_flutter/features/sessions/widgets/unread_focus_cards.dart';

const _name = 'Firmware refactoring and OTA receive reliability';
const _preview = 'Checking the final task state and the remaining changes.';
const _requests = {
  'permission-1': RequestInfo(tool: 'Bash with a long tool name'),
};

Session _session() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Session(
    id: 'session-layout',
    seq: 1,
    createdAt: now,
    updatedAt: now,
    active: true,
    activeAt: now,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: 'online',
    pinned: true,
    metadata: Metadata(
      path: '/home/workspace/git/project',
      summary: Summary(text: _name, updatedAt: now),
      flavor: 'codex',
    ),
    todos: [
      for (var i = 0; i < 225; i++)
        TodoItem(
          id: '$i',
          content: 'Task $i',
          status: i < 223 ? TodoState.completed : TodoState.pending,
          priority: 'medium',
          order: i,
          createdAt: now,
          updatedAt: now,
        ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 320,
  double scale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: dark
            ? ThemeHelper.buildDarkTheme()
            : ThemeHelper.buildLightTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      for (final selection in [false, true]) {
        testWidgets('attention and list rows fit 320px: '
            'dark=$dark scale=$scale selection=$selection', (tester) async {
          final session = _session();
          await _pump(
            tester,
            Column(
              children: [
                NeedsAttentionCard(
                  session: session,
                  showFlavorIcon: true,
                  onTap: () {},
                  onLongPress: () {},
                  unreadCount: 120,
                  lastMessagePreview: _preview,
                  selectionMode: selection,
                  isSelected: selection,
                  permissionRequests: _requests,
                ),
                UnreadFocusListGroup(
                  children: [
                    UnreadFocusListRow(
                      session: session,
                      showFlavorIcon: true,
                      onTap: () {},
                      onLongPress: () {},
                      unreadCount: 120,
                      lastMessagePreview: _preview,
                      selectionMode: selection,
                      isSelected: selection,
                      archiveCountdownLabel: '2h',
                    ),
                  ],
                ),
              ],
            ),
            dark: dark,
            scale: scale,
          );

          expect(tester.takeException(), isNull);
          expect(find.text('99+'), findsNWidgets(2));
          expect(find.text('223/225'), findsNWidgets(2));
          expect(find.text(_preview), findsNWidgets(2));
          final name = tester.widget<Text>(find.text(_name).first);
          final cs = Theme.of(
            tester.element(find.text(_name).first),
          ).colorScheme;
          expect(name.style?.color, cs.onSurface);
          if (!selection) {
            expect(
              tester.getSize(find.text(_name).first).width,
              greaterThan(200),
            );
            expect(find.text('Allow'), findsOneWidget);
            expect(find.text('Deny'), findsOneWidget);
          } else {
            expect(find.text('Allow'), findsNothing);
            expect(find.byType(SelectionCheckbox), findsNWidgets(2));
          }
          for (var i = 0; i < 2; i++) {
            expect(
              tester.getTopLeft(find.byType(UnreadBadge).at(i)).dy,
              greaterThanOrEqualTo(
                tester.getBottomLeft(find.text(_preview).at(i)).dy,
              ),
            );
          }
        });
      }
    }
  }

  testWidgets('row tap and long press retain independent callbacks', (
    tester,
  ) async {
    var taps = 0;
    var longPresses = 0;
    await _pump(
      tester,
      UnreadFocusListGroup(
        children: [
          UnreadFocusListRow(
            session: _session(),
            showFlavorIcon: true,
            onTap: () => taps++,
            onLongPress: () => longPresses++,
          ),
        ],
      ),
    );
    await tester.tap(find.text(_name));
    await tester.longPress(find.text(_name));
    expect(taps, 1);
    expect(longPresses, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline approval buttons stay disabled', (tester) async {
    await _pump(
      tester,
      NeedsAttentionCard(
        session: _session().copyWith(presence: 'offline'),
        showFlavorIcon: false,
        onTap: () {},
        onLongPress: () {},
        permissionRequests: _requests,
      ),
      scale: 2,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
