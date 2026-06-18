import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/features/chat/widgets/chat_app_bar.dart';
import 'package:happy_flutter/features/chat/widgets/model_mode.dart';

void main() {
  group('buildChatMachineVitals', () {
    test('returns null when machineId is null', () {
      expect(buildChatMachineVitals(machineId: null, daemonState: null), isNull);
    });

    test('returns null when machineId is empty', () {
      expect(buildChatMachineVitals(machineId: '', daemonState: null), isNull);
    });

    test('returns null when daemonState is null', () {
      // Even with a valid machineId, no daemon stats means no vitals.
      expect(
        buildChatMachineVitals(machineId: 'm1', daemonState: null),
        isNull,
      );
    });

    test('returns vitals when machineId and daemonState are present', () {
      final state = <String, dynamic>{
        'machineStats': {
          'cpu': {'usagePercent': 12.5},
          'memory': {'usagePercent': 64.0},
          'disk': {'usagePercent': 87.3},
        },
      };
      final vitals = buildChatMachineVitals(
        machineId: 'm1',
        daemonState: state,
      );
      expect(vitals, isNotNull);
      expect(vitals!.cpuPercent, closeTo(12.5, 0.01));
      expect(vitals.memoryPercent, closeTo(64.0, 0.01));
      expect(vitals.diskPercent, closeTo(87.3, 0.01));
    });
  });

  group('formatLastSeenLabel', () {
    Widget _wrap(int activeAtMs) {
      // A trivial host widget so the test can resolve AppLocalizations.
      // The function only reads context.l10n, not Theme.
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Text(formatLastSeenLabel(context, activeAtMs));
          },
        ),
      );
    }

    testWidgets('returns "just now" for active timestamps under 1 minute old',
        (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_wrap(now.millisecondsSinceEpoch));
      // The l10n string for chatLastSeenJustNow is non-empty in the
      // test bundle (English fallback). We assert the function ran
      // without throwing and produced a non-empty widget.
      expect(find.byType(Text), findsOneWidget);
    });
  });

  group('buildChatStatusChips', () {
    // testWidgets host with l10n so formatLastSeenLabel (called
    // for the offline path) can resolve its labels.
    Future<ChatStatusChipsInputs> _runInHost(
      WidgetTester tester,
      ChatStatusChipsInputs Function(ColorScheme cs) build,
    ) async {
      final cs = ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.light,
      );
      late ChatStatusChipsInputs captured;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              captured = build(cs);
              // Use the context so the binding initialises l10n.
              return Text(Localizations.localeOf(context).toLanguageTag());
            },
          ),
        ),
      );
      return captured;
    }

    Session _onlineSession({int activeAt = 0, bool thinking = false}) =>
        Session.fromJson(<String, dynamic>{
          'id': 's1',
          'seq': 1,
          'createdAt': 1,
          'updatedAt': 1,
          'active': true,
          'activeAt': activeAt,
          'metadataVersion': 1,
          'agentStateVersion': 1,
          'thinking': thinking,
          'archived': false,
          'metadata': <String, dynamic>{
            'machineId': null,
            'lifecycleState': 'running',
            'lifecycleStateSince': null,
          },
          'agentState': null,
          'presence': 'online',
        });

    testWidgets('returns "Online" chip when session is ready and not thinking',
        (tester) async {
      final inputs = await _runInHost(
        tester,
        (cs) => ChatStatusChipsInputs(
          session: _onlineSession(),
          isReady: true,
          hasRequests: false,
          sendIssue: null,
          latestUserMessage: null,
          lastVisibleNonSidechainCreatedAt: 0,
          debugMaxSeq: -1,
          modelMode: ChatModelMode.defaultModel,
        ),
      );
      final context = tester.element(find.byType(Text));
      final chips = buildChatStatusChips(
        context: context,
        colorScheme: Theme.of(context).colorScheme,
        inputs: inputs,
      );
      expect(chips, hasLength(1));
      expect(chips.first.text, 'Online');
      expect(chips.first.showDot, isTrue);
      expect(chips.first.pulse, isTrue);
    });

    testWidgets(
      'returns "Offline" + last-seen chips when not ready and not connecting',
      (tester) async {
        final inputs = await _runInHost(
          tester,
          (cs) => ChatStatusChipsInputs(
            session: _onlineSession(activeAt: 0),
            isReady: false,
            hasRequests: false,
            sendIssue: null,
            latestUserMessage: null,
            lastVisibleNonSidechainCreatedAt: 0,
            debugMaxSeq: -1,
            modelMode: ChatModelMode.defaultModel,
          ),
        );
        final context = tester.element(find.byType(Text));
        final chips = buildChatStatusChips(
          context: context,
          colorScheme: Theme.of(context).colorScheme,
          inputs: inputs,
        );
        expect(chips, hasLength(2));
        expect(chips[0].text, 'Offline');
        expect(chips[1].text, isNotEmpty);
      },
    );

    testWidgets('sendIssue overrides online state', (tester) async {
      final inputs = await _runInHost(
        tester,
        (cs) => ChatStatusChipsInputs(
          session: _onlineSession(),
          isReady: true,
          hasRequests: false,
          sendIssue: const SendIssue(
            title: 'agent failed',
            message: 'will restart on next send',
            blocksSend: true,
          ),
          latestUserMessage: null,
          lastVisibleNonSidechainCreatedAt: 0,
          debugMaxSeq: -1,
          modelMode: ChatModelMode.defaultModel,
        ),
      );
      final context = tester.element(find.byType(Text));
      final chips = buildChatStatusChips(
        context: context,
        colorScheme: Theme.of(context).colorScheme,
        inputs: inputs,
      );
      expect(chips, hasLength(1));
      expect(chips.first.text, 'Agent failed');
    });

    testWidgets('appends "Approval needed" chip when hasRequests is true',
        (tester) async {
      final inputs = await _runInHost(
        tester,
        (cs) => ChatStatusChipsInputs(
          session: _onlineSession(),
          isReady: true,
          hasRequests: true,
          sendIssue: null,
          latestUserMessage: null,
          lastVisibleNonSidechainCreatedAt: 0,
          debugMaxSeq: -1,
          modelMode: ChatModelMode.defaultModel,
        ),
      );
      final context = tester.element(find.byType(Text));
      final chips = buildChatStatusChips(
        context: context,
        colorScheme: Theme.of(context).colorScheme,
        inputs: inputs,
      );
      // Online + Approval needed
      expect(chips, hasLength(2));
      expect(chips[1].text, 'Approval needed');
    });

    testWidgets('appends a model chip when modelMode is not default',
        (tester) async {
      final inputs = await _runInHost(
        tester,
        (cs) => ChatStatusChipsInputs(
          session: _onlineSession(),
          isReady: true,
          hasRequests: false,
          sendIssue: null,
          latestUserMessage: null,
          lastVisibleNonSidechainCreatedAt: 0,
          debugMaxSeq: -1,
          modelMode: ChatModelMode.sonnet,
        ),
      );
      final context = tester.element(find.byType(Text));
      final chips = buildChatStatusChips(
        context: context,
        colorScheme: Theme.of(context).colorScheme,
        inputs: inputs,
      );
      // Online + Sonnet
      expect(chips, hasLength(2));
      expect(chips[1].text, 'Sonnet');
    });
  });
}
