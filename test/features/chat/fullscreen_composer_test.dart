import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/chat_input.dart';
import 'package:happy_flutter/features/chat/widgets/fullscreen_composer.dart';

Widget _buildComposer({
  required TextEditingController controller,
  required VoidCallback onSend,
  required String sessionId,
  bool isSendDisabled = false,
}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ChatInput(
            sessionId: sessionId,
            controller: controller,
            onSend: onSend,
            isSendDisabled: isSendDisabled,
          ),
        ),
      ),
    ),
  );
}

Finder _fullscreenField() {
  return find.descendant(
    of: find.byType(FullscreenComposerScreen),
    matching: find.byType(TextField),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('expands the draft into a full-screen editor and back', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'first paragraph');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        onSend: () {},
        sessionId: 'composer-expand',
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(ExpandComposerButton));
    await tester.pumpAndSettle();

    expect(_fullscreenField(), findsOneWidget);
    expect(
      tester.widget<TextField>(_fullscreenField()).controller?.text,
      'first paragraph',
    );

    await tester.enterText(_fullscreenField(), 'first paragraph\nsecond one');
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(
      find.byKey(const ValueKey<String>('fullscreen-composer-collapse')),
    );
    await tester.pumpAndSettle();

    // Editing full screen edits the same draft — nothing to copy back.
    expect(find.byType(FullscreenComposerScreen), findsNothing);
    expect(controller.text, 'first paragraph\nsecond one');
  });

  testWidgets('sending from the editor closes it and sends once', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sends = 0;

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        onSend: () => sends++,
        sessionId: 'composer-send',
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(ExpandComposerButton));
    await tester.pumpAndSettle();

    // Empty draft cannot send from the editor either.
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('fullscreen-composer-send')),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(_fullscreenField(), 'a very long prompt');
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(
      find.byKey(const ValueKey<String>('fullscreen-composer-send')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FullscreenComposerScreen), findsNothing);
    expect(sends, 1);
  });

  testWidgets('a blocked session cannot send from the editor', (tester) async {
    final controller = TextEditingController(text: 'queued prompt');
    addTearDown(controller.dispose);
    var sends = 0;

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        onSend: () => sends++,
        sessionId: 'composer-blocked',
        isSendDisabled: true,
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(ExpandComposerButton));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('fullscreen-composer-send')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FullscreenComposerScreen), findsOneWidget);
    expect(sends, 0);
  });
}
