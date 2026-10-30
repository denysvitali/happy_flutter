import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/app_badge.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/session_ui_state_notifier.dart';
import 'package:happy_flutter/core/ui/agent_identity.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_action_tile.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_types.dart';

Session _session(String title) {
  final at = DateTime.now().millisecondsSinceEpoch;
  return Session(
    id: 'session-$title',
    seq: 1,
    createdAt: at,
    updatedAt: at,
    active: true,
    activeAt: at,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: 'online',
    metadata: Metadata(
      host: 'devbox',
      path: '/home/dev/git/fw-analyzer',
      summary: Summary(text: title, updatedAt: at),
    ),
  );
}

MissionActionRow _row(String title, MissionLane lane, int unread) =>
    MissionActionRow(
      session: _session(title),
      entry: SessionUiEntry(
        lastMessagePreview: 'Check also provisioning-api',
        lastMessageTimestamp: DateTime.now().millisecondsSinceEpoch,
        unreadCount: unread,
      ),
      lane: lane,
      animateActivity: false,
      onTap: () {},
      onLongPress: () {},
      onArchive: () {},
      onMarkRead: () {},
    );

Widget _app(Widget child) => ProviderScope(
  child: MaterialApp(
    theme: ThemeHelper.buildDarkTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('phone row lines up avatar, text, age, pill and menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(376, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(_row('fw-analyzer', MissionLane.unread, 1)));

    final row = tester.getRect(find.byType(MissionActionRow));
    final title = tester.getRect(find.text('fw-analyzer'));
    final preview = tester.getRect(find.text('Check also provisioning-api'));
    final age = tester.getRect(find.text('Just now'));
    final pill = tester.getRect(
      find.ancestor(of: find.text('1 new'), matching: find.byType(AppBadge)),
    );
    // The row leads with the teammate's agent-identity avatar.
    final tile = tester.getRect(find.byType(AgentAvatar));
    expect(tile.size, const Size.square(missionAvatarSize));
    final menu = tester.getRect(find.byTooltip('Session actions'));
    final dots = tester.getRect(find.byIcon(Icons.more_vert_rounded));

    // The avatar's top edge matches the title's glyph top (3dp below its
    // line box), and the text column starts one shared gap after it.
    expect(tile.top - title.top, closeTo(3, 0.5));
    expect(title.left - tile.right, closeTo(missionRowTextGap, 0.5));
    expect(preview.left, closeTo(title.left, 0.5));
    // Title and update read as one block, not two separated lines.
    expect(preview.top - title.bottom, lessThanOrEqualTo(6.5));
    // Age and pill share a right edge; the menu is centered on the block.
    expect(pill.right, closeTo(age.right, 0.5));
    expect(menu.size, const Size(44, 44));
    expect(menu.center.dy, closeTo(row.center.dy, 2.5));
    // The menu's dots mirror the tile's left inset (the glyph box has
    // 10/24 of its width of empty space either side of the dots).
    final dotsRight = dots.right - dots.width * 10 / 24;
    expect(row.right - dotsRight, closeTo(tile.left - row.left, 1));
    // The smaller age shares the title's baseline instead of floating above
    // it, and the age sits a short step from the menu's dots, not a whole
    // 44dp target away.
    double baseline(Finder text) {
      final paragraph = tester.renderObject<RenderParagraph>(text);
      final painter = TextPainter(
        text: paragraph.text,
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
      )..layout(maxWidth: paragraph.size.width);
      return tester.getRect(text).top +
          painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    }

    expect(
      baseline(find.text('Just now')),
      closeTo(baseline(find.text('fw-analyzer')), 0.5),
    );
    final dotsLeft = dots.left + dots.width * 10 / 24;
    expect(dotsLeft - age.right, inInclusiveRange(12, 28));
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone rows keep one height with or without an unread pill', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(376, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            _row('with-pill', MissionLane.unread, 1),
            _row('without-pill', MissionLane.quiet, 0),
          ],
        ),
      ),
    );
    final heights = [
      for (final row in tester.widgetList(find.byType(MissionActionRow)))
        tester.getSize(find.byWidget(row)).height,
    ];
    expect(heights, hasLength(2));
    expect(heights[0], closeTo(heights[1], 0.5));
    expect(tester.takeException(), isNull);
  });
}
