import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr/qr.dart';

import '../../core/api/api_client.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/auth.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/server_config.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/backup_key_utils.dart';

// ---------------------------------------------------------------------------
// RoundButton
// ---------------------------------------------------------------------------

/// Custom round button widget similar to happy project's RoundButton
class RoundButton extends StatelessWidget {
  const RoundButton({
    required this.title,
    super.key,
    this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.height = 52.0,
  });

  final String title;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final double height;

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
          elevation: 0,
          shadowColor: Colors.transparent,
          side: isPrimary
              ? null
              : BorderSide(
                  color: theme.colorScheme.outline,
                ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
        child: isLoading
            ? AppLoadingIndicator(
                size: 20,
                strokeWidth: 2,
                color: isPrimary
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
              )
            : Text(
                title,
                style: TextStyle(
                  fontSize: isPrimary ? 18 : 16,
                  fontWeight:
                      isPrimary ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QRCodeDisplay + QRCodePainter
// ---------------------------------------------------------------------------

/// QR Code widget using the qr package
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
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.20),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: QRCodePainter(data: data, size: size),
      ),
    );
  }
}

/// Custom painter that renders a QR code via the [qr] package.
class QRCodePainter extends CustomPainter {
  QRCodePainter({required this.data, required this.size});

  final String data;
  final double size;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final qrCode = QrCode(8, QrErrorCorrectLevel.L)..addData(data);
    final qrImage = QrImage(qrCode);

    final moduleCount = qrImage.moduleCount;
    final cellSize = size.width / moduleCount;

    for (var row = 0; row < moduleCount; row++) {
      for (var col = 0; col < moduleCount; col++) {
        if (qrImage.isDark(row, col)) {
          canvas.drawRect(
            Rect.fromLTWH(
              col * cellSize,
              row * cellSize,
              cellSize,
              cellSize,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! QRCodePainter || oldDelegate.data != data;
  }
}

// ---------------------------------------------------------------------------
// AuthScreen (public)
// ---------------------------------------------------------------------------

/// Authentication screen with landing page pattern
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.initialDeepLink,
    this.showError = false,
  });

  final String? initialDeepLink;

  /// When [true], a banner is shown saying authentication failed and the
  /// user should sign in again. Used when [AuthState.error] redirects here.
  final bool showError;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  // fade-in animation
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  bool _isLoadingCreateAccount = false;
  bool _showQRScreen = false;
  Uint8List? _publicKey;
  bool _isPolling = false;
  String? _error;
  String? _serverError;
  bool _isProcessingLink = false;
  String? _linkSuccessMessage;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: AppDuration.slow,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: AppCurve.enter,
    );
    _fadeController.forward();

