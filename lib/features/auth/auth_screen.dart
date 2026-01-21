import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/auth.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/app_providers.dart';

/// Simple QR code data URL generator
class QRCodeGenerator {
  /// Generate a simple visual representation of QR code data
  /// In production, use a proper QR code library
  static String generateDataUrl(String data) {
    // Return a placeholder SVG data URL
    final encoded = Uri.encodeComponent(data);
    return 'data:text/plain;charset=utf-8,$encoded';
  }
}

/// Simple QR code widget
class SimpleQRCode extends StatelessWidget {
  final String data;
  final double size;

  const SimpleQRCode({
    super.key,
    required this.data,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: QRCodePainter(data: data),
    );
  }
}

class QRCodePainter extends CustomPainter {
  final String data;

  QRCodePainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Create a simple pattern based on the data hash
    final hash = data.hashCode.abs();
    final cellSize = size.width / 21; // Standard QR code has 21x21 modules

    // Draw the three position detection patterns (corners)
    _drawPositionPattern(canvas, paint, 0, 0, cellSize);
    _drawPositionPattern(canvas, paint, size.width - 7 * cellSize, 0, cellSize);
    _drawPositionPattern(canvas, paint, 0, size.height - 7 * cellSize, cellSize);

    // Draw data modules based on hash
    final random = Random(hash);
    for (int row = 8; row < 17; row++) {
      for (int col = 8; col < 17; col++) {
        if (random.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
    }

    // Draw timing patterns
    for (int i = 8; i < 21; i++) {
      if (i % 2 == 0) {
        canvas.drawRect(
          Rect.fromLTWH(i * cellSize, 6 * cellSize, cellSize, cellSize),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(6 * cellSize, i * cellSize, cellSize, cellSize),
          paint,
        );
      }
    }
  }

  void _drawPositionPattern(Canvas canvas, Paint paint, double x, double y, double cellSize) {
    // Outer 7x7 black square
    canvas.drawRect(Rect.fromLTWH(x, y, 7 * cellSize, 7 * cellSize), paint);

    // Inner 5x5 white square
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(x + cellSize, y + cellSize, 5 * cellSize, 5 * cellSize),
      whitePaint,
    );

    // Center 3x3 black square
    canvas.drawRect(
      Rect.fromLTWH(x + 2 * cellSize, y + 2 * cellSize, 3 * cellSize, 3 * cellSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Authentication screen with QR code display
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  Uint8List? _publicKey;
  bool _isLoading = true;
  bool _isPolling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startAuth();
  }

  Future<void> _startAuth() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final publicKey = await AuthService().startQRAuth();
      setState(() {
        _publicKey = publicKey;
        _isLoading = false;
        _isPolling = true;
      });

      // Start polling for approval
      _pollForApproval(publicKey);
    } catch (e) {
      setState(() {
        _error = 'Failed to start authentication: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _pollForApproval(Uint8List publicKey) async {
    try {
      await AuthService().waitForAuthApproval(publicKey);

      if (mounted) {
        // Update auth state
        ref.read(authStateNotifierProvider.notifier).checkAuth();

        // Navigate to main screen
        // Navigator.of(context).pushReplacementNamed('/sessions');
      }
    } catch (e) {
      if (mounted) {
        if (e is AuthError) {
          setState(() {
            _error = e.messageText;
            _isPolling = false;
          });
        } else {
          setState(() {
            _error = 'Authentication failed: $e';
            _isPolling = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.android,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Happy',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Mobile client for Claude Code & Codex',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_error != null)
                Column(
                  children: [
                    Icon(Icons.error, color: Colors.red[400], size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _startAuth,
                      child: const Text('Try Again'),
                    ),
                  ],
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SimpleQRCode(
                    data: _publicKey != null
                        ? base64Encode(_publicKey!)
                        : '',
                    size: 200,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Scan with your desktop app to sign in',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (_isPolling)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Waiting for approval...',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Authentication gate widget
class AuthGate extends ConsumerWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateNotifierProvider);

    return switch (authState) {
      AuthState.authenticated => child,
      AuthState.unauthenticated => const AuthScreen(),
      AuthState.authenticating => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthState.error => const AuthScreen(),
    };
  }
}
