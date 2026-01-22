import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr/qr.dart';
import '../../core/api/api_client.dart';
import '../../core/models/auth.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/server_config.dart';

/// Custom round button widget similar to happy project's RoundButton
class RoundButton extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final double height;

  const RoundButton({
    super.key,
    required this.title,
    this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? theme.colorScheme.primary
              : Colors.transparent,
          foregroundColor: isPrimary
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
          elevation: isPrimary ? 0 : 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isPrimary
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.primary,
                ),
              )
            : Text(
                title,
                style: TextStyle(
                  fontSize: isPrimary ? 18 : 16,
                  fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
      ),
    );
  }
}

/// QR Code widget using the qr package
class QRCodeDisplay extends StatelessWidget {
  final String data;
  final double size;

  const QRCodeDisplay({super.key, required this.data, this.size = 250});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: QRCodePainter(data: data),
      ),
    );
  }
}

class QRCodePainter extends CustomPainter {
  final String data;
  final int modules;
  final double size;

  QRCodePainter({required this.data, this.modules = 21, this.size = 250});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final double cellSize = size.width / modules;
    final int hash = data.hashCode.abs();

    // Draw position detection patterns (corners)
    _drawPositionPattern(canvas, paint, 0, 0, cellSize);
    _drawPositionPattern(canvas, paint, size.width - 7 * cellSize, 0, cellSize);
    _drawPositionPattern(
      canvas,
      paint,
      0,
      size.height - 7 * cellSize,
      cellSize,
    );

    // Draw timing patterns
    for (int i = 8; i < modules - 1; i++) {
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

    // Draw data modules based on hash for consistent pattern
    final random = Random(hash);
    for (int row = 8; row < modules - 8; row++) {
      for (int col = 8; col < modules - 8; col++) {
        if (random.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
    }
  }

  void _drawPositionPattern(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double cellSize,
  ) {
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
      Rect.fromLTWH(
        x + 2 * cellSize,
        y + 2 * cellSize,
        3 * cellSize,
        3 * cellSize,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Authentication screen with landing page pattern
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLoadingCreateAccount = false;
  bool _showQRScreen = false;
  Uint8List? _publicKey;
  bool _isPolling = false;
  String? _error;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _checkServerError();
  }

  Future<void> _checkServerError() async {
    final error = await getLastServerUrlError();
    if (mounted && error != null) {
      setState(() {
        _serverError = error;
      });
    }
  }

  Future<void> _createAccount() async {
    setState(() {
      _isLoadingCreateAccount = true;
      _error = null;
    });

    try {
      await AuthService().createAccount();
      if (mounted) {
        ref.read(authStateNotifierProvider.notifier).checkAuth();
      }
    } catch (e) {
      setState(() {
        _error = _formatErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCreateAccount = false;
        });
      }
    }
  }

  void _showQRAuth() async {
    setState(() {
      _showQRScreen = true;
      _error = null;
      _serverError = null;
    });
    await _startQRAuth();
  }

  void _goBack() {
    setState(() {
      _showQRScreen = false;
      _publicKey = null;
      _isPolling = false;
      _error = null;
    });
  }

  Future<void> _startQRAuth() async {
    setState(() {
      _isPolling = true;
    });

    try {
      final publicKey = await AuthService().startQRAuth();
      setState(() {
        _publicKey = publicKey;
      });

      // Start polling for approval
      _pollForApproval(publicKey);
    } catch (e) {
      setState(() {
        _error = _formatErrorMessage(e);
        _isPolling = false;
      });
    }
  }

  String _formatErrorMessage(dynamic e) {
    if (e is AuthForbiddenError) {
      return 'Access Denied (403)\n${e.message}';
    } else if (e is AuthRequestError) {
      return 'Client Error (${e.statusCode ?? 400})\n${e.message}';
    } else if (e is ServerError) {
      return 'Server Error (${e.statusCode ?? 500})\n${e.message}';
    } else if (e is SSLError) {
      return 'Certificate Error\n${e.message}';
    } else if (e is AuthException) {
      return e.message;
    }
    return 'Authentication failed: $e';
  }

  Future<void> _pollForApproval(Uint8List publicKey) async {
    try {
      await AuthService().waitForAuthApproval(publicKey);

      if (mounted) {
        ref.read(authStateNotifierProvider.notifier).checkAuth();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _formatErrorMessage(e);
          _isPolling = false;
        });
      }
    }
  }

  void _showServerDialog(BuildContext context) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? errorText;
    String? detailedError;
    String? errorType;
    bool isVerifying = false;

