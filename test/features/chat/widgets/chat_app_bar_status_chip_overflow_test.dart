import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/features/chat/widgets/chat_app_bar.dart';
import 'package:happy_flutter/features/chat/widgets/chat_app_bar_status.dart';

Session _session() => Session.fromJson(<String, dynamic>{
  'id': 's1',
  'seq': 1,
  'createdAt': 1,
  'updatedAt': 1,
  'active': true,
  'activeAt': 1,
  'metadataVersion': 1,
  'agentStateVersion': 1,
  'thinking': true,
  'archived': false,
  'metadata': <String, dynamic>{
    'path': '/root/firmware/p5-4-boot-a-deadman',
    'host': 'dc1-shuttle.local',
  },
  'agentState': null,
  'presence': 'online',
});

Widget _harness(List<ChatAppBarStatusChip> chips) {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: ChatAppBar(
          session: _session(),
          sessionTitle: 'P5.4 boot_a deadman oracle',
          sessionId: 's1',
          statusChips: chips,
          onMenuTap: () {},
          onInfoTap: () {},
        ),
        body: const SizedBox.shrink(),
      ),
    ),
  );
}

/// Every chip label must render in full — no per-chip ellipsis.
void _expectNoTruncatedChip(WidgetTester tester, List<String> labels) {
  for (final label in labels) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text(label),
    );
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: 'status chip "$label" was ellipsized in the app bar',
    );
  }
}

void main() {
  const chips = [
    ChatAppBarStatusChip(
      text: 'Online',
      color: Color(0xFF4CAF50),
      showDot: true,
    ),
    ChatAppBarStatusChip(
      text: 'Thinking',
      color: Color(0xFF7C93FF),
      showDot: true,
    ),
  ];

  group('ChatAppBar status chips', () {
    // Phone viewport — the width where "Online"/"Thinking" collapsed to
    // "On…"/"Th…" because every chip shared the row via Flexible.
    testWidgets('renders both labels in full on a phone-width app bar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(chips));
      await tester.pumpAndSettle();

      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Thinking'), findsOneWidget);
      _expectNoTruncatedChip(tester, ['Online', 'Thinking']);
    });

    testWidgets('scrolls a long chip set instead of overflowing the row', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _harness(const [
          ...chips,
          ChatAppBarStatusChip(
            text: 'Approval needed',
            color: Color(0xFFFFB020),
            icon: Icons.shield_outlined,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      // No chip is mangled and the Row never overflows — the strip scrolls.
      _expectNoTruncatedChip(tester, [
        'Online',
        'Thinking',
        'Approval needed',
      ]);
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(ChatAppBar),
          matching: find.byType(Scrollable),
        ),
        findsWidgets,
      );
    });

    testWidgets('capture', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(chips));
      await tester.pumpAndSettle();

      final out = Platform.environment['CHAT_APP_BAR_CAPTURE'];
      if (out == null) return;
      final image = await tester.binding.runAsync(
        () => captureImage(find.byType(ChatAppBar).evaluate().first),
      );
      final bytes = await tester.binding.runAsync(
        () => image!.toByteData(format: ImageByteFormat.png),
      );
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
