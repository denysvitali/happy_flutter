import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/storage_service.dart';
import 'package:happy_flutter/core/widgets/auth_gate.dart';
import 'package:happy_flutter/features/settings/link_device_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class _AuthenticatedNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState.authenticated;

  int generation = 0;

  @override
  int get authTransitionGeneration => generation;

  void switchAccount() {
    generation++;
  }

  void signOutForTest() {
    generation++;
    state = AuthState.unauthenticated;
  }
}

class _CountingStorage extends TestFlutterSecureStoragePlatform {
  _CountingStorage() : super(<String, String>{});
  int credentialReads = 0;
  Future<void>? readBarrier;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    if (key == 'auth_credentials') {
      credentialReads++;
      await readBarrier;
    }
    return super.read(key: key, options: options);
  }
}

class _ScannerPlatform extends MobileScannerPlatform {
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const SizedBox();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async =>
      const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.off,
        size: Size(100, 100),
      );
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final publicKey = List<int>.generate(32, (index) => index + 1);
  final encodedKey = base64UrlEncode(publicKey).replaceAll('=', '');
  final fingerprint = sha256.convert(publicKey).toString();
  late FlutterSecureStoragePlatform originalStorage;
  late MobileScannerPlatform originalScanner;
  late _CountingStorage storage;
  late ProviderContainer container;
  late GoRouter router;

  setUp(() async {
    originalStorage = FlutterSecureStoragePlatform.instance;
    originalScanner = MobileScannerPlatform.instance;
    storage = _CountingStorage();
    FlutterSecureStoragePlatform.instance = storage;
    MobileScannerPlatform.instance = _ScannerPlatform();
    await TokenStorage().removeCredentials();
    container = ProviderContainer(
      overrides: [
        authStateNotifierProvider.overrideWith(_AuthenticatedNotifier.new),
      ],
    );
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          name: 'sessions',
          builder: (context, state) => AuthGate(
            child: Scaffold(
              body: TextButton(
                onPressed: () => context.push('/link'),
                child: const Text('Open linking'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/link',
          builder: (context, state) =>
              const AuthGate(child: LinkDeviceScreen()),
        ),
      ],
    );
  });

  tearDown(() {
    router.dispose();
    container.dispose();
    FlutterSecureStoragePlatform.instance = originalStorage;
    MobileScannerPlatform.instance = originalScanner;
  });

  Future<void> openLinking(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open linking'));
    await tester.pumpAndSettle();
  }

  Future<void> submit(
    WidgetTester tester,
    String url, {
    required bool scan,
  }) async {
    if (scan) {
      tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
        BarcodeCapture(barcodes: [Barcode(rawValue: url)]),
      );
    } else {
      await tester.tap(find.text('Enter URL'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), url);
      await tester.tap(find.widgetWithText(FilledButton, 'Approve Linking'));
    }
    await tester.pumpAndSettle();
  }

  for (final scan in <bool>[true, false]) {
    for (final terminal in <bool>[true, false]) {
      testWidgets('link request requires fingerprint review '
          '(scan=$scan, terminal=$terminal)', (tester) async {
        await openLinking(tester);
        final prefix = terminal ? 'happy://terminal?' : 'happy:///account?';
        final url = '$prefix$encodedKey';
        await submit(tester, url, scan: scan);

        expect(container.read(pendingLinkRequestProvider)?.url, url);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.textContaining(fingerprint), findsOneWidget);
        expect(storage.credentialReads, 0);

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(container.read(pendingLinkRequestProvider), isNull);
        expect(storage.credentialReads, 0);
        expect(find.byType(AlertDialog), findsNothing);
      });
    }
  }

  testWidgets('only explicit confirmation dispatches approval', (tester) async {
    await openLinking(tester);
    await submit(tester, 'happy://terminal?$encodedKey', scan: true);
    expect(storage.credentialReads, 0);
    expect(find.textContaining(fingerprint), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Approve Linking'),
      ),
    );
    await tester.pumpAndSettle();

    // Empty test credentials stop approval before crypto or network work.
    expect(storage.credentialReads, 1);
  });

  testWidgets('queued confirmation uses the latest staged request', (
    tester,
  ) async {
    await openLinking(tester);
    final firstUrl = 'happy://terminal?$encodedKey';
    container.read(pendingLinkRequestProvider.notifier).stage(firstUrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      container
          .read(pendingLinkRequestProvider.notifier)
          .stage('happy:///account?$encodedKey');
    });
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('A device is asking'), findsOneWidget);
    expect(storage.credentialReads, 0);
  });

  testWidgets('replaced request cannot approve the old dialog', (tester) async {
    await openLinking(tester);
    await submit(tester, 'happy://terminal?$encodedKey', scan: true);
    container
        .read(pendingLinkRequestProvider.notifier)
        .stage('happy:///account?$encodedKey');
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Approve Linking'),
      ),
    );
    await tester.pumpAndSettle();

    expect(storage.credentialReads, 0);
    expect(
      container.read(pendingLinkRequestProvider)?.url,
      'happy:///account?$encodedKey',
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('A device is asking'), findsOneWidget);
  });

  testWidgets('cancelled old dialog presents its replacement', (tester) async {
    await openLinking(tester);
    await submit(tester, 'happy://terminal?$encodedKey', scan: true);
    container
        .read(pendingLinkRequestProvider.notifier)
        .stage('happy:///account?$encodedKey');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(storage.credentialReads, 0);
    expect(
      container.read(pendingLinkRequestProvider)?.url,
      'happy:///account?$encodedKey',
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('A device is asking'), findsOneWidget);
  });

  testWidgets('replacement during approval wait is presented', (tester) async {
    await openLinking(tester);
    await submit(tester, 'happy://terminal?$encodedKey', scan: true);
    final barrier = Completer<void>();
    storage.readBarrier = barrier.future;
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Approve Linking'),
      ),
    );
    await tester.pumpAndSettle();
    expect(storage.credentialReads, 1);

    container
        .read(pendingLinkRequestProvider.notifier)
        .stage('happy:///account?$encodedKey');
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    barrier.complete();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('A device is asking'), findsOneWidget);
    expect(
      container.read(pendingLinkRequestProvider)?.url,
      'happy:///account?$encodedKey',
    );
  });

  testWidgets('account switch cannot approve an open dialog', (tester) async {
    await openLinking(tester);
    await submit(tester, 'happy://terminal?$encodedKey', scan: true);
    final auth =
        container.read(authStateNotifierProvider.notifier)
            as _AuthenticatedNotifier;
    auth.switchAccount();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Approve Linking'),
      ),
    );
    await tester.pumpAndSettle();

    expect(storage.credentialReads, 0);
    expect(container.read(pendingLinkRequestProvider), isNull);
  });

  testWidgets('logout cannot approve an open dialog', (tester) async {
    await openLinking(tester);
    await submit(tester, 'happy://terminal?$encodedKey', scan: true);
    final auth =
        container.read(authStateNotifierProvider.notifier)
            as _AuthenticatedNotifier;
    auth.signOutForTest();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Approve Linking'),
      ),
    );
    // The signed-out landing screen has repeating decorative animations.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(storage.credentialReads, 0);
    expect(container.read(pendingLinkRequestProvider), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cleared request cannot approve the old dialog', (tester) async {
    await openLinking(tester);
    await submit(tester, 'happy://terminal?$encodedKey', scan: true);
    container.read(pendingLinkRequestProvider.notifier).clear();
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Approve Linking'),
      ),
    );
    await tester.pumpAndSettle();

    expect(storage.credentialReads, 0);
    expect(container.read(pendingLinkRequestProvider), isNull);
  });

  testWidgets('invalid typed URLs do not stage a request', (tester) async {
    await openLinking(tester);
    await submit(tester, 'happy://terminal?invalid', scan: false);

    expect(container.read(pendingLinkRequestProvider), isNull);
    expect(storage.credentialReads, 0);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(LinkDeviceScreen), findsOneWidget);
  });
}
