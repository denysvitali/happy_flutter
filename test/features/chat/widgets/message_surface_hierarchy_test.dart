import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/bot_message.dart';
import 'package:happy_flutter/features/chat/widgets/user_bubble.dart';

Widget _app(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('assistant prose uses an open surface with one group marker', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const BotMessage(
          text: 'A clear response',
          messageData: <String, dynamic>{'id': 'assistant-1'},
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('assistant-message-surface')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('assistant-message-marker')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _app(
        const BotMessage(
          text: 'Continuation',
          messageData: <String, dynamic>{'id': 'assistant-2'},
          isFirstInGroup: false,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('assistant-message-marker')),
      findsNothing,
    );
  });

  testWidgets('user turn keeps a distinct tonal message surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const UserBubble(text: 'Please make this easier to scan.')),
    );

    final surface = find.byKey(const ValueKey<String>('user-message-surface'));
    expect(surface, findsOneWidget);
    final container = tester.widget<Container>(surface);
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, isNotNull);
    expect(decoration.gradient, isNull);
    expect(decoration.boxShadow, isNull);
  });
}
