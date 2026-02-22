import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/auth.dart';
import '../../core/models/profile.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/services/logger_service.dart';
import '../../core/utils/backup_key_utils.dart';
import '../auth/auth_screen.dart' show QRCodeDisplay;

/// Account management screen
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          buildProfileSection(context, ref),
          const SizedBox(height: AppSpacing.xxl),
          buildBackupSection(context),
          const SizedBox(height: AppSpacing.xxl),
          buildRestoreSection(context),
          const SizedBox(height: AppSpacing.xxl),
          buildDevicesSection(context),
          const SizedBox(height: AppSpacing.xxl),
          buildServicesSection(context),
        ],
      ),
    );
  }

  Widget buildProfileSection(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileNotifierProvider);
    return SettingsSection(
      title: 'Profile',
      children: [
        ListTile(
          leading: profile?.avatarUrl != null
              ? CircleAvatar(
                  backgroundImage: ResizeImage(
                    NetworkImage(profile!.avatarUrl!),
                    width: (48 * 3).toInt(),
                    height: (48 * 3).toInt(),
                  ),
                )
              : const CircleAvatar(
                  child: Icon(Icons.person),
                ),
          title: Text(profile?.displayName ?? 'Loading...'),
          subtitle: Text(profile?.github?.email ?? 'Not loaded'),
        ),
      ],
    );
  }

  Widget buildBackupSection(BuildContext context) {
    return SettingsSection(
      title: 'Backup Key',
      children: [
        ListTile(
          leading: const Icon(Icons.key),
          title: const Text('Show Backup Key'),
          subtitle: const Text('View your account recovery key'),
          onTap: () => _showBackupKeyDialog(context),
        ),
        ListTile(
          leading: const Icon(Icons.content_copy),
          title: const Text('Copy Backup Key'),
          subtitle: const Text('Copy to clipboard'),
          onTap: () => _copyBackupKey(context),
        ),
      ],
    );
  }

  Widget buildRestoreSection(BuildContext context) {
    return SettingsSection(
      title: 'Restore',
      children: [
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('Restore Account'),
          subtitle: const Text('Recover account from backup key'),
          onTap: () => context.push('/settings/account/restore'),
        ),
      ],
    );
  }

  Widget buildDevicesSection(BuildContext context) {
    return SettingsSection(
      title: 'Devices',
      children: [
        ListTile(
          leading: const Icon(Icons.devices),
          title: const Text('Linked Devices'),
          subtitle: const Text('Manage devices linked to your account'),
          onTap: () => context.push('/settings/account/devices'),
        ),
        ListTile(
          leading: const Icon(Icons.add_link),
          title: const Text('Link New Device'),
          subtitle: const Text('Generate QR code for another device'),
          onTap: () => context.push('/settings/account/link'),
        ),
      ],
    );
  }

  Widget buildServicesSection(BuildContext context) {
    return SettingsSection(
      title: 'Connected Services',
      children: [const _ConnectedServicesLoader()],
    );
  }

  void _showBackupKeyDialog(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final key = await AuthService().generateBackupKey();
      if (!context.mounted) return;
      unawaited(showDialog(
        context: context,
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return AlertDialog(
          title: const Text('Backup Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Save this key in a safe place. You can use it'
                ' to restore your account.',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: SelectableText(
                  key,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: key));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup key copied')),
                );
              },
              icon: const Icon(Icons.content_copy),
              label: const Text('Copy'),
            ),
          ],
        );
        },
      ));
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _copyBackupKey(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final key = await AuthService().generateBackupKey();
      await Clipboard.setData(ClipboardData(text: key));
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Backup key copied to clipboard')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

/// Loads connected services once in initState to avoid re-fetching on rebuild.
class _ConnectedServicesLoader extends StatefulWidget {
  const _ConnectedServicesLoader();

  @override
  State<_ConnectedServicesLoader> createState() =>
      _ConnectedServicesLoaderState();
}

class _ConnectedServicesLoaderState extends State<_ConnectedServicesLoader> {
  late final Future<List<ConnectedServiceInfo>> _future;

  @override
  void initState() {
    super.initState();
    _future = AuthService().getConnectedServices();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConnectedServiceInfo>>(
      future: _future,
      builder: (context, snapshot) {
        final services = snapshot.data ?? [];
        return Column(
          children: ConnectedService.values.map((service) {
            final info = services.firstWhere(
              (s) => s.service == service,
              orElse: () =>
                  ConnectedServiceInfo(service: service, isConnected: false),
            );
            return ServiceTile(service: info);
          }).toList(),
        );
      },
    );
  }
}

/// Service tile for connected services
class ServiceTile extends StatelessWidget {

  const ServiceTile({required this.service, super.key});
  final ConnectedServiceInfo service;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(_getServiceIcon(), color: _getServiceColor(cs)),
      title: Text(service.service.displayName),
      subtitle: service.isConnected
          ? Text(service.accountName ?? service.accountEmail ?? 'Connected')
          : const Text('Not connected'),
      trailing: service.isConnected
          ? Icon(Icons.check_circle, color: cs.primary)
          : Icon(
              Icons.circle_outlined,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
      onTap: service.isConnected ? () => _showServiceInfo(context) : null,
    );
  }

  IconData _getServiceIcon() {
    switch (service.service) {
      case ConnectedService.claude:
        return Icons.auto_awesome;
      case ConnectedService.github:
        return Icons.code;
      case ConnectedService.gemini:
        return Icons.auto_awesome;
      case ConnectedService.openai:
        return Icons.psychology;
    }
  }

  Color _getServiceColor(ColorScheme cs) {
    switch (service.service) {
      case ConnectedService.claude:
        return AppColors.warning;
      case ConnectedService.github:
        return cs.onSurface;
      case ConnectedService.gemini:
        return cs.primary;
      case ConnectedService.openai:
        return AppColors.success;
    }
  }

  void _showServiceInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${service.service.displayName} Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (service.accountName != null)
              ListTile(
                title: const Text('Name'),
                subtitle: Text(service.accountName!),
              ),
            if (service.accountEmail != null)
              ListTile(
                title: const Text('Email'),
                subtitle: Text(service.accountEmail!),
              ),
            if (service.connectedAt != null)
              ListTile(
                title: const Text('Connected'),
                subtitle: Text(service.connectedAt!.toLocal().toString()),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Account restoration screen
class RestoreAccountScreen extends ConsumerStatefulWidget {
  const RestoreAccountScreen({super.key});

  @override
  ConsumerState<RestoreAccountScreen> createState() =>
      _RestoreAccountScreenState();
}

class _RestoreAccountScreenState extends ConsumerState<RestoreAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter your backup key to restore your account.',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Backup Key',
                  hintText: 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX',
                  prefixIcon: Icon(Icons.key),
                  border: OutlineInputBorder(),
                ),
                validator: _validateKey,
                enabled: !_isLoading,
                maxLength: 35,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Builder(
                builder: (context) {
                  final cs = Theme.of(context).colorScheme;
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
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
                            _error ?? '',
                            style: TextStyle(color: cs.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _restoreAccount,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Restore Account'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed:
                    _isLoading ? null : () => _pasteFromClipboard(context),
                child: const Text('Paste from Clipboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateKey(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your backup key';
    }
    if (!BackupKeyUtils.isValidKey(value)) {
      return 'Invalid key format. Use XXXXX-XXXXX-XXXXX-XXXXX-XXXXX';
    }
    return null;
  }

  void _pasteFromClipboard(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        _controller.text = data.text ?? '';
      });
    }
  }

  Future<void> _restoreAccount() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AuthService().restoreAccount(_controller.text.trim());
      if (mounted) {
        unawaited(ref.read(authStateNotifierProvider.notifier).checkAuth());
        if (mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account restored successfully')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = _formatError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatError(dynamic e) {
    if (e is AuthForbiddenError) {
      return 'Access denied. Please try again.';
    } else if (e is AuthRequestError) {
      return e.message;
    }
    return 'Failed to restore account: $e';
  }
}

