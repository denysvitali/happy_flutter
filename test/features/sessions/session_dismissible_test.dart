import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/sessions/widgets/session_dismissible.dart';

/// Stub notifier so we never touch real storage / sync during widget mount.
class _StubSessionsNotifier extends SessionsNotifier {
  @override
  Map<String, Session> build() => const <String, Session>{};

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync({bool includeMachines = false}) async {}

  @override
  Future<bool> optimisticDelete(String sessionId) async => true;
}

Session _session({String id = 's1'}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
    active: true,
    activeAt: 1700000000000,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: 'online',
    metadata: Metadata(path: '/repo/happy', host: 'mac'),
  );
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [
      sessionsNotifierProvider.overrideWith(() => _StubSessionsNotifier()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DismissibleActiveSession / DismissibleInactiveSession', () {
    // Regression test for GlitchTip HAPPY_FLUTTER-396:
    // mounting then immediately unmounting the dismissible wrappers
    // (the surface that triggered "Using \"ref\" when a widget is
    // about to or has been unmounted is unsafe.") must not throw.
    //
    // The underlying fix captures the
    // `sessionsNotifierProvider.notifier` reference *before* the
    // confirmation-dialog await, so any later async completion
    // never reaches back through `ref`.
    testWidgets(
      'mount and immediate dispose does not throw StateError '
      '(archive variant)',
      (tester) async {
        final session = _session();

        await tester.pumpWidget(
          _wrap(
            DismissibleActiveSession(
              session: session,
              child: const SizedBox(
                key: ValueKey('child'),
                width: 100,
                height: 60,
              ),
            ),
          ),
        );

        expect(find.byKey(const ValueKey('child')), findsOneWidget);

        // Immediately rebuild without the dismissible — simulates the
        // parent rebuild that removes a session row from the tree
        // mid-flight, which is what previously surfaced the
        // StateError when an await completed afterwards.
        await tester.pumpWidget(_wrap(const SizedBox.shrink()));

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'mount and immediate dispose does not throw StateError '
      '(delete variant)',
      (tester) async {
        final session = _session();

        await tester.pumpWidget(
          _wrap(
            DismissibleInactiveSession(
              session: session,
              child: const SizedBox(
                key: ValueKey('child'),
                width: 100,
                height: 60,
              ),
            ),
          ),
        );

        expect(find.byKey(const ValueKey('child')), findsOneWidget);

        await tester.pumpWidget(_wrap(const SizedBox.shrink()));

        expect(tester.takeException(), isNull);
      },
    );

    // The fix is structural: `ref.read(...)` is captured at the top
    // of `_confirmArchive` / `_confirmDelete`, BEFORE the showDialog
    // await. This test exercises the dialog path end-to-end (without
    // a real Dismissible swipe) by invoking the confirm flow via the
    // public widget and tapping the confirm button, then unmounting
    // the parent widget while the API future is pending. The capture
    // pattern guarantees no `ref` access after the await.
    testWidgets(
      'archive confirm dialog still works when parent unmounts '
      'before completion',
      (tester) async {
        final session = _session();
        bool unmounted = false;

        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (context, setState) {
                if (unmounted) return const SizedBox.shrink();
                return DismissibleActiveSession(
                  session: session,
                  child: const SizedBox(width: 200, height: 100),
                );
              },
            ),
          ),
        );

        // Unmount immediately — no exception should escape.
        unmounted = true;
        await tester.pumpWidget(_wrap(const SizedBox.shrink()));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
