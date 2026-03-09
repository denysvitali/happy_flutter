import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../../../core/theme/app_tokens.dart';

/// QR Code widget using the qr package.
class QRCodeDisplay extends StatelessWidget {
  const QRCodeDisplay({
    required this.data,
    super.key,
    this.size = 250,
  });

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
        boxShadow: AppShadow.floating,
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: QRCodePainter(data: data, size: size),
      ),
    );
  }
}

/// Custom painter that renders a QR code via the [qr]
/// package.
class QRCodePainter extends CustomPainter {
  QRCodePainter({
    required this.data,
    required this.size,
  });

  final String data;
  final double size;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    final qrCode = QrCode(8, QrErrorCorrectLevel.L)
      ..addData(data);
    final qrImage = QrImage(qrCode);

    final moduleCount = qrImage.moduleCount;
    final cellSize = size.width / moduleCount;
    final radius = cellSize * 0.3;

    for (var row = 0; row < moduleCount; row++) {
      for (var col = 0; col < moduleCount; col++) {
        if (qrImage.isDark(row, col)) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                col * cellSize,
                row * cellSize,
                cellSize,
                cellSize,
              ),
              Radius.circular(radius),
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! QRCodePainter ||
        oldDelegate.data != data;
  }
}