/// The three modes of the device linking screen.
enum _LinkMode { scan, showQR, enterURL }

/// Device linking screen
class LinkDeviceScreen extends ConsumerStatefulWidget {
  const LinkDeviceScreen({super.key});

  @override
  ConsumerState<LinkDeviceScreen> createState() => _LinkDeviceScreenState();
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
    } catch (e) {
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
      await AuthService().waitForLinkingApproval(_linkingResult!.linkingId);
      if (mounted) {
        unawaited(ref.read(authStateNotifierProvider.notifier).checkAuth());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device linked successfully!')),
          );
          context.pop();
        }
      }
    } catch (e) {
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
          const SnackBar(content: Text('Device linked successfully!')),
        );
        context.pop();
      }
    } catch (e) {
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
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Link a New Device',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
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
                onSelectionChanged: (modes) =>
                    _setMode(modes.first),
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
                      Icon(Icons.error_outline, color: cs.onErrorContainer),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: cs.onErrorContainer,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _error = null),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _buildModeContent(cs, l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeContent(
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    return switch (_mode) {
      _LinkMode.scan => _buildScanContent(cs),
      _LinkMode.showQR => _buildShowQRContent(cs, l10n),
      _LinkMode.enterURL => _buildEnterURLContent(cs, l10n),
    };
  }

  Widget _buildScanContent(ColorScheme cs) {
    return Column(
      children: [
        Text(
          'Point your camera at the QR code displayed'
          ' on the new device',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
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
            'New device: tap "Link or Restore Account"',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildShowQRContent(
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            '1. Open Happy on the new device\n'
            '2. Tap "Link or Restore Account"\n'
            '3. Scan this QR code',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
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
            height: 44,
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

  Widget _buildEnterURLContent(
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        Text(
          'Enter the linking URL from another device:\n\n'
          'happy://terminal?...\n\n'
          'Or happy:///account?...',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
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
          height: 44,
          child: FilledButton(
            onPressed: _isLoading ? null : _submitUrl,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : Text(l10n.accountApproveLinking),
          ),
        ),
      ],
    );
  }
}

/// Linked devices screen
class LinkedDevicesScreen extends ConsumerStatefulWidget {
  const LinkedDevicesScreen({super.key});

  @override
  ConsumerState<LinkedDevicesScreen> createState() =>
      _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends ConsumerState<LinkedDevicesScreen> {
  List<DeviceInfo> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _devices = await AuthService().getLinkedDevices();
    } catch (e) {
      logger.warning('Error loading devices: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unlinkDevice(DeviceInfo device) async {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10nDialog = AppLocalizations.of(context);
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(l10nDialog.accountUnlinkDevice),
          content: Text(
            'Are you sure you want to unlink "${device.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10nDialog.commonCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10nDialog.accountUnlink),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final success =
        await AuthService().unlinkDevice(device.id);
    if (success) {
      unawaited(_loadDevices());
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.accountFailedToUnlink),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountLinkedDevices),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? Center(
                  child: Builder(
                    builder: (context) {
                      final cs = Theme.of(context).colorScheme;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.devices,
                            size: 64,
                            color: cs.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'No linked devices',
                            style: TextStyle(
                              fontSize: 16,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    return DeviceTile(
                      device: device,
                      onUnlink: () => _unlinkDevice(device),
                    );
                  },
                ),
    );
  }
}

/// Device tile widget
class DeviceTile extends StatelessWidget {

  const DeviceTile({
    required this.device, required this.onUnlink, super.key,
  });
  final DeviceInfo device;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        leading: Icon(_getPlatformIcon()),
        title: Row(
          children: [
            Expanded(child: Text(device.name)),
            if (device.isCurrentDevice)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  'This Device',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${device.platform} • Last active ${_formatLastActive()}',
        ),
        trailing: device.isCurrentDevice
            ? null
            : IconButton(
                icon: Icon(Icons.delete_outline, color: cs.error),
                onPressed: onUnlink,
              ),
      ),
    );
  }

  IconData _getPlatformIcon() {
    switch (device.platform.toLowerCase()) {
      case 'ios':
        return Icons.phone_iphone;
      case 'android':
        return Icons.phone_android;
      case 'macos':
      case 'windows':
      case 'linux':
        return Icons.computer;
      case 'web':
        return Icons.language;
      default:
        return Icons.devices;
    }
  }

  String _formatLastActive() {
    final now = DateTime.now();
    final diff = now.difference(device.lastActive);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return device.lastActive.toLocal().toString().split(' ')[0];
  }
}