    _checkServerError();
    if (widget.initialDeepLink != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleIncomingLink(widget.initialDeepLink!);
      });
    }

    // Show error banner if redirected due to AuthState.error
    if (widget.showError) {
      _error = 'Something went wrong. Please sign in again.';
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ── deep-link handling ────────────────────────────────────────────────────

  Future<void> _handleIncomingLink(String url) async {
    setState(() {
      _isProcessingLink = true;
      _error = null;
    });

    try {
      final publicKey = AuthService.parseAuthUrl(url);
      if (publicKey == null) {
        setState(() {
          _error = 'Invalid QR code';
          _isProcessingLink = false;
        });
        return;
      }

      final credentials = await TokenStorage().getCredentials();
      if (credentials == null) {
        setState(() {
          _error = 'Please sign in first to approve device linking';
          _isProcessingLink = false;
        });
        return;
      }

      final success = await AuthService().approveLinkingRequest(url);

      if (success) {
        setState(() {
          _linkSuccessMessage = 'Device linked successfully!';
          _isProcessingLink = false;
        });
      } else {
        setState(() {
          _error = 'Failed to link device';
          _isProcessingLink = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error linking device: $e';
        _isProcessingLink = false;
      });
    }
  }

  Future<void> _checkServerError() async {
    final error = getLastServerUrlError();
    if (mounted && error != null) {
      setState(() {
        _serverError = error;
      });
    }
  }

  // ── account actions ───────────────────────────────────────────────────────

  Future<void> _createAccount() async {
    setState(() {
      _isLoadingCreateAccount = true;
      _error = null;
    });

    try {
      debugPrint('Creating account...');
      await AuthService().createAccount();
      debugPrint('Account created successfully');
      if (mounted) {
        unawaited(
          ref.read(authStateNotifierProvider.notifier).checkAuth(),
        );
      }
    } catch (e) {
      debugPrint('Create account error: $e');
      if (e is Error) {
        debugPrint('Stack trace: ${e.stackTrace}');
      }
      setState(() {
        _error = _formatErrorMessage(e, context);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCreateAccount = false;
        });
      }
    }
  }

  Future<void> _showSecretKeyDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _RestoreKeyDialog(
        onRestore: (normalized) async {
          await AuthService().restoreAccount(normalized);
          if (!mounted) return;
          Navigator.of(context).pop();
          unawaited(
            ref.read(authStateNotifierProvider.notifier).checkAuth(),
          );
        },
        formatError: (e) => _formatErrorMessage(e, context),
      ),
    );
  }

  void _showQRAuth() {
    setState(() {
      _showQRScreen = true;
      _error = null;
      _serverError = null;
    });
    unawaited(_startQRAuth());
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
      unawaited(_pollForApproval(publicKey));
    } catch (e) {
      setState(() {
        _error = _formatErrorMessage(e, context);
        _isPolling = false;
      });
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  String _formatErrorMessage(dynamic e, BuildContext ctx) {
    final l10n = ctx.l10n;
    if (e is AuthForbiddenError) {
      return '${l10n.authAccessDenied}\n${e.message}';
    } else if (e is AuthRequestError) {
      final statusCode = e.statusCode ?? 400;
      return '${l10n.authClientError} ($statusCode)\n${e.message}';
    } else if (e is ServerError) {
      final statusCode = e.statusCode ?? 500;
      return '${l10n.authServerError} ($statusCode)\n${e.message}';
    } else if (e is SSLError) {
      return '${l10n.authCertificateError}\n${e.message}';
    } else if (e is AuthException) {
      return e.message;
    }
    return '${l10n.authAuthenticationFailed}: $e';
  }

  Future<void> _pollForApproval(Uint8List publicKey) async {
    try {
      await AuthService().waitForAuthApproval(publicKey);
      if (mounted) {
        unawaited(
          ref.read(authStateNotifierProvider.notifier).checkAuth(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _formatErrorMessage(e, context);
          _isPolling = false;
        });
      }
    }
  }

  void _showServerDialog(BuildContext ctx) {
    showGeneralDialog<void>(
      context: ctx,
      barrierDismissible: true,
      barrierLabel:
          MaterialLocalizations.of(ctx).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx2, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx2, animation, secondaryAnimation) {
        return _ServerUrlDialog(
          initialUrl: getServerUrl(),
          defaultUrl: defaultServerUrl,
        );
      },
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (_showQRScreen) {
      return _buildQRScreen(context, isLandscape);
    }

    return _buildLandingScreen(context, isLandscape);
  }

  // ── landing screen ────────────────────────────────────────────────────────

  Widget _buildLandingScreen(
    BuildContext context,
    bool isLandscape,
  ) {
    final theme = Theme.of(context);
    final padding = MediaQuery.of(context).padding;

    final appBar = AppBar(
      title: Text(context.l10n.appTitle),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: context.l10n.authServerSettings,
          onPressed: () => _showServerDialog(context),
        ),
      ],
    );

    final notices = _buildNotices(context);
    final header = _AuthHeader(theme: theme);
    final buttons = _AuthButtonGroup(
      onCreateAccount: _createAccount,
      onLinkAccount: _showQRAuth,
      onRestoreKey: _showSecretKeyDialog,
      isLoadingCreate: _isLoadingCreateAccount,
      l10n: context.l10n,
    );

    Widget body;
    if (isLandscape) {
      body = SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xxxl + AppSpacing.lg,
            right: AppSpacing.xxxl + AppSpacing.lg,
            bottom: padding.bottom + AppSpacing.xxl,
          ),
          child: Row(
            children: [
              const Expanded(child: Center(child: _LandingLogoMark())),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...notices,
                    header,
                    const SizedBox(height: AppSpacing.xxxl),
                    SizedBox(width: 280, child: buttons),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      body = SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                ...notices,
                header,
                const SizedBox(height: AppSpacing.xxxl + AppSpacing.lg),
                SizedBox(width: 280, child: buttons),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _AnimatedGradientBackground(child: body),
      ),
    );
  }

  List<Widget> _buildNotices(BuildContext context) {
    final notices = <Widget>[];

    if (_isProcessingLink) {
      notices.add(
        _StatusBanner(
          icon: null,
          message: 'Processing device link...',
          color: Theme.of(context).colorScheme.primary,
          isLoading: true,
          onDismiss: null,
        ),
      );
    }

    if (_linkSuccessMessage != null) {
      notices.add(
        _StatusBanner(
          icon: Icons.check_circle,
          message: _linkSuccessMessage!,
          color: Colors.green,
          isLoading: false,
          onDismiss: () => setState(() => _linkSuccessMessage = null),
        ),
      );
    }

    if (_serverError != null) {
      notices.add(
        _StatusBanner(
          icon: Icons.warning,
          message: context.l10n.authServerConnectionError,
          color: Colors.red,
          isLoading: false,
          onDismiss: () => setState(() => _serverError = null),
        ),
      );
    }

    if (_error != null) {
      notices.add(
        _StatusBanner(
          icon: Icons.error_outline,
          message: _error!,
          color: Colors.red,
          isLoading: false,
          onDismiss: () => setState(() => _error = null),
        ),
      );
    }

    return notices;
  }

  // ── QR screen ─────────────────────────────────────────────────────────────

  Widget _buildQRScreen(BuildContext context, bool isLandscape) {
    final theme = Theme.of(context);
    final padding = MediaQuery.of(context).padding;

    final appBar = AppBar(
      title: const Text('Link Account'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _goBack,
      ),
    );

    final instructions = _QRInstructions(theme: theme);

    final qrSection = _QRCodeSection(
      isPolling: _isPolling,
      publicKey: _publicKey,
      error: _error,
      onDismissError: () => setState(() => _error = null),
      theme: theme,
    );

    final actions = _PollingView(
      isPolling: _isPolling,
      hasError: _error != null,
      onTryAgain: _startQRAuth,
      onBack: _goBack,
      theme: theme,
    );

    if (isLandscape) {
      return Scaffold(
        appBar: appBar,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.xxxl + AppSpacing.lg,
              right: AppSpacing.xxxl + AppSpacing.lg,
              bottom: padding.bottom + AppSpacing.xxl,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [instructions],
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      qrSection,
                      const SizedBox(height: AppSpacing.xxl),
                      SizedBox(width: 280, child: actions),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: AppSpacing.lg),
                instructions,
                const SizedBox(height: AppSpacing.xxxl),
                qrSection,
                const SizedBox(height: AppSpacing.xxl),
                SizedBox(width: 280, child: actions),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private extracted widgets
// ---------------------------------------------------------------------------

// ── _AnimatedGradientBackground ───────────────────────────────────────────

/// Wraps [child] in a very subtly animated two-hue gradient that shifts
/// slowly to add depth to the landing screen.
class _AnimatedGradientBackground extends StatefulWidget {
  const _AnimatedGradientBackground({required this.child});

  final Widget child;

  @override
  State<_AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState
    extends State<_AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surface;
    // Two nearly identical hues: base surface vs. a very faint primary tint.
    final hintA = Color.lerp(base, scheme.primary, 0.03)!;
    final hintB = Color.lerp(base, scheme.primary, 0.07)!;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) {
        final t = (math.sin(_ctrl.value * math.pi) + 1) / 2;
        final topColor = Color.lerp(hintA, hintB, t)!;
        final bottomColor = Color.lerp(hintB, hintA, t)!;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [topColor, bottomColor],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ── _AuthHeader ───────────────────────────────────────────────────────────

/// Logo + title + subtitle block shown on the landing screen.
class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary,
                Color.lerp(
                  theme.colorScheme.primary,
                  theme.colorScheme.tertiary,
                  0.4,
                )!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.30),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.android,
            size: 48,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          context.l10n.appTitle,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.l10n.appSubtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── _LandingLogoMark ──────────────────────────────────────────────────────

/// Icon-only logo mark used in landscape left panel.
class _LandingLogoMark extends StatelessWidget {
  const _LandingLogoMark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            Color.lerp(
              theme.colorScheme.primary,
              theme.colorScheme.tertiary,
              0.4,
            )!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.30),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        Icons.android,
        size: 56,
        color: theme.colorScheme.onPrimary,
      ),
    );
  }
}