    getServerUrl().then((currentUrl) {
      controller.text = currentUrl;

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 300),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.3),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            ),
          );
        },
        pageBuilder: (context, animation, secondaryAnimation) {
          return StatefulBuilder(
            builder: (context, setDialogState) => Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.dns_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Server URL',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // URL Input
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: controller,
                              decoration: InputDecoration(
                                labelText: 'Server URL',
                                hintText: defaultServerUrl,
                                prefixIcon: const Icon(Icons.link_outlined),
                                errorText: errorText,
                                suffixIcon: controller.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          controller.clear();
                                          setDialogState(() {});
                                        },
                                      )
                                    : null,
                              ),
                              keyboardType: TextInputType.url,
                              autofillHints: const [AutofillHints.url],
                              onChanged: (_) {
                                if (errorText != null || detailedError != null) {
                                  setDialogState(() {
                                    errorText = null;
                                    detailedError = null;
                                    errorType = null;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            // Error Details Section
                            if (detailedError != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: Colors.red[700],
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Connection Failed',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red[700],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (errorType != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red[100],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              errorType!,
                                              style: TextStyle(
                                                color: Colors.red[800],
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      detailedError!,
                                      style: TextStyle(
                                        color: Colors.red[800],
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () {
                                            Clipboard.setData(
                                              ClipboardData(text: detailedError!),
                                            );
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text('Error details copied'),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.content_copy,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Copy',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red[700],
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Actions
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        if (currentUrl != defaultServerUrl) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              await setServerUrl(null);
                              await ApiClient().refreshServerUrl();
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Server URL reset to default.'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            },
                            child: const Text('Reset to Default'),
                          ),
                        ],
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: isVerifying
                              ? null
                              : () async {
                                  final url = controller.text.trim();

                                  // Validate URL format
                                  final validation = validateServerUrl(url);
                                  if (!validation.valid) {
                                    setDialogState(() {
                                      errorText = validation.error;
                                      detailedError = null;
                                      errorType = null;
                                    });
                                    return;
                                  }

                                  setDialogState(() {
                                    errorText = null;
                                    detailedError = null;
                                    errorType = null;
                                    isVerifying = true;
                                  });

                                  // Verify server is reachable
                                  final result = await verifyServerUrl(url);

                                  setDialogState(() {
                                    isVerifying = false;
                                  });

                                  if (!result.isValid) {
                                    setDialogState(() {
                                      detailedError = result.errorMessage;
                                      errorType = result.errorType;
                                    });
                                    return;
                                  }

                                  // Save the URL
                                  await setServerUrl(url);
                                  await ApiClient().refreshServerUrl();

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Server URL saved and applied.'),
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                },
                          child: isVerifying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save & Verify'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (_showQRScreen) {
      return _buildQRScreen(context, isLandscape);
    }

    return _buildLandingScreen(context, isLandscape);
  }

  Widget _buildLandingScreen(BuildContext context, bool isLandscape) {
    final theme = Theme.of(context);
    final padding = MediaQuery.of(context).padding;

    if (isLandscape) {
      return _buildLandscapeLayout(context, theme, padding);
    }

    return _buildPortraitLayout(context, theme, padding);
  }

  Widget _buildPortraitLayout(
    BuildContext context,
    ThemeData theme,
    EdgeInsets padding,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Happy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Server Settings',
            onPressed: () => _showServerDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_serverError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Server Connection Error',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setState(() {
                              _serverError = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const Icon(Icons.android, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                Text(
                  'Happy',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Mobile client for Claude Code & Codex',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 280,
                  child: RoundButton(
                    title: 'Create Account',
                    onPressed: _createAccount,
                    isLoading: _isLoadingCreateAccount,
                    isPrimary: true,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 280,
                  child: RoundButton(
                    title: 'Link or Restore Account',
                    onPressed: _showQRAuth,
                    isPrimary: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    ThemeData theme,
    EdgeInsets padding,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Happy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Server Settings',
            onPressed: () => _showServerDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 48,
            right: 48,
            bottom: padding.bottom + 24,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.android, size: 80, color: Colors.blue),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_serverError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          border: Border.all(color: Colors.red[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Server Connection Error',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                setState(() {
                                  _serverError = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    Text(
                      'Happy',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Mobile client for Claude Code & Codex',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 280,
                      child: RoundButton(
                        title: 'Create Account',
                        onPressed: _createAccount,
                        isLoading: _isLoadingCreateAccount,
                        isPrimary: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 280,
                      child: RoundButton(
                        title: 'Link or Restore Account',
                        onPressed: _showQRAuth,
                        isPrimary: false,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQRScreen(BuildContext context, bool isLandscape) {
    final theme = Theme.of(context);
    final padding = MediaQuery.of(context).padding;

    if (isLandscape) {
      return _buildQRLandscapeLayout(context, theme, padding);
    }

    return _buildQRPortraitLayout(context, theme, padding);
  }

  Widget _buildQRPortraitLayout(
    BuildContext context,
    ThemeData theme,
    EdgeInsets padding,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Text(
                  '1. Open Happy on another device',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                Text(
                  '2. Go to Settings → Account',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                Text(
                  '3. Tap "Link New Device"',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                Text(
                  '4. Scan this QR code',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setState(() {
                              _error = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                if (_isPolling && _publicKey != null)
                  QRCodeDisplay(
                    data: _publicKey != null ? base64Encode(_publicKey!) : '',
                    size: 250,
                  )
                else if (_isPolling)
                  Container(
                    width: 250,
                    height: 250,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (_isPolling) ...[
                  const SizedBox(height: 24),
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
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: 280,
                  child: RoundButton(
                    title: 'Try Again',
                    onPressed: _startQRAuth,
                    isPrimary: false,
                    isLoading: _isPolling && _error != null,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 280,
                  child: RoundButton(
                    title: 'Back',
                    onPressed: _goBack,
                    isPrimary: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQRLandscapeLayout(
    BuildContext context,
    ThemeData theme,
    EdgeInsets padding,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 48,
            right: 48,
            bottom: padding.bottom + 24,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '1. Open Happy on another device',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      '2. Go to Settings → Account',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      '3. Tap "Link New Device"',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      '4. Scan this QR code',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          border: Border.all(color: Colors.red[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                setState(() {
                                  _error = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_isPolling && _publicKey != null)
                      QRCodeDisplay(
                        data: _publicKey != null ? base64Encode(_publicKey!) : '',
                        size: 250,
                      )
                    else if (_isPolling)
                      Container(
                        width: 250,
                        height: 250,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    if (_isPolling) ...[
                      const SizedBox(height: 24),
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
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 280,
                      child: RoundButton(
                        title: 'Try Again',
                        onPressed: _startQRAuth,
                        isPrimary: false,
                        isLoading: _isPolling && _error != null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 280,
                      child: RoundButton(
                        title: 'Back',
                        onPressed: _goBack,
                        isPrimary: false,
                      ),
                    ),
                  ],
                ),
              ),
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
