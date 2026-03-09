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
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'widgets/auth_landing_widgets.dart';
import 'widgets/restore_key_dialog.dart';
import 'widgets/server_url_dialog.dart';

/// Authentication screen with landing page pattern
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.initialDeepLink,
    this.showError = false,
  });

  final String? initialDeepLink;

  /// When [true], a banner is shown saying
  /// authentication failed and the user should sign in
  /// again.
  final bool showError;

  @override
  ConsumerState<AuthScreen> createState() =>
      _AuthScreenState();
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

    if (widget.showError) {
      _error = context.l10n.authSomethingWentWrong;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ── deep-link handling ────────────────────────

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

      final credentials =
          await TokenStorage().getCredentials();
      if (credentials == null) {
        setState(() {
          _error = context.l10n.authSignInFirst;
          _isProcessingLink = false;
        });
        return;
      }

      final success =
          await AuthService().approveLinkingRequest(url);

      if (success) {
        setState(() {
          _linkSuccessMessage =
              context.l10n.authDeviceLinkedSuccess;
          _isProcessingLink = false;
        });
      } else {
        setState(() {
          _error = context.l10n.authFailedToLinkDevice;
          _isProcessingLink = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = context.l10n
            .authErrorLinkingDevice(e.toString());
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

  // ── account actions ───────────────────────────

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
        unawaited(
          ref
              .read(authStateNotifierProvider.notifier)
              .checkAuth(),
        );
      }
    } catch (e) {
      logger.warning('Create account error: $e');
      if (e is Error) {
        logger.info('Stack trace: ${e.stackTrace}');
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
      builder: (ctx) => RestoreKeyDialog(
        onRestore: (normalized) async {
          await AuthService().restoreAccount(normalized);
          if (!mounted) return;
          Navigator.of(context).pop();
          unawaited(
            ref
                .read(authStateNotifierProvider.notifier)
                .checkAuth(),
          );
        },
        formatError: (e) =>
            _formatErrorMessage(e, context),
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
      final publicKey =
          await AuthService().startQRAuth();
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

  // ── helpers ──────────────────────────────────

  String _formatErrorMessage(
    dynamic e,
    BuildContext ctx,
  ) {
    final l10n = ctx.l10n;
    if (e is AuthForbiddenError) {
      return '${l10n.authAccessDenied}\n${e.message}';
    } else if (e is AuthRequestError) {
      final statusCode = e.statusCode ?? 400;
      return '${l10n.authClientError} ($statusCode)\n'
          '${e.message}';
    } else if (e is ServerError) {
      final statusCode = e.statusCode ?? 500;
      return '${l10n.authServerError} ($statusCode)\n'
          '${e.message}';
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

  Future<void> _pollForApproval(
    Uint8List publicKey,
  ) async {
    try {
      await AuthService()
          .waitForAuthApproval(publicKey);
      if (mounted) {
        setState(() => _isPolling = false);
        unawaited(
          ref
              .read(authStateNotifierProvider.notifier)
              .checkAuth(),
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
      barrierLabel: MaterialLocalizations.of(ctx)
          .modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: AppDuration.slow,
      transitionBuilder: (
        ctx2,
        animation,
        secondaryAnimation,
        child,
      ) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: AppCurve.enter,
            ),
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: AppCurve.enter,
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (
        ctx2,
        animation,
        secondaryAnimation,
      ) {
        return ServerUrlDialog(
          initialUrl: getServerUrl(),
          defaultUrl: defaultServerUrl,
        );
      },
    );
  }

  // ── build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation ==
            Orientation.landscape;

    if (_showQRScreen) {
      return _buildQRScreen(context, isLandscape);
    }

    return _buildLandingScreen(context, isLandscape);
  }

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
    final header = AuthHeader(theme: theme);
    final buttons = AuthButtonGroup(
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
              const Expanded(
                child: Center(
                  child: LandingLogoMark(),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      ...notices,
                      header,
                      const SizedBox(
                        height: AppSpacing.xxxl,
                      ),
                      SizedBox(
                        width: 280,
                        child: buttons,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      body = SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(
                  AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: AppSpacing.xxl,
                    ),
                    ...notices,
                    header,
                    const SizedBox(
                      height: AppSpacing.xxxl +
                          AppSpacing.lg,
                    ),
                    SizedBox(
                      width: 280,
                      child: buttons,
                    ),
                    const SizedBox(
                      height: AppSpacing.xxl,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: AnimatedGradientBackground(child: body),
      ),
    );
  }

  List<Widget> _buildNotices(BuildContext context) {
    final notices = <Widget>[];

    if (_isProcessingLink) {
      notices.add(
        StatusBanner(
          icon: null,
          message:
              context.l10n.authProcessingDeviceLink,
          color: Theme.of(context).colorScheme.primary,
          isLoading: true,
          onDismiss: null,
        ),
      );
    }

    if (_linkSuccessMessage != null) {
      notices.add(
        StatusBanner(
          icon: Icons.check_circle,
          message: _linkSuccessMessage!,
          color: AppColors.success,
          isLoading: false,
          onDismiss: () =>
              setState(() => _linkSuccessMessage = null),
        ),
      );
    }

    if (_serverError != null) {
      notices.add(
        StatusBanner(
          icon: Icons.warning,
          message:
              context.l10n.authServerConnectionError,
          color: Theme.of(context).colorScheme.error,
          isLoading: false,
          onDismiss: () =>
              setState(() => _serverError = null),
        ),
      );
    }

    if (_error != null) {
      notices.add(
        StatusBanner(
          icon: Icons.error_outline,
          message: _error!,
          color: Theme.of(context).colorScheme.error,
          isLoading: false,
          onDismiss: () =>
              setState(() => _error = null),
        ),
      );
    }

    return notices;
  }

  Widget _buildQRScreen(
    BuildContext context,
    bool isLandscape,
  ) {
    final theme = Theme.of(context);
    final padding = MediaQuery.of(context).padding;

    final appBar = AppBar(
      title: Text(context.l10n.authLinkAccount),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _goBack,
      ),
    );

    final instructions = QRInstructions(theme: theme);

    final qrSection = QRCodeSection(
      isPolling: _isPolling,
      publicKey: _publicKey,
      error: _error,
      onDismissError: () =>
          setState(() => _error = null),
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
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [instructions],
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      qrSection,
                      const SizedBox(
                        height: AppSpacing.xxl,
                      ),
                      SizedBox(
                        width: 280,
                        child: actions,
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

    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: AppSpacing.lg,
                    ),
                    instructions,
                    const SizedBox(
                      height: AppSpacing.xxxl,
                    ),
                    qrSection,
                    const SizedBox(
                      height: AppSpacing.xxl,
                    ),
                    SizedBox(
                      width: 280,
                      child: actions,
                    ),
                    const SizedBox(
                      height: AppSpacing.xxl,
                    ),
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
    final authState =
        ref.watch(authStateNotifierProvider);

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
      AuthState.unauthenticated => AuthScreen(
          initialDeepLink: initialDeepLink,
        ),
      AuthState.authenticating => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_rounded,
                  size: 48,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Checking sign-in status...',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xxl),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      AuthState.error => AuthScreen(
          initialDeepLink: initialDeepLink,
          showError: true,
        ),
    };
  }
}
