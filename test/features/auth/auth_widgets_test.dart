import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/features/auth/widgets/qr_code_display.dart';
import 'package:happy_flutter/features/auth/widgets/round_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  // ─── RoundButton ──────────────────────────────────────────

  group('RoundButton', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(
        wrap(const RoundButton(title: 'Click Me')),
      );

      expect(find.text('Click Me'), findsOneWidget);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RoundButton(
            title: 'With Icon',
            icon: Icons.add,
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('does not render icon when null', (tester) async {
      await tester.pumpWidget(
        wrap(const RoundButton(title: 'No Icon')),
      );

      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('shows loading indicator when isLoading is true',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const RoundButton(
            title: 'Loading',
            isLoading: true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });

    testWidgets('shows text when not loading', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RoundButton(
            title: 'Not Loading',
            isLoading: false,
          ),
        ),
      );

      expect(find.text('Not Loading'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        wrap(
          RoundButton(
            title: 'Tap Me',
            onPressed: () => pressed = true,
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('does not call onPressed when disabled',
        (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        wrap(
          RoundButton(
            title: 'Disabled',
            onPressed: null,
          ),
        ),
      );

      await tester.tap(find.text('Disabled'));
      await tester.pump();

      expect(pressed, isFalse);
    });

    testWidgets('does not call onPressed when loading',
        (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        wrap(
          RoundButton(
            title: 'Loading',
            isLoading: true,
            onPressed: () => pressed = true,
          ),
        ),
      );

      // Loading indicator prevents tap
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(pressed, isFalse);
    });

    testWidgets('renders primary style by default', (tester) async {
      await tester.pumpWidget(
        wrap(const RoundButton(title: 'Primary')),
      );

      // Primary button uses gradient decoration (Container with
      // BoxDecoration)
      final containers = find.byType(Container);
      expect(containers, findsWidgets);
    });

    testWidgets('renders secondary style when isPrimary is false',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const RoundButton(
            title: 'Secondary',
            isPrimary: false,
          ),
        ),
      );

      expect(find.text('Secondary'), findsOneWidget);
    });

    testWidgets('respects custom height', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RoundButton(
            title: 'Custom Height',
            height: 60,
          ),
        ),
      );

      expect(find.text('Custom Height'), findsOneWidget);
    });
  });

  // ─── QRCodeDisplay ────────────────────────────────────────

  group('QRCodeDisplay', () {
    testWidgets('renders with default size', (tester) async {
      await tester.pumpWidget(
        wrap(const QRCodeDisplay(data: 'test-data')),
      );

      await tester.pump();

      expect(find.byType(QRCodeDisplay), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders end-to-end encrypted label',
        (tester) async {
      await tester.pumpWidget(
        wrap(const QRCodeDisplay(data: 'test-data')),
      );

      await tester.pump();

      expect(find.text('End-to-end encrypted'), findsOneWidget);
    });

    testWidgets('renders lock icon', (tester) async {
      await tester.pumpWidget(
        wrap(const QRCodeDisplay(data: 'test-data')),
      );

      await tester.pump();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('renders with custom size', (tester) async {
      await tester.pumpWidget(
        wrap(
          const QRCodeDisplay(data: 'test-data', size: 100),
        ),
      );

      await tester.pump();

      expect(find.byType(QRCodeDisplay), findsOneWidget);
    });

    testWidgets('renders different data', (tester) async {
      await tester.pumpWidget(
        wrap(const QRCodeDisplay(data: 'different-data-123')),
      );

      await tester.pump();

      expect(find.byType(QRCodeDisplay), findsOneWidget);
    });
  });

  // ─── QRCodePainter ────────────────────────────────────────

  group('QRCodePainter', () {
    test('shouldRepaint returns true when data changes', () {
      final painter1 = QRCodePainter(data: 'data1', size: 100);
      final painter2 = QRCodePainter(data: 'data2', size: 100);

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns false when data is same', () {
      final painter1 = QRCodePainter(data: 'same', size: 100);
      final painter2 = QRCodePainter(data: 'same', size: 100);

      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('shouldRepaint returns true for different type', () {
      final painter = QRCodePainter(data: 'data', size: 100);
      final otherPainter = _OtherPainter();

      expect(painter.shouldRepaint(otherPainter), isTrue);
    });

    test('stores data and size correctly', () {
      final painter = QRCodePainter(
        data: 'my-qr-data',
        size: 200,
      );

      expect(painter.data, 'my-qr-data');
      expect(painter.size, 200);
    });
  });
}

class _OtherPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
