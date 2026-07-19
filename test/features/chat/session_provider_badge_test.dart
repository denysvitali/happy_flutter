import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/chat/widgets/chat_app_bar.dart';
import 'package:happy_flutter/features/sessions/session_avatar.dart';
import 'package:happy_flutter/features/sessions/widgets/session_cards.dart';

import '../loops/loop_notifier_test_helpers.dart';

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

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      loopsNotifierProvider.overrideWith(StubLoopsNotifier.new),
    ],
    child: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('chat app bar uses the same pixelated session avatar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: ChatAppBar(
              session: _session(flavor: 'codex'),
              sessionTitle: 'Workspace',
              statusChips: const [
                ChatAppBarStatusChip(
                  text: 'Connected',
                  color: Colors.green,
                  showDot: true,
                ),
              ],
              onMenuTap: () {},
              onInfoTap: () {},
              sessionId: 'session-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final avatar = tester.widget<SessionAvatar>(find.byType(SessionAvatar));
    expect(avatar.style, isNull);
    expect(avatar.showFlavorIcon, isTrue);
  });

  testWidgets('chat app bar shows machine vitals when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: ChatAppBar(
              session: _session(flavor: 'codex'),
              sessionTitle: 'Workspace',
              statusChips: const [],
              machineVitals: const ChatMachineVitals(
                cpuPercent: 12,
                memoryPercent: 48,
                diskPercent: 73,
              ),
              onMenuTap: () {},
              onInfoTap: () {},
              sessionId: 'session-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Machine'), findsOneWidget);
    expect(find.text('CPU 12%'), findsOneWidget);
    expect(find.text('MEM 48%'), findsOneWidget);
    expect(find.text('DISK 73%'), findsOneWidget);

    await tester.tap(find.text('Machine'));
    await tester.pumpAndSettle();

    expect(find.text('Machine health'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
  });

  testWidgets('chat app bar can show an embedded back button', (tester) async {
    var backTapped = false;
    await tester.pumpWidget(
      _wrap(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: ChatAppBar(
              session: _session(flavor: 'codex'),
              sessionTitle: 'Workspace',
              statusChips: const [],
              onMenuTap: () {},
              onInfoTap: () {},
              onBackTap: () => backTapped = true,
              sessionId: 'session-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(backTapped, isTrue);
  });

  testWidgets('session cards use hash-based avatar style by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SessionCard(
              session: _session(flavor: 'claude'),
              showFlavorIcon: false,
              isSingle: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final avatar = tester.widget<SessionAvatar>(find.byType(SessionAvatar));
    expect(avatar.style, isNull);
    expect(avatar.showFlavorIcon, isTrue);
  });
}
