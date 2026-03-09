import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/features/chat/widgets/chat_app_bar.dart';
import 'package:happy_flutter/features/sessions/widgets/session_cards.dart';

Session _session({required String flavor}) {
  return Session(
    id: 'session-1',
    seq: 1,
    createdAt: 1,
    updatedAt: 1,
    active: true,
    activeAt: 1,
    metadata: Metadata(
      host: 'host',
      path: '/repo',
      machineId: 'machine-1',
      flavor: flavor,
      name: 'Workspace',
    ),
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: 'online',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('chat app bar shows the provider badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: ChatAppBar(
            session: _session(flavor: 'codex'),
            sessionTitle: 'Workspace',
            statusText: 'Online',
            statusColor: Colors.green,
            isThinking: false,
            onMenuTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Codex'), findsOneWidget);
  });

  testWidgets('session cards show the provider badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionCard(
            session: _session(flavor: 'claude'),
            showFlavorIcon: false,
            isSingle: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Claude'), findsOneWidget);
  });
}
