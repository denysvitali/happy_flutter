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
                progress: SyncProgress(
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

    expect(find.text('Syncing'), findsOneWidget);
    expect(
      find.text('Fetching conversations - 309 of 588 complete'),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('shows one reconnecting status while sync is active', (
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
                progress: SyncProgress(
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

    expect(find.text('Connecting'), findsOneWidget);
    expect(
      find.text('Sync is waiting for live updates to reconnect'),
      findsOneWidget,
    );
    expect(find.text('Syncing'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
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
                progress: SyncProgress(
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

    expect(find.text('Syncing'), findsOneWidget);
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

    expect(find.text('Data refresh failed'), findsOneWidget);
    expect(
      find.text('Sessions or machines may be out of date'),
      findsOneWidget,
    );
    expect(find.text('Syncing'), findsNothing);
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

    expect(find.text('Data refresh failed'), findsNothing);
    expect(find.byKey(const ValueKey('idle')), findsOneWidget);
  });
}