// ── _AuthButtonGroup ──────────────────────────────────────────────────────

/// The three auth action buttons on the landing screen.
class _AuthButtonGroup extends StatelessWidget {
  const _AuthButtonGroup({
    required this.onCreateAccount,
    required this.onLinkAccount,
    required this.onRestoreKey,
    required this.isLoadingCreate,
    required this.l10n,
  });

  final VoidCallback onCreateAccount;
  final VoidCallback onLinkAccount;
  final VoidCallback onRestoreKey;
  final bool isLoadingCreate;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoundButton(
          title: l10n.welcomeCreateAccount,
          onPressed: onCreateAccount,
          isLoading: isLoadingCreate,
          isPrimary: true,
        ),
        const SizedBox(height: AppSpacing.md),
        RoundButton(
          title: l10n.welcomeLinkOrRestoreAccount,
          onPressed: onLinkAccount,
          isPrimary: false,
        ),
        const SizedBox(height: AppSpacing.sm),
        RoundButton(
          title: 'Sign In with Secret Key',
          onPressed: onRestoreKey,
          isPrimary: false,
        ),
      ],
    );
  }
}

// ── _StatusBanner ─────────────────────────────────────────────────────────

/// A coloured notice bar used for errors, warnings and success messages.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.color,
    required this.isLoading,
    required this.onDismiss,
    this.icon,
  });

  final IconData? icon;
  final String message;
  final Color color;
  final bool isLoading;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          if (isLoading)
            AppLoadingIndicator(size: 20, strokeWidth: 2, color: color)
          else if (icon != null)
            Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: color,
                fontSize: 13,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: color,
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
            ),
        ],
      ),
    );
  }
}

