import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/performance_context_service.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';
import 'package:happy_flutter/features/sessions/widgets/session_headers.dart';
import 'package:happy_flutter/features/sessions/widgets/session_list_helpers.dart';
import 'package:happy_flutter/features/sessions/widgets/sessions_list_content.dart';

class _StubSettingsNotifier extends SettingsNotifier {
  @override
  Settings build() => Settings()..sessionsViewStyle = 'mission_control';
}

class _StubSessionsNotifier extends SessionsNotifier {
  @override
  Map<String, Session> build() => {_before.id: _before};

  void replaceWith(Session session) {
    state = {session.id: session};
  }
}

class _StubMachinesNotifier extends MachinesNotifier {
  @override
  Map<String, Machine> build() => const {};
}

class _StubSessionUiStateNotifier extends SessionUiStateNotifier {
  @override
  SessionUiState build() => const SessionUiState();
}

const _sessionId = 'retained-session';

final _before = _session('Before update');
final _after = _session('After update');

Session _session(String name) {
  return Session(
    id: _sessionId,
    seq: 1,
    createdAt: 1,
    updatedAt: 1,
    active: true,
    activeAt: 1,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: true,
    presence: 'online',
    metadata: Metadata(
      host: 'localhost',
      path: '/home/dev/happy_flutter',
      summary: Summary(text: name, updatedAt: 1),
    ),
  );
}

Widget _app({
  required ProviderContainer container,
  required ValueNotifier<SelectionState> selection,
  required ValueNotifier<SessionFolderHeader?> folder,
  required bool isVisible,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SessionsListContent(
          key: const ValueKey('sessions-list'),
          selectionNotifier: selection,
          folderNotifier: folder,
          isVisible: isVisible,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'retained hidden sessions tree ignores provider churn until visible',
    (tester) async {
      final performanceContext = PerformanceContextService()
        ..setCurrentRoute('sessions');
      addTearDown(performanceContext.resetForTesting);
      final container = ProviderContainer(
        overrides: [
          settingsNotifierProvider.overrideWith(_StubSettingsNotifier.new),
          sessionsNotifierProvider.overrideWith(_StubSessionsNotifier.new),
          machinesNotifierProvider.overrideWith(_StubMachinesNotifier.new),
          sessionUiStateNotifierProvider.overrideWith(
            _StubSessionUiStateNotifier.new,
          ),
        ],
      );
      final selection = ValueNotifier<SelectionState>(const SelectionState());
      final folder = ValueNotifier<SessionFolderHeader?>(null);
      addTearDown(() {
        selection.dispose();
        folder.dispose();
        container.dispose();
      });

      await tester.pumpWidget(
        _app(
          container: container,
          selection: selection,
          folder: folder,
          isVisible: true,
        ),
      );
      await tester.pump();
      expect(find.text('Before update'), findsOneWidget);

      await tester.pumpWidget(
        _app(
          container: container,
          selection: selection,
          folder: folder,
          isVisible: false,
        ),
      );
      await tester.pump();

      final sessionsNotifier =
          container.read(sessionsNotifierProvider.notifier)
              as _StubSessionsNotifier;
      sessionsNotifier.replaceWith(_after);
      await tester.pump();

      expect(find.text('Before update'), findsOneWidget);
      expect(find.text('After update'), findsNothing);

      await tester.pumpWidget(
        _app(
          container: container,
          selection: selection,
          folder: folder,
          isVisible: true,
        ),
      );
      await tester.pump();

      expect(find.text('Before update'), findsNothing);
      expect(find.text('After update'), findsOneWidget);
    },
  );
}
