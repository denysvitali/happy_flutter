import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/tools.dart';
import 'package:happy_flutter/features/chat/tools/views/send_message_view.dart';

Widget _wrap(Map<String, dynamic> tool) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SendMessageView(tool: tool)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders recipient and body without raw JSON keys', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap({
        'name': 'SendMessage',
        'input': {
          'recipient': 'agent-2',
          'message': 'Please inspect the parser',
        },
        'state': 'completed',
        'result': {'status': 'delivered'},
      }),
    );

    expect(find.text('agent-2'), findsOneWidget);
    expect(find.text('Please inspect the parser'), findsOneWidget);
    expect(find.text('delivered'), findsOneWidget);
    expect(find.text('"recipient"'), findsNothing);
  });

  testWidgets('renders nested JSON argument envelope', (tester) async {
    await tester.pumpWidget(
      _wrap({
        'name': 'mcp__collab__send_message',
        'input': '{"arguments":{"to":"reviewer","content":"Check this"}}',
        'state': 'running',
      }),
    );

    expect(find.text('reviewer'), findsOneWidget);
    expect(find.text('Check this'), findsOneWidget);
    expect(find.text('Sending…'), findsOneWidget);
  });

  test('exports the dedicated SendMessage view', () {
    expect(SendMessageView, isNotNull);
  });
}