// ── _QRInstructions ───────────────────────────────────────────────────────

/// Numbered step list shown above / beside the QR code.
class _QRInstructions extends StatelessWidget {
  const _QRInstructions({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    const steps = [
      '1. Open Happy on another device',
      '2. Go to Settings → Account',
      '3. Tap "Link New Device"',
      '4. Scan this QR code',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: steps
          .map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                s,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          )
          .toList(),
    );
  }
}

// ── _QRCodeSection ────────────────────────────────────────────────────────

/// Shows the QR code or a loading placeholder, plus the error banner.
class _QRCodeSection extends StatelessWidget {
  const _QRCodeSection({
    required this.isPolling,
    required this.publicKey,
    required this.error,
    required this.onDismissError,
    required this.theme,
  });

  final bool isPolling;
  final Uint8List? publicKey;
  final String? error;
  final VoidCallback onDismissError;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (error != null)
          _StatusBanner(
            icon: Icons.warning,
            message: error!,
            color: Colors.red,
            isLoading: false,
            onDismiss: onDismissError,
          ),
        if (isPolling && publicKey != null)
          QRCodeDisplay(
            data: 'happy:///account?'
                '${base64Url.encode(publicKey!).replaceAll('=', '')}',
            size: 250,
          )
        else if (isPolling)
          Container(
            width: 250,
            height: 250,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const AppLoadingIndicator(),
          ),
      ],
    );
  }
}

