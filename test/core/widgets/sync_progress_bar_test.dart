import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart'
    show ConnectionStatus;
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/connection_notifier.dart';
import 'package:happy_flutter/core/providers/network_notifier.dart';
import 'package:happy_flutter/core/providers/sync_state_notifier.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/widgets/sync_progress_bar.dart';

class _StubSyncStateNotifier extends SyncStateNotifier {
  _StubSyncStateNotifier(this.value);

  final SyncState value;

  @override
  SyncState build() => value;
}

class _StubNetworkNotifier extends NetworkNotifier {
  _StubNetworkNotifier(this.value);

  final bool value;

  @override
  bool build() => value;
}

class _StubConnectionNotifier extends ConnectionNotifier {
  _StubConnectionNotifier(this.value);

  final ConnectionStatus value;

  @override
  ConnectionStatus build() => value;
}

void main() {
  testWidgets('shows detailed conversation fetch progress', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkNotifierProvider.overrideWith(
            () => _StubNetworkNotifier(true),
          ),
          connectionNotifierProvider.overrideWith(
            () => _StubConnectionNotifier(ConnectionStatus.connected),
          ),
          syncStateNotifierProvider.overrideWith(
            () => _StubSyncStateNotifier(
              const SyncState(
                isSyncing: true,
                catalogProgress: SyncProgress(
                  label: 'Fetching conversations',
                  completed: 309,
                  total: 588,
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncProgressBar())),
      ),
    );

    // Routine sub-second refreshes never flash the pill.
    expect(find.textContaining('Fetching conversations'), findsNothing);

    await tester.pump(SyncProgressBar.showDelay);
    await tester.pumpAndSettle();

    expect(
      find.text('Fetching conversations  309 of 588', findRichText: true),
      findsOneWidget,
    );
    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, closeTo(309 / 588, 0.001));
  });

  testWidgets('does not duplicate socket recovery while sync is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkNotifierProvider.overrideWith(
            () => _StubNetworkNotifier(true),
          ),
          connectionNotifierProvider.overrideWith(
            () => _StubConnectionNotifier(ConnectionStatus.connecting),
          ),
          syncStateNotifierProvider.overrideWith(
            () => _StubSyncStateNotifier(
              const SyncState(
                isSyncing: true,
                catalogProgress: SyncProgress(
                  label: 'Fetching conversations',
                  completed: 12,
                  total: 40,
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncProgressBar())),
      ),
    );

    await tester.pump(SyncProgressBar.showDelay);
    await tester.pumpAndSettle();

    expect(find.text('Connecting'), findsNothing);
    expect(find.textContaining('Fetching conversations'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('overlay does not shift child layout when status is visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkNotifierProvider.overrideWith(
            () => _StubNetworkNotifier(true),
          ),
          connectionNotifierProvider.overrideWith(
            () => _StubConnectionNotifier(ConnectionStatus.connected),
          ),
          syncStateNotifierProvider.overrideWith(
            () => _StubSyncStateNotifier(
              const SyncState(
                isSyncing: true,
                catalogProgress: SyncProgress(
                  label: 'Fetching conversations',
                  completed: 12,
                  total: 40,
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SyncProgressOverlay(
              child: Align(
                alignment: Alignment.topCenter,
                child: Text('Pinned content'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(SyncProgressBar.showDelay);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Fetching conversations', findRichText: true),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('Pinned content')).dy,
      moreOrLessEquals(0),
    );
  });

  testWidgets('keeps an exhausted critical data refresh failure visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkNotifierProvider.overrideWith(
            () => _StubNetworkNotifier(true),
          ),
          connectionNotifierProvider.overrideWith(
            () => _StubConnectionNotifier(ConnectionStatus.connected),
          ),
          syncStateNotifierProvider.overrideWith(
            () => _StubSyncStateNotifier(
              const SyncState(hasCriticalFailure: true),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncProgressBar())),
      ),
    );

    await tester.pumpAndSettle();

    // Failures surface immediately; only progress waits for the delay.
    expect(
      find.text(
        'Data refresh failed  Sessions or machines may be out of date',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('successful recovery returns the status bar to idle', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkNotifierProvider.overrideWith(
            () => _StubNetworkNotifier(true),
          ),
          connectionNotifierProvider.overrideWith(
            () => _StubConnectionNotifier(ConnectionStatus.connected),
          ),
          syncStateNotifierProvider.overrideWith(
            () => _StubSyncStateNotifier(const SyncState()),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncProgressBar())),
      ),
    );

    expect(find.textContaining('Data refresh failed'), findsNothing);
    expect(find.byKey(const ValueKey('idle')), findsOneWidget);
  });

  Widget harness(SyncState state, {required SyncStatusScope scope}) {
    return ProviderScope(
      // A fresh scope per state: overrides cannot change on a live scope.
      key: UniqueKey(),
      overrides: [
        networkNotifierProvider.overrideWith(() => _StubNetworkNotifier(true)),
        connectionNotifierProvider.overrideWith(
          () => _StubConnectionNotifier(ConnectionStatus.connected),
        ),
        syncStateNotifierProvider.overrideWith(
          () => _StubSyncStateNotifier(state),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(body: SyncProgressBar(scope: scope)),
      ),
    );
  }

  testWidgets('background refreshes never surface on the sessions list', (
    tester,
  ) async {
    // Settings, machines, git status and unopened chats keep isSyncing true
    // with a fallback label, but none of it is conversation catalog work.
    await tester.pumpWidget(
      harness(
        const SyncState(
          isSyncing: true,
          progress: SyncProgress(label: 'Syncing Machines and 3 more'),
        ),
        scope: SyncStatusScope.sessions,
      ),
    );
    await tester.pump(SyncProgressBar.showDelay * 2);
    await tester.pumpAndSettle();

    expect(find.textContaining('Syncing'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('idle')), findsOneWidget);
  });

  testWidgets('chat scope reports only the open chat catch-up', (tester) async {
    await tester.pumpWidget(
      harness(
        const SyncState(
          isSyncing: true,
          catalogProgress: SyncProgress(
            label: 'Fetching conversations',
            completed: 1,
            total: 7,
          ),
        ),
        scope: SyncStatusScope.chat,
      ),
    );
    await tester.pump(SyncProgressBar.showDelay * 2);
    await tester.pumpAndSettle();
    expect(find.textContaining('Fetching conversations'), findsNothing);

    await tester.pumpWidget(
      harness(
        const SyncState(isSyncing: true, isVisibleChatSyncing: true),
        scope: SyncStatusScope.chat,
      ),
    );
    expect(find.text('Loading new messages'), findsNothing);
    await tester.pump(SyncProgressBar.showDelay);
    // The spinner is indeterminate, so pump past the fade-in rather than
    // waiting for the tree to settle.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Loading new messages'), findsOneWidget);
  });
}
