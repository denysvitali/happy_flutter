import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/sync_state_notifier.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/widgets/sync_progress_bar.dart';

class _StubSyncStateNotifier extends SyncStateNotifier {
  _StubSyncStateNotifier(this.value);

  final SyncState value;

  @override
  SyncState build() => value;
}

void main() {
  testWidgets('shows detailed conversation fetch progress', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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

    expect(find.text('Fetching conversations 309/588'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