// ── _PollingView ──────────────────────────────────────────────────────────

/// "Waiting for approval" indicator + Try Again / Back buttons.
class _PollingView extends StatelessWidget {
  const _PollingView({
    required this.isPolling,
    required this.hasError,
    required this.onTryAgain,
    required this.onBack,
    required this.theme,
  });

  final bool isPolling;
  final bool hasError;
  final VoidCallback onTryAgain;
  final VoidCallback onBack;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isPolling) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppLoadingIndicator(
                size: AppSpacing.lg,
                strokeWidth: 2,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Waiting for approval...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        RoundButton(
          title: 'Try Again',
          onPressed: onTryAgain,
          isPrimary: false,
          isLoading: isPolling && hasError,
        ),
        const SizedBox(height: AppSpacing.md),
        RoundButton(
          title: 'Back',
          onPressed: onBack,
          isPrimary: false,
        ),
      ],
    );
  }
}

// ── _RestoreKeyDialog ─────────────────────────────────────────────────────

/// Dialog for signing in with a backup / secret key.
class _RestoreKeyDialog extends StatefulWidget {
  const _RestoreKeyDialog({
    required this.onRestore,
    required this.formatError,
  });

  /// Called with the normalised key string; should throw on failure.
  final Future<void> Function(String normalized) onRestore;

  /// Formats a caught error object into a user-visible string.
  final String Function(dynamic) formatError;

  @override
  State<_RestoreKeyDialog> createState() => _RestoreKeyDialogState();
}

class _RestoreKeyDialogState extends State<_RestoreKeyDialog> {
  final _controller = TextEditingController();
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _normalize(String input) {
    final s = input.replaceAll(RegExp(r'\s+'), '');
    if (s.isEmpty) return null;
    if (BackupKeyUtils.isValidKey(s)) return s;

    final hex = s.startsWith('0x') ? s.substring(2) : s;
    if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hex)) {
      try {
        final bytes = <int>[];
        for (var i = 0; i < hex.length; i += 2) {
          bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
        }
        return BackupKeyUtils.encodeKey(Uint8List.fromList(bytes));
      } catch (_) {}
    }

    final b64 = s.replaceAll('-', '+').replaceAll('_', '/');
    final rem = b64.length % 4;
    final padded =
        rem == 0 ? b64 : b64.padRight(b64.length + (4 - rem), '=');
    try {
      final bytes = base64Decode(padded);
      if (bytes.length == 32) return BackupKeyUtils.encodeKey(bytes);
    } catch (_) {}
    return null;
  }

  Future<void> _submit() async {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() => _errorText = 'Please enter a secret key');
      return;
    }
    final normalized = _normalize(input);
    if (normalized == null) {
      setState(() {
        _errorText = 'Invalid key. Use backup key'
            ' (11 groups), base64, base64url,'
            ' or 64-char hex.';
      });
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });
    try {
      await widget.onRestore(normalized);
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = widget.formatError(e));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sign In with Secret Key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Enter backup key (11 groups like XXXXX-XXXXX...),'
            ' base64/base64url, or 64-char hex key.',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              labelText: 'Secret Key',
              hintText: 'Backup key / base64 / hex',
              errorText: _errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: const BorderSide(color: Colors.red),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: const BorderSide(
                  color: Colors.red,
                  width: 2,
                ),
              ),
            ),
            maxLines: 2,
            minLines: 1,
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  final clip =
                      await Clipboard.getData(Clipboard.kTextPlain);
                  final text = clip?.text?.trim();
                  if (text == null || text.isEmpty) return;
                  _controller.text = text;
                  setState(() => _errorText = null);
                },
          child: const Text('Paste'),
        ),
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const AppLoadingIndicator(
                  size: 16,
                  strokeWidth: 2,
                  color: Colors.white,
                )
              : const Text('Sign In'),
        ),
      ],
    );
  }
}

// ── _ServerUrlDialog ──────────────────────────────────────────────────────

