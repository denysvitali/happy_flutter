import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/auth.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/theme/app_tokens.dart';
import '../auth/widgets/qr_code_display.dart';

/// The three modes of the device linking screen.
enum _LinkMode { scan, showQR, enterURL }

/// Device linking screen
class LinkDeviceScreen extends ConsumerStatefulWidget {
  const LinkDeviceScreen({super.key});

  @override
  ConsumerState<LinkDeviceScreen> createState() =>
      _LinkDeviceScreenState();
}

class _LinkDeviceScreenState extends ConsumerState<LinkDeviceScreen> {
  _LinkMode _mode = _LinkMode.scan;
  late final MobileScannerController _scanController;
  bool _scanned = false;

  // showQR mode state
  DeviceLinkingResult? _linkingResult;
  bool _qrLoading = false;
  bool _isPolling = false;

  // shared state
  bool _isLoading = false;
  String? _error;

  // enterURL mode state
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scanController = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    unawaited(_scanController.dispose());
    super.dispose();
  }

  Future<void> _startLinking() async {
    if (_mode != _LinkMode.showQR) return;
    setState(() {
      _qrLoading = true;
      _error = null;
    });
    try {
      final result = await AuthService().startDeviceLinking();
      if (!mounted || _mode != _LinkMode.showQR) return;
      setState(() {
        _linkingResult = result;
        _qrLoading = false;
        _isPolling = true;
      });
      unawaited(_pollForApproval());
    } catch (e, st) {
      logger.warning('Failed to start device linking: $e', e, st);
      if (mounted) {
        setState(() {
          _error = 'Failed to start device linking: $e';
          _qrLoading = false;
        });
      }
    }
  }

  Future<void> _pollForApproval() async {
    if (_linkingResult == null) return;
    try {
      await AuthService()
          .waitForLinkingApproval(_linkingResult!.linkingId);
      if (mounted) {
        unawaited(
          ref.read(authStateNotifierProvider.notifier).checkAuth(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.authDeviceLinkedSuccess),
            ),
          );
          context.pop();
        }
      }
    } catch (e, st) {
      logger.warning(
        'Device linking approval poll failed: $e',
        e,
        st,
      );
      if (mounted) {
        setState(() {
          _error = _formatError(e);
          _isPolling = false;
        });
      }
    }
  }

  Future<void> _approveUrl(String url) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService().approveLinkingRequest(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.authDeviceLinkedSuccess),
          ),
        );
        context.pop();
      }
    } catch (e, st) {
      logger.warning('Failed to approve linking request: $e', e, st);
      if (mounted) {
        setState(() {
          _error = _formatError(e);
          _isLoading = false;
          _scanned = false;
        });
        if (_mode == _LinkMode.scan) {
          unawaited(_scanController.start());
        }
      }
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_scanned || _isLoading || _mode != _LinkMode.scan) return;
    for (final barcode in capture.barcodes) {
      final url = barcode.rawValue;
      if (url != null && url.startsWith('happy://')) {
        _scanned = true;
        unawaited(_scanController.stop());
        unawaited(_approveUrl(url));
        return;
      }
    }
  }

  Future<void> _submitUrl() async {
    final url = _urlController.text.trim();
    if (!url.startsWith('happy://')) {
      setState(() {
        _error = 'Invalid URL format. Must start with "happy://"';
      });
      return;
    }
    await _approveUrl(url);
  }

  String _formatError(dynamic e) {
    if (e is ExpiredError) return 'Linking timed out. Please try again.';
    if (e is AuthForbiddenError) return 'Linking rejected by server.';
    return 'Linking failed: $e';
  }

  void _setMode(_LinkMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _error = null;
    });
    if (mode == _LinkMode.scan) {
      _scanned = false;
    } else if (mode == _LinkMode.showQR) {
      if (_linkingResult == null && !_qrLoading) {
        _startLinking();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountLinkDevice),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppScreenPadding.settings,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Link a New Device',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xxl),
              SegmentedButton<_LinkMode>(
                segments: [
                  ButtonSegment(
                    value: _LinkMode.scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(l10n.accountScanQR),
                  ),
                  ButtonSegment(
                    value: _LinkMode.showQR,
                    icon: const Icon(Icons.qr_code),
                    label: Text(l10n.accountShowQR),
                  ),
                  ButtonSegment(
                    value: _LinkMode.enterURL,
                    icon: const Icon(Icons.link),
                    label: Text(l10n.accountEnterUrl),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (modes) => _setMode(modes.first),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: cs.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: cs.onErrorContainer,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: cs.onErrorContainer,
                            fontSize: AppFontSize.sm,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        onPressed: () => setState(() => _error = null),
                      ),
                    ],
                  ),
                ),
              Expanded(child: _buildModeContent(cs, l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeContent(ColorScheme cs, AppLocalizations l10n) {
    return switch (_mode) {
      _LinkMode.scan => _buildScanContent(cs, l10n),
      _LinkMode.showQR => _buildShowQRContent(cs, l10n),
      _LinkMode.enterURL => _buildEnterURLContent(cs, l10n),
    };
  }

  Widget _buildScanContent(ColorScheme cs, AppLocalizations l10n) {
    return Column(
      children: [
        Text(
          l10n.accountScanInstruction,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppFontSize.base,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        clipBehavior: Clip.hardEdge,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: MobileScanner(
                          controller: _scanController,
                          onDetect: _onBarcodeDetected,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!_isLoading)
          Text(
            l10n.accountScanHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: cs.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildShowQRContent(ColorScheme cs, AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            l10n.accountShowQRInstructions,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppFontSize.base,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          if (_qrLoading)
            Container(
              width: 250,
              height: 250,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (_linkingResult != null)
            QRCodeDisplay(data: _linkingResult!.getQRData(), size: 250),
          if (_isPolling) ...[
            const SizedBox(height: AppSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Waiting for device to scan...',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xxxl),
          SizedBox(
            width: 200,
            height: AppTouchTarget.min,
            child: OutlinedButton(
              onPressed: !_isPolling && _error != null
                  ? _startLinking
                  : () => context.pop(),
              child: Text(
                !_isPolling && _error != null
                    ? l10n.authTryAgain
                    : l10n.commonCancel,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterURLContent(ColorScheme cs, AppLocalizations l10n) {
    return Column(
      children: [
        Text(
          'Enter the linking URL from another device:\n\n'
          'happy://terminal?...\n\n'
          'Or happy:///account?...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppFontSize.base,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        TextField(
          controller: _urlController,
          enabled: !_isLoading,
          decoration: const InputDecoration(
            hintText: 'happy://terminal?...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: 200,
          height: AppTouchTarget.min,
          child: FilledButton(
            onPressed: _isLoading ? null : _submitUrl,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.accountApproveLinking),
          ),
        ),
      ],
    );
  }
}
