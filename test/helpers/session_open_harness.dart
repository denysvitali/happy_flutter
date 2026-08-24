// Shared harness for the "tap session X opens session X" contract suite.
//
// Every entry point that can open a chat is pumped under one GoRouter whose
// `/chat/:sessionId` page records the id it was opened with. The fixture
// deliberately seeds several sessions with near-identical metadata (same
// host, machine and path) and distinct labels, so any id/label
// misalignment in a list, row, palette item or notification payload shows
// up as the wrong recorded id.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/chat_switch_metrics.dart';

/// Shared metadata for every fixture session — identical on purpose.
const contractSessionHost = 'build-box.local';
const contractSessionPath = '/home/dev/happy_flutter';
const contractSessionMachineId = 'machine-1';

/// Fixture ids. Ids and labels intentionally share no prefix so a test that
/// accidentally matches on the label cannot pass by coincidence.
const contractAlphaId = 'c0ffee0001';
const contractBravoId = 'c0ffee0002';
const contractCharlieId = 'c0ffee0003';
const contractDeltaId = 'c0ffee0004';
const contractEchoId = 'c0ffee0005';
const contractFoxtrotId = 'c0ffee0006';

const contractAlphaLabel = 'Alpha review';
const contractBravoLabel = 'Bravo review';
const contractCharlieLabel = 'Charlie review';
const contractDeltaLabel = 'Delta review';
const contractEchoLabel = 'Echo review';
const contractFoxtrotLabel = 'Foxtrot review';

/// Label of every fixture session keyed by id.
const contractLabels = <String, String>{
  contractAlphaId: contractAlphaLabel,
  contractBravoId: contractBravoLabel,
  contractCharlieId: contractCharlieLabel,
  contractDeltaId: contractDeltaLabel,
  contractEchoId: contractEchoLabel,
  contractFoxtrotId: contractFoxtrotLabel,
};

/// Builds one fixture session. [label] feeds both `metadata.summary`
/// (session list cards) and `metadata.name` (command palette / artifacts).
Session contractSession({
  required String id,
  required String label,
  bool archived = false,
  bool thinking = false,
  String presence = 'offline',
  Duration age = const Duration(minutes: 5),
  AgentState? agentState,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final at = now - age.inMilliseconds;
  return Session(
    id: id,
    seq: 1,
    createdAt: at - 60000,
    updatedAt: at,
    active: !archived,
    activeAt: at,
    archived: archived,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: archived ? 'offline' : presence,
    agentState: agentState,
    metadata: Metadata(
      host: contractSessionHost,
      path: contractSessionPath,
      machineId: contractSessionMachineId,
      name: label,
      summary: Summary(text: label, updatedAt: at),
    ),
  );
}

/// Six sessions, all in the same folder/machine:
///
/// * Alpha   — active, online, thinking (Mission Control "live" lane)
/// * Bravo   — active, online, pending permission ("blocked" lane)
/// * Charlie — active, offline (quiet)
/// * Delta   — archived today (recent archived)
/// * Foxtrot — archived two days ago (recent archived, other date group)
/// * Echo    — archived ten days ago (older archived)
Map<String, Session> contractSessions() {
  final sessions = <Session>[
    contractSession(
      id: contractAlphaId,
      label: contractAlphaLabel,
      thinking: true,
      presence: 'online',
      age: const Duration(minutes: 1),
    ),
    contractSession(
      id: contractBravoId,
      label: contractBravoLabel,
      presence: 'online',
      age: const Duration(minutes: 2),
      agentState: AgentState(
        requests: {
          'perm-1': RequestInfo(
            tool: 'Bash',
            createdAt: DateTime.now().millisecondsSinceEpoch - 1000,
          ),
        },
      ),
    ),
    contractSession(
      id: contractCharlieId,
      label: contractCharlieLabel,
      age: const Duration(minutes: 3),
    ),
    contractSession(
      id: contractDeltaId,
      label: contractDeltaLabel,
      archived: true,
      age: const Duration(minutes: 4),
    ),
    contractSession(
      id: contractFoxtrotId,
      label: contractFoxtrotLabel,
      archived: true,
      age: const Duration(days: 2),
    ),
    contractSession(
      id: contractEchoId,
      label: contractEchoLabel,
      archived: true,
      age: const Duration(days: 10),
    ),
  ];
  return {for (final s in sessions) s.id: s};
}

/// Records every chat route that was actually opened, in order.
class SessionOpenRecorder {
  final List<String> opened = <String>[];

  String? get last => opened.isEmpty ? null : opened.last;
}

/// Cancels the 15 s `ChatSwitchMetrics` timeout armed by every tap so the
/// test binding does not report a pending timer after teardown.
void cancelContractChatSwitchMetrics({Iterable<String> extraIds = const []}) {
  final metrics = ChatSwitchMetrics();
  for (final id in contractLabels.keys.followedBy(extraIds)) {
    metrics.cancel(id);
  }
}

/// Stand-in for the chat route. `initState` records exactly once per push,
/// so rebuilds never double count and a debounced second tap never shows.
class SessionOpenChatStub extends StatefulWidget {
  const SessionOpenChatStub({
    required this.sessionId,
    required this.recorder,
    super.key,
  });

  final String sessionId;
  final SessionOpenRecorder recorder;

  @override
  State<SessionOpenChatStub> createState() => _SessionOpenChatStubState();
}

class _SessionOpenChatStubState extends State<SessionOpenChatStub> {
  @override
  void initState() {
    super.initState();
    widget.recorder.opened.add(widget.sessionId);
    // The real ChatScreen closes the tap-to-content attempt once content
    // paints; the stub closes it immediately so no 15 s timeout remains.
    ChatSwitchMetrics().cancel(widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('chat:${widget.sessionId}')));
  }
}