/// Dialog for configuring the server URL.
class _ServerUrlDialog extends StatefulWidget {
  const _ServerUrlDialog({
    required this.initialUrl,
    required this.defaultUrl,
  });

  final String initialUrl;
  final String defaultUrl;

  @override
  State<_ServerUrlDialog> createState() => _ServerUrlDialogState();
}

class _ServerUrlDialogState extends State<_ServerUrlDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  String? _errorText;
  String? _detailedError;
  String? _errorType;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearErrors() {
    if (_errorText != null || _detailedError != null) {
      setState(() {
        _errorText = null;
        _detailedError = null;
        _errorType = null;
      });
    }
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    final validation = validateServerUrl(url);
    if (!validation.valid) {
      setState(() {
        _errorText = validation.error;
        _detailedError = null;
        _errorType = null;
      });
      return;
    }

    setState(() {
      _errorText = null;
      _detailedError = null;
      _errorType = null;
      _isVerifying = true;
    });

    final result = await verifyServerUrl(url);
    setState(() => _isVerifying = false);

    if (!result.isValid) {
      setState(() {
        _detailedError = result.errorMessage;
        _errorType = result.errorType;
      });
      return;
    }

    setServerUrl(url);
    unawaited(ApiClient().refreshServerUrl());

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server URL saved and applied.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDefault = widget.initialUrl == widget.defaultUrl;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: 40,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              0,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.dns_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.settingsServerUrl,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // URL input + error detail
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: l10n.settingsServerUrlLabel,
                        hintText: widget.defaultUrl,
                        prefixIcon: const Icon(Icons.link_outlined),
                        errorText: _errorText,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _controller.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.url,
                      autofillHints: const [AutofillHints.url],
                      onChanged: (_) {
                        _clearErrors();
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_detailedError != null) ...[
                      _ErrorDetailBox(
                        errorType: _errorType,
                        errorMessage: _detailedError!,
                        l10n: l10n,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Actions
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.commonCancel),
                ),
                if (!isDefault) ...[
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: () {
                      setServerUrl(null);
                      ApiClient().refreshServerUrl();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.settingsServerResetSuccess,
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    child: Text(l10n.settingsServerResetToDefault),
                  ),
                ],
                const SizedBox(width: AppSpacing.md),
                FilledButton(
                  onPressed: _isVerifying ? null : _save,
                  child: _isVerifying
                      ? const AppLoadingIndicator(
                          size: 16,
                          strokeWidth: 2,
                          color: Colors.white,
                        )
                      : Text(l10n.settingsServerSaveVerify),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _ErrorDetailBox ───────────────────────────────────────────────────────

/// Red error-detail panel used inside [_ServerUrlDialog].
class _ErrorDetailBox extends StatelessWidget {
  const _ErrorDetailBox({
    required this.errorMessage,
    required this.l10n,
    this.errorType,
  });

  final String? errorType;
  final String errorMessage;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.authConnectionFailed,
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
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(AppRadius.xs),
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
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            errorMessage,
            style: TextStyle(
              color: Colors.red[800],
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: errorMessage),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error details copied'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.content_copy, size: 16),
                label: Text(
                  l10n.commonCopy,
                  style: const TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AuthGate (public)
// ---------------------------------------------------------------------------

/// Authentication gate widget
class AuthGate extends ConsumerWidget {
  const AuthGate({
    required this.child,
    super.key,
    this.initialDeepLink,
  });

  final Widget child;
  final String? initialDeepLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateNotifierProvider);

    if (initialDeepLink != null &&
        authState == AuthState.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(authStateNotifierProvider.notifier)
            .handleDeepLink(initialDeepLink!);
      });
    }

    return switch (authState) {
      AuthState.authenticated => child,
      AuthState.unauthenticated =>
        AuthScreen(initialDeepLink: initialDeepLink),
      AuthState.authenticating => const Scaffold(
          body: AppLoadingIndicator(),
        ),
      AuthState.error =>
        AuthScreen(initialDeepLink: initialDeepLink, showError: true),
    };
  }
}
