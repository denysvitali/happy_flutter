import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/auth/auth_screen.dart';

/// A stub [AuthStateNotifier] that can be seeded with a specific [AuthState].
class _StubAuthNotifier extends AuthStateNotifier {
  _StubAuthNotifier(this._state);
  final AuthState _state;

  @override
  AuthState build() => _state;

  @override
  Future<void> checkAuth() async {
    // No-op in tests to avoid touching native platform code.
  }
}

/// A simple content widget used as the [AuthGate.child] in tests that
/// check the authenticated state.
class _MockContent extends StatelessWidget {
  const _MockContent();

  @override
  Widget build(BuildContext context) {
    return const Text('Authenticated Content');
  }
}

/// Wraps [widget] in the minimal [MaterialApp] + [ProviderScope] required
/// for [ConsumerWidget] tests.
Widget _buildApp(
  Widget widget, {
  AuthState authState = AuthState.unauthenticated,
}) {
  return ProviderScope(
    overrides: [
      authStateNotifierProvider.overrideWith(() =>
          _StubAuthNotifier(authState)),
    ],
    child: MaterialApp(
      home: widget,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthGate widget', () {
    testWidgets(
      'shows CircularProgressIndicator in authenticating state',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            const AuthGate(child: _MockContent()),
            authState: AuthState.authenticating,
          ),
        );

        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Authenticated Content'), findsNothing);
      },
    );

    testWidgets(
      'shows child content in authenticated state',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            const AuthGate(child: _MockContent()),
            authState: AuthState.authenticated,
          ),
        );

        await tester.pump();

        expect(find.text('Authenticated Content'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
  });

  group('AuthGate state transitions', () {
    testWidgets(
      'authenticating state does not show child',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            const AuthGate(child: _MockContent()),
            authState: AuthState.authenticating,
          ),
        );

        await tester.pump();

        expect(find.text('Authenticated Content'), findsNothing);
        expect(find.byType(Scaffold), findsWidgets);
      },
    );

    testWidgets(
      'authenticated state shows child immediately',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            const AuthGate(child: _MockContent()),
            authState: AuthState.authenticated,
          ),
        );

        await tester.pump();

        expect(find.text('Authenticated Content'), findsOneWidget);
      },
    );
  });
}
