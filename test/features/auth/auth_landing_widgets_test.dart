import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/features/auth/widgets/auth_landing_widgets.dart';
import 'package:happy_flutter/features/auth/widgets/qr_code_display.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── AnimatedGradientBackground ───────────────────────────

  group('AnimatedGradientBackground', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AnimatedGradientBackground(
            child: Text('Child Content'),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Child Content'), findsOneWidget);
    });

    testWidgets('disposes animation controller', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AnimatedGradientBackground(
            child: Text('Test'),
          ),
        ),
      );

      await tester.pump();

      // Remove widget to trigger dispose
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates:
              AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SizedBox()),
        ),
      );

      await tester.pump();
      // No assertion needed; just verifying dispose does not throw
    });
  });

  // ─── AuthHeader ───────────────────────────────────────────

  group('AuthHeader', () {
    testWidgets('renders logo icon', (tester) async {
      await tester.pumpWidget(
        _wrap(AuthHeader(theme: ThemeData())),
      );

      await tester.pump();

      expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
    });

    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(
        _wrap(AuthHeader(theme: ThemeData())),
      );

      await tester.pump();

      // Title uses context.l10n.appTitle
      expect(find.text('Happy'), findsOneWidget);
    });

    testWidgets('renders subtitle text', (tester) async {
      await tester.pumpWidget(
        _wrap(AuthHeader(theme: ThemeData())),
      );

      await tester.pump();

      expect(
        find.text(
          'Mobile client for Claude Code & Codex',
        ),
        findsOneWidget,
      );
    });
  });

  // ─── LandingLogoMark ──────────────────────────────────────

  group('LandingLogoMark', () {
    testWidgets('renders logo icon', (tester) async {
      await tester.pumpWidget(
        _wrap(const LandingLogoMark()),
      );

      await tester.pump();

      expect(
        find.byIcon(Icons.chat_bubble_rounded),
        findsOneWidget,
      );
    });
  });

  // ─── StatusBanner ─────────────────────────────────────────

  group('StatusBanner', () {
    testWidgets('renders message text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          StatusBanner(
            message: 'Test message',
            color: Colors.red,
            isLoading: false,
            onDismiss: null,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoading',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          StatusBanner(
            message: 'Loading...',
            color: Colors.blue,
            isLoading: true,
            onDismiss: null,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
      );
    });

    testWidgets('shows icon when not loading and icon provided',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          StatusBanner(
            message: 'With icon',
            color: Colors.green,
            isLoading: false,
            onDismiss: () {},
            icon: Icons.check,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows dismiss button when onDismiss provided',
        (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        _wrap(
          StatusBanner(
            message: 'Dismissible',
            color: Colors.orange,
            isLoading: false,
            onDismiss: () => dismissed = true,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(dismissed, isTrue);
    });

    testWidgets('no dismiss button when onDismiss is null',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          StatusBanner(
            message: 'Not dismissible',
            color: Colors.red,
            isLoading: false,
            onDismiss: null,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('shows Error label for error-colored banners',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          StatusBanner(
            message: 'Something failed',
            color: Colors.red,
            isLoading: false,
            onDismiss: null,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('does not show Error label for non-error banners',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          StatusBanner(
            message: 'Success message',
            color: Colors.blue,
            isLoading: false,
            onDismiss: null,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Error'), findsNothing);
    });
  });

  // ─── QRInstructions ───────────────────────────────────────

  group('QRInstructions', () {
    testWidgets('renders instruction title', (tester) async {
      await tester.pumpWidget(
        _wrap(QRInstructions(theme: ThemeData())),
      );

      await tester.pump();

      expect(
        find.text('How to link your account'),
        findsOneWidget,
      );
    });

    testWidgets('renders all 4 step numbers', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: QRInstructions(theme: ThemeData()),
          ),
        ),
      );

      await tester.pump();

      for (var i = 1; i <= 4; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
    });

    testWidgets('renders step text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: QRInstructions(theme: ThemeData()),
          ),
        ),
      );

      await tester.pump();

      expect(
        find.text('Open Happy on another device'),
        findsOneWidget,
      );
      expect(find.text('Scan this QR code'), findsOneWidget);
    });
  });

  // ─── PollingView ──────────────────────────────────────────

  group('PollingView', () {
    testWidgets('shows waiting indicator when polling',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          PollingView(
            isPolling: true,
            hasError: false,
            onTryAgain: () {},
            onBack: () {},
            theme: ThemeData(),
          ),
        ),
      );

      await tester.pump();

      expect(
        find.text('Waiting for approval...'),
        findsOneWidget,
      );
    });

    testWidgets('hides waiting indicator when not polling',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          PollingView(
            isPolling: false,
            hasError: false,
            onTryAgain: () {},
            onBack: () {},
            theme: ThemeData(),
          ),
        ),
      );

      await tester.pump();

      expect(
        find.text('Waiting for approval...'),
        findsNothing,
      );
    });

    testWidgets('renders Try Again button', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PollingView(
            isPolling: false,
            hasError: false,
            onTryAgain: () {},
            onBack: () {},
            theme: ThemeData(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('renders Back button', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PollingView(
            isPolling: false,
            hasError: false,
            onTryAgain: () {},
            onBack: () {},
            theme: ThemeData(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('calls onTryAgain when Try Again is tapped',
        (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          PollingView(
            isPolling: false,
            hasError: false,
            onTryAgain: () => retried = true,
            onBack: () {},
            theme: ThemeData(),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('calls onBack when Back is tapped', (tester) async {
      var wentBack = false;
      await tester.pumpWidget(
        _wrap(
          PollingView(
            isPolling: false,
            hasError: false,
            onTryAgain: () {},
            onBack: () => wentBack = true,
            theme: ThemeData(),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Back'));
      await tester.pump();

      expect(wentBack, isTrue);
    });
  });

  // ─── QRCodeSection ────────────────────────────────────────

  group('QRCodeSection', () {
    testWidgets('shows loading placeholder when polling without key',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          QRCodeSection(
            isPolling: true,
            publicKey: null,
            error: null,
            onDismissError: () {},
            theme: ThemeData(),
          ),
        ),
      );

      await tester.pump();

      expect(
        find.text('Generating secure QR code\u2026'),
        findsOneWidget,
      );
    });

    testWidgets('shows nothing when not polling', (tester) async {
      await tester.pumpWidget(
        _wrap(
          QRCodeSection(
            isPolling: false,
            publicKey: null,
            error: null,
            onDismissError: () {},
            theme: ThemeData(),
          ),
        ),
      );

      await tester.pump();

      expect(
        find.text('Generating secure QR code\u2026'),
        findsNothing,
      );
    });

    testWidgets('shows error banner when error is present',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          QRCodeSection(
            isPolling: false,
            publicKey: null,
            error: 'Connection failed',
            onDismissError: () {},
            theme: ThemeData(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Connection failed'), findsOneWidget);
    });

    testWidgets('shows QR code when polling with public key',
        (tester) async {
      // Suppress overflow errors from QRCodeDisplay's internal
      // fixed-size Container.
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        origOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = origOnError);

      final publicKey = Uint8List.fromList(
        List.generate(32, (i) => i),
      );

      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: Center(
              child: QRCodeSection(
                isPolling: true,
                publicKey: publicKey,
                error: null,
                onDismissError: () {},
                theme: ThemeData(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(QRCodeDisplay), findsOneWidget);
    });
  });

  // ─── AuthButtonGroup ──────────────────────────────────────

  group('AuthButtonGroup', () {
    testWidgets('renders create account button', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AuthButtonGroup(
            onCreateAccount: () {},
            onLinkAccount: () {},
            onRestoreKey: () {},
            isLoadingCreate: false,
            l10n: _FakeL10n(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('renders link account button', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AuthButtonGroup(
            onCreateAccount: () {},
            onLinkAccount: () {},
            onRestoreKey: () {},
            isLoadingCreate: false,
            l10n: _FakeL10n(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Link Account'), findsOneWidget);
    });

    testWidgets('renders restore key button', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AuthButtonGroup(
            onCreateAccount: () {},
            onLinkAccount: () {},
            onRestoreKey: () {},
            isLoadingCreate: false,
            l10n: _FakeL10n(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Restore Key'), findsOneWidget);
    });

    testWidgets('create account button shows loading when creating',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AuthButtonGroup(
            onCreateAccount: () {},
            onLinkAccount: () {},
            onRestoreKey: () {},
            isLoadingCreate: true,
            l10n: _FakeL10n(),
          ),
        ),
      );

      await tester.pump();

      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
      );
    });
  });
}

/// Minimal fake AppLocalizations for widget tests that accept
/// [AppLocalizations] directly (no BuildContext needed).
class _FakeL10n extends AppLocalizations {
  _FakeL10n() : super('en');

  @override
  String get welcomeCreateAccount => 'Create Account';

  @override
  String get welcomeLinkOrRestoreAccount => 'Link Account';

  @override
  String get authSignInWithSecretKey => 'Restore Key';

  @override
  dynamic noSuchMethod(Invocation invocation) => '';
}