/// Router with `/` → [home] and the named `chat` route
/// (`/chat/:sessionId`) → [SessionOpenChatStub].
GoRouter buildSessionOpenRouter({
  required SessionOpenRecorder recorder,
  required WidgetBuilder home,
  String initialLocation = '/',
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', builder: (context, _) => home(context)),
      GoRoute(path: '/sessions', builder: (context, _) => home(context)),
      GoRoute(
        path: '/chat/:sessionId',
        name: 'chat',
        builder: (_, state) => SessionOpenChatStub(
          sessionId: state.pathParameters['sessionId']!,
          recorder: recorder,
        ),
      ),
    ],
  );
}

/// Localized `MaterialApp.router` under an [UncontrolledProviderScope].
Widget buildSessionOpenApp({
  required ProviderContainer container,
  required GoRouter router,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

/// Storage-free settings notifier with a configurable initial value.
class ContractSettingsNotifier extends SettingsNotifier {
  ContractSettingsNotifier(this._initial);

  final Settings Function() _initial;

  @override
  Settings build() => _initial();

  @override
  Future<void> updateSetting<T>(String key, T value) async {
    final json = state.toJson();
    json[key] = value;
    state = Settings.fromJson(json);
  }
}

/// Sessions notifier seeded from memory; never touches `Sync`.
class ContractSessionsNotifier extends SessionsNotifier {
  ContractSessionsNotifier(this._initial);

  final Map<String, Session> _initial;

  @override
  Map<String, Session> build() => _initial;

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync({bool includeMachines = false}) async {}

  /// Publishes [session] under its id, replacing any previous entry.
  void replace(Session session) {
    state = {...state, session.id: session};
  }

  /// Simulates an archive landing for [sessionId]: the card must move to
  /// the archived bucket while keeping its id.
  void archive(String sessionId) {
    final current = state[sessionId]!;
    replace(
      current.copyWith(
        archived: true,
        active: false,
        thinking: false,
        presence: 'offline',
      ),
    );
  }
}

class ContractMachinesNotifier extends MachinesNotifier {
  @override
  Map<String, Machine> build() => const {};

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync() async {}
}

/// UI-state notifier with a fixed, `Sync`-free projection.
class ContractSessionUiStateNotifier extends SessionUiStateNotifier {
  ContractSessionUiStateNotifier([this._initial = const SessionUiState()]);

  final SessionUiState _initial;

  @override
  SessionUiState build() => _initial;

  @override
  void loadFromSync() {}

  @override
  void loadSessionFromSync(String sessionId) {}

  /// Replaces the projection wholesale (e.g. to mark an optimistic archive).
  void publish(SessionUiState next) {
    state = next;
  }
}

/// Provider overrides shared by every list-level entry point.
List<Override> contractListOverrides({
  required Settings Function() settings,
  Map<String, Session>? sessions,
  SessionUiState uiState = const SessionUiState(),
}) {
  return [
    settingsNotifierProvider.overrideWith(
      () => ContractSettingsNotifier(settings),
    ),
    sessionsNotifierProvider.overrideWith(
      () => ContractSessionsNotifier(sessions ?? contractSessions()),
    ),
    machinesNotifierProvider.overrideWith(ContractMachinesNotifier.new),
    sessionUiStateNotifierProvider.overrideWith(
      () => ContractSessionUiStateNotifier(uiState),
    ),
  ];
}
