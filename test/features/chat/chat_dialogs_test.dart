import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/providers/chat_action_notifier.dart';
import 'package:happy_flutter/features/chat/helpers/chat_dialogs.dart';

/// Records the calls the session menu makes, instead of reaching the message
/// repository (which is not initialized in a widget test).
class _RecordingChatActions extends ChatActionNotifier {
  final stopped = <String>[];

  @override
  Future<void> stopSessionProcess(String sessionId) async {
    stopped.add(sessionId);
  }
}

void main() {
  late _RecordingChatActions actions;

  setUp(() {
    actions = _RecordingChatActions();
  });

  Future<void> pumpMenu(WidgetTester tester) async {
    // The session menu is a tall bottom sheet; the default 800x600 test
    // surface puts the destructive actions below the fold.
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatActionNotifierProvider.overrideWith(() => actions),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showSessionMenu(
                    context,
                    sessionId: 's1',
                    onAbort: () {},
                  ),
                  child: const Text('open menu'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // GlitchTip 8778 / 8806 / 8804: the sheet was popped before `ref.read`, so
  // the read hit the sheet's unmounted Consumer and threw
  // `Using "ref" when a widget is about to or has been unmounted is unsafe`.
  // The throw was swallowed by the catch, which meant the stop never reached
  // the notifier — the user saw only a generic failure snackbar.
  testWidgets('stopping the agent process survives the sheet unmounting', (
    tester,
  ) async {
    await pumpMenu(tester);

    await tester.tap(find.text('open menu'));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.chatStopAgentProcess));
    await tester.pumpAndSettle();

    // The sheet is gone; the confirmation dialog is up.
    await tester.tap(find.text(l10n.chatStopAgentProcess));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      actions.stopped,
      ['s1'],
      reason: 'the notifier must be reached even though the sheet that '
          'hosted the tap is unmounted by the time the dialog resolves',
    );
  });

  testWidgets('cancelling the confirmation does not stop the process', (
    tester,
  ) async {
    await pumpMenu(tester);

    await tester.tap(find.text('open menu'));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.chatStopAgentProcess));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();

    expect(actions.stopped, isEmpty);
  });
}
