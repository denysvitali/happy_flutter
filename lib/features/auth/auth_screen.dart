import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/auth.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/server_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../dev/dev_logs_screen.dart';
import 'widgets/auth_animated_widgets.dart';
import 'widgets/auth_landing_widgets.dart';
import 'widgets/restore_key_dialog.dart';
import 'widgets/server_url_dialog.dart';

/// Authentication screen with landing page pattern.
///
/// Uses [AnimatedSwitcher] for smooth transitions
/// between the landing page and QR linking views.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.initialDeepLinkFuture,
    this.showError = false,
  });

  /// Optional future for the initial deep link from the platform
  /// channel. Resolved in [_AuthScreenState.initState] and used to
  /// drive the device-linking flow when present. Passing a future
  /// (vs. a resolved value) lets the platform call run in parallel
  /// with first frame.
  final Future<String?>? initialDeepLinkFuture;

  /// When [true], a banner is shown saying
  /// authentication failed and the user should sign
  /// in again.
  final bool showError;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
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
  bool _didApplyShowError = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: AppDuration.slower,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: AppCurve.enter,
    );
    _fadeController.forward();

    _checkServerError();
    final initialDeepLinkFuture = widget.initialDeepLinkFuture;
    if (initialDeepLinkFuture != null) {
      // Resolve the platform-channel future in the background and
      // dispatch device-linking only if a deep link is actually
      // present.  We don't block the first frame on this — the
      // future was kicked off in parallel with `runApp`.
      initialDeepLinkFuture.then((link) {
        if (!mounted || link == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _handleIncomingLink(link);
        });
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Localizations are not safe in initState — AuthGate builds this
    // screen on AuthState.error, so reading context.l10n there crashed
    // failed-auth users into ErrorBoundary instead of the sign-in page.
    if (widget.showError && !_didApplyShowError) {
      _didApplyShowError = true;
      _error = context.l10n.authSomethingWentWrong;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // -- deep-link handling ---------------------

  Future<void> _handleIncomingLink(String url) async {
    setState(() {
      _isProcessingLink = true;
      _error = null;
    });

    try {
      final publicKey = AuthService.parseAuthUrl(url);
      if (publicKey == null) {
        setState(() {
          _error = context.l10n.authInvalidQR;
          _isProcessingLink = false;
        });
        return;
      }

      ref.read(authStateNotifierProvider.notifier).handleDeepLink(url);
      setState(() {
        _error = context.l10n.authSignInFirst;
        _isProcessingLink = false;
      });
    } catch (e, st) {
      logger.warning('Device linking failed: $e', e, st);
      setState(() {
        _error = context.l10n.authErrorLinkingDevice(e.toString());
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

  // -- account actions ------------------------

  Future<void> _createAccount() async {
    setState(() {
      _isLoadingCreateAccount = true;
      _error = null;
    });

    try {
      logger.info('Creating account...');
      await AuthService().createAccount();
      logger.info('Account created successfully');
      if (mounted) {
        unawaited(ref.read(authStateNotifierProvider.notifier).checkAuth());
      }
    } catch (e, st) {
      logger.warning('Create account error: $e', e, st);
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
      builder: (ctx) => RestoreKeyDialog(
        onRestore: (normalized) async {
          await AuthService().restoreAccount(normalized);
          if (!mounted) return;
          Navigator.of(context).pop();
          unawaited(ref.read(authStateNotifierProvider.notifier).checkAuth());
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
    } catch (e, st) {
      logger.warning('QR auth start failed: $e', e, st);
      setState(() {
        _error = _formatErrorMessage(e, context);
        _isPolling = false;
      });
    }
  }

  // -- helpers --------------------------------

  String _formatErrorMessage(dynamic e, BuildContext ctx) {
    final l10n = ctx.l10n;
    if (e is AuthForbiddenError) {
      return '${l10n.authAccessDenied}\n'
          '${e.message}';
    } else if (e is AuthRequestError) {
      final statusCode = e.statusCode ?? 400;
      return '${l10n.authClientError} '
          '($statusCode)\n${e.message}';
    } else if (e is ServerError) {
      final statusCode = e.statusCode ?? 500;
      return '${l10n.authServerError} '
          '($statusCode)\n${e.message}';
    } else if (e is SSLError) {
      return '${l10n.authCertificateError}\n'
          '${e.message}';
    } else if (e is ExpiredError) {
      return e.messageText;
    } else if (e is AuthError) {
      return e.messageText;
    } else if (e is AuthException) {
      return e.message;
    }
    return '${l10n.authAuthenticationFailed}: $e';
  }

  Future<void> _pollForApproval(Uint8List publicKey) async {
    try {
      await AuthService().waitForAuthApproval(publicKey);
      if (mounted) {
        setState(() => _isPolling = false);
        unawaited(ref.read(authStateNotifierProvider.notifier).checkAuth());
      }
    } catch (e, st) {
      logger.warning('QR auth approval poll failed: $e', e, st);
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
      barrierLabel: MaterialLocalizations.of(ctx).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: AppDuration.slow,
      transitionBuilder: (ctx2, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: AppCurve.enter)),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: AppCurve.enter),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx2, animation, secondaryAnimation) {
        return ServerUrlDialog(
          initialUrl: getServerUrl(),
          defaultUrl: defaultServerUrl,
        );
      },
    );
  }

  void _showLogs() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => const DevLogsScreen(requireDeveloperMode: false),
      ),
    );
  }

  Widget? _buildDiagnosticsButton(BuildContext context) {
    if (!widget.showError) return null;
    return OutlinedButton.icon(
      onPressed: _showLogs,
      icon: const Icon(Icons.receipt_long_outlined),
      label: Text('View ${context.l10n.devLogsTitle}'),
    );
  }

  // -- build ----------------------------------

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: _buildAppBar(context),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: AnimatedGradientBackground(
          child: AnimatedSwitcher(
            duration: AppDuration.slow,
            switchInCurve: AppCurve.enter,
            switchOutCurve: AppCurve.exit,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: _showQRScreen
                        ? const Offset(0.05, 0)
                        : const Offset(-0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _showQRScreen
                ? _buildQRScreen(context, isLandscape)
                : _buildLandingScreen(context, isLandscape),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    if (_showQRScreen) {
      return AppBar(
        title: Text(context.l10n.authLinkAccount),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.l10n.commonBack,
          onPressed: _goBack,
        ),
      );
    }

    return AppBar(
      title: Text(context.l10n.appTitle),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: context.l10n.authServerSettings,
          onPressed: () => _showServerDialog(context),
        ),
      ],
    );
  }

  Widget _buildLandingScreen(BuildContext context, bool isLandscape) {
    final theme = Theme.of(context);
    final padding = MediaQuery.of(context).padding;

    final notices = _buildNotices(context);
    final header = AuthHeader(theme: theme);
    final buttons = AuthButtonGroup(
      onCreateAccount: _createAccount,
      onLinkAccount: _showQRAuth,
      onRestoreKey: _showSecretKeyDialog,
      isLoadingCreate: _isLoadingCreateAccount,
      l10n: context.l10n,
    );
    final diagnosticsButton = _buildDiagnosticsButton(context);

    if (isLandscape) {
      return KeyedSubtree(
        key: const ValueKey('landing'),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.xxxl + AppSpacing.lg,
              right: AppSpacing.xxxl + AppSpacing.lg,
              bottom: padding.bottom + AppSpacing.xxl,
            ),
            child: Row(
              children: [
                const Expanded(child: Center(child: LandingLogoMark())),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...notices,
                        header,
                        const SizedBox(height: AppSpacing.xxxl),
                        SizedBox(
                          width: 300,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              buttons,
                              if (diagnosticsButton != null) ...[
                                const SizedBox(height: AppSpacing.md),
                                diagnosticsButton,
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return KeyedSubtree(
      key: const ValueKey('landing'),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppSpacing.xxxl),
                    ...notices,
                    header,
                    const SizedBox(height: AppSpacing.xxxl + AppSpacing.lg),
                    SizedBox(
                      width: 300,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          buttons,
                          if (diagnosticsButton != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            diagnosticsButton,
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNotices(BuildContext context) {
    final notices = <Widget>[];
    final scheme = Theme.of(context).colorScheme;

    if (_isProcessingLink) {
      notices.add(
        StatusBanner(
          icon: null,
          message: context.l10n.authProcessingDeviceLink,
          color: scheme.primary,
          isLoading: true,
          onDismiss: null,
        ),
      );
    }

    if (_linkSuccessMessage != null) {
      notices.add(
        StatusBanner(
          icon: Icons.check_circle_rounded,
          message: _linkSuccessMessage!,
          color: AppColors.success,
          isLoading: false,
          onDismiss: () => setState(() => _linkSuccessMessage = null),
        ),
      );
    }

    if (_serverError != null) {
      notices.add(
        StatusBanner(
          icon: Icons.warning_amber_rounded,
          message: context.l10n.authServerConnectionError,
          color: scheme.error,
          isLoading: false,
          onDismiss: () => setState(() => _serverError = null),
        ),
      );
    }

    if (_error != null) {
      notices.add(
        StatusBanner(
          icon: Icons.error_outline_rounded,
          message: _error!,
          color: scheme.error,
          isLoading: false,
          onDismiss: () => setState(() => _error = null),
        ),
      );
    }

    return notices;
  }

  Widget _buildQRScreen(BuildContext context, bool isLandscape) {
    final theme = Theme.of(context);
    final padding = MediaQuery.of(context).padding;

    final instructions = QRInstructions(theme: theme);

    final qrSection = QRCodeSection(
      isPolling: _isPolling,
      publicKey: _publicKey,
      error: _error,
      onDismissError: () => setState(() => _error = null),
      theme: theme,
    );

    final actions = PollingView(
      isPolling: _isPolling,
      hasError: _error != null,
      onTryAgain: _startQRAuth,
      onBack: _goBack,
      theme: theme,
    );

    if (isLandscape) {
      return KeyedSubtree(
        key: const ValueKey('qr-screen'),
        child: SafeArea(
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
                      SizedBox(width: 300, child: actions),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return KeyedSubtree(
      key: const ValueKey('qr-screen'),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    instructions,
                    const SizedBox(height: AppSpacing.xxl),
                    qrSection,
                    const SizedBox(height: AppSpacing.xxl),
                    SizedBox(width: 300, child: actions),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
