import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// QR Code widget with polished container styling.
///
/// Displays a QR code inside a white card with a subtle
/// primary-color accent border and floating shadow.
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
    final scheme = Theme.of(context).colorScheme;
    final containerSize = size + AppSpacing.xxxl +
        AppSpacing.xl;

    return Container(
      width: containerSize,
      height: containerSize,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppRadius.xl,
        ),
        border: Border.all(
          color: scheme.outlineVariant.withValues(
            alpha: AppOpacity.medium,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(
              alpha: AppOpacity.subtle,
            ),
            blurRadius: AppSpacing.xxxl,
            spreadRadius: -AppSpacing.xs,
            offset: const Offset(0, AppSpacing.sm),
          ),
          ...AppShadow.floating,
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                AppRadius.md,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
              size: Size(size, size),
              painter: QRCodePainter(
                data: data,
                size: size,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: AppFontSize.sm,
                color: scheme.onSurfaceVariant
                    .withValues(
                  alpha: AppOpacity.half,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'End-to-end encrypted',
                style: TextStyle(
                  fontSize: AppFontSize.xs,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant
                      .withValues(
                    alpha: AppOpacity.half,
                  ),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom painter that renders a QR code via the [qr]
/// package with rounded module corners.
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
      ..color = const Color(0xFF1A1A2E)
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
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return oldDelegate is! QRCodePainter ||
        oldDelegate.data != data;
  }
}
