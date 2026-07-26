import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/bot_message.dart';
import 'package:happy_flutter/features/chat/widgets/message_focus_view.dart';
import 'package:happy_flutter/features/chat/widgets/user_bubble.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: child),
      ),
    ),
  );
}

/// The message copy the focus view keeps sharp. It sits under the blur
/// layer's sibling, so both the in-place bubble (behind the blur) and the
/// copy match the same text finder.
Finder _blurLayer() => find.byType(BackdropFilter);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('long-press focus view', () {
    testWidgets('blurs the conversation and shows the details card', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BotMessage(
            text: 'focus me',
            messageData: <String, dynamic>{
              'id': 'msg-1',
              'model': 'claude-opus-5',
              'createdAt': 1700000000000,
              'meta': <String, dynamic>{'permissionMode': 'default'},
            },
          ),
        ),
      );

      expect(_blurLayer(), findsNothing);
      expect(find.textContaining('focus me'), findsOneWidget);

      await tester.longPress(find.textContaining('focus me'));
      await tester.pumpAndSettle();

      // The conversation behind the focused copy is blurred.
      expect(_blurLayer(), findsOneWidget);
      final filter = tester.widget<BackdropFilter>(_blurLayer()).filter;
      expect(filter, isA<ui.ImageFilter>());

      // The message itself is rendered a second time, sharp, above the blur.
      expect(find.textContaining('focus me'), findsNWidgets(2));

      // ...with its information as a card of meta chips plus actions.
      expect(find.byType(MessageFocusCard), findsOneWidget);
      expect(find.text('claude-opus-5'), findsOneWidget);
      expect(find.text('default'), findsOneWidget);
      expect(find.text('Select text'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('the focused copy is inert — tapping it dismisses', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BotMessage(
            text: 'focus me',
            messageData: <String, dynamic>{'id': 'msg-1'},
          ),
        ),
      );

      await tester.longPress(find.textContaining('focus me'));
      await tester.pumpAndSettle();
      expect(_blurLayer(), findsOneWidget);

      // The copy is the second instance of the text — the one above the
      // blur. Taps on it must fall through to the dismiss barrier rather
      // than being swallowed (or worse, re-triggering message gestures).
      final copy = find.textContaining('focus me').last;
      final ignorers = tester.widgetList<IgnorePointer>(
        find.ancestor(of: copy, matching: find.byType(IgnorePointer)),
      );
      expect(ignorers.any((widget) => widget.ignoring), isTrue);

      await tester.tapAt(tester.getCenter(copy));
      await tester.pumpAndSettle();

      expect(_blurLayer(), findsNothing);
    });

    testWidgets('tapping the blurred background dismisses it', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BotMessage(
            text: 'focus me',
            messageData: <String, dynamic>{'id': 'msg-1'},
          ),
        ),
      );

      await tester.longPress(find.textContaining('focus me'));
      await tester.pumpAndSettle();
      expect(_blurLayer(), findsOneWidget);

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(_blurLayer(), findsNothing);
      expect(find.textContaining('focus me'), findsOneWidget);
    });

    testWidgets('Copy pops the focus view and writes the clipboard', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        _wrap(
          const BotMessage(
            text: 'copy this message',
            messageData: <String, dynamic>{'id': 'msg-1'},
          ),
        ),
      );

      await tester.longPress(find.textContaining('copy this message'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(_blurLayer(), findsNothing);

      // The clipboard write happens after the overlay has popped, so it
      // needs another turn of the async queue.
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'Clipboard.setData'),
        isNotEmpty,
      );
      expect(
        calls
            .firstWhere((call) => call.method == 'Clipboard.setData')
            .arguments['text'],
        'copy this message',
      );
    });

    testWidgets('user messages focus too and surface their send status', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const UserBubble(
            text: 'my own message',
            messageData: <String, dynamic>{
              'id': 'local-1',
              'sendStatus': 'sending',
              'createdAt': 1700000000000,
            },
          ),
        ),
      );

      await tester.longPress(find.textContaining('my own message'));
      await tester.pumpAndSettle();

      expect(_blurLayer(), findsOneWidget);
      expect(find.byType(MessageFocusCard), findsOneWidget);
      expect(find.text('sending'), findsOneWidget);
      // createdAt is November 2023, rendered as an absolute date chip.
      expect(find.textContaining('2023'), findsOneWidget);
    });
  });
}
