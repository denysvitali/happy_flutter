import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/views/todo_view.dart';

/// Progressive-lag remediation, 2026-08-24.
///
/// The in-progress pulse icon ran an unbounded `repeat()` for as long as it
/// was mounted. A resting chat whose latest TodoWrite snapshot contains an
/// in_progress item (the normal state of any interrupted plan) therefore
/// animated at full refresh rate forever — production telemetry showed the
/// chat route never once recorded an idle render window. The pulse is now a
/// bounded intro: a few cycles, then a static icon.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(TodoView.resetPushGuard);
  tearDown(TodoView.resetPushGuard);

  Map<String, dynamic> inProgressTool() => <String, dynamic>{
    'name': 'TodoWrite',
    'toolUseId': 'call_todo',
    'state': 'completed',
    'createdAt': 1000,
    'input': {
      'todos': [
        {'content': 'Half-done step', 'status': 'in_progress'},
        {'content': 'Next step', 'status': 'pending'},
      ],
    },
  };

  Widget wrap(ProviderContainer container, Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  testWidgets('in-progress pulse settles to a static icon '
      '(bounded intro, not an unbounded repeat)', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      wrap(container, TodoView(tool: inProgressTool(), sessionId: 's1')),
    );

    // The intro is animating shortly after mount.
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.hasRunningAnimations, isTrue);

    // 3 cycles × (900ms forward + 900ms reverse) = 5.4s. Walk well past
    // that in bounded pumps — pumpAndSettle would have hung forever on
    // the old unbounded repeat.
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }

    expect(
      tester.hasRunningAnimations,
      isFalse,
      reason:
          'a visible in-progress todo row must not keep the frame '
          'pipeline warm forever',
    );
    // The row still renders its in-progress icon.
    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
  });
}
