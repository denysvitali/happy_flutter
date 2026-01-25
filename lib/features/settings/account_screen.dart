import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr/qr.dart';
import '../../core/models/auth.dart';
import '../../core/models/profile.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/auth_service.dart' hide AuthForbiddenError, AuthRequestError, ServerError, SSLError;
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
        padding: const EdgeInsets.all(16),
        children: [
          buildProfileSection(context, ref),
          const SizedBox(height: 24),
          buildBackupSection(context),
          const SizedBox(height: 24),
          buildRestoreSection(context),
          const SizedBox(height: 24),
          buildDevicesSection(context),
          const SizedBox(height: 24),
          buildServicesSection(context),
        ],
      ),
    );
  }

  Widget buildProfileSection(BuildContext context, WidgetRef ref) {
    return SettingsSection(
      title: 'Profile',
      children: [
        Consumer(
          builder: (context, ref, child) {
            return FutureBuilder<Profile?>(
              future: AuthService().getProfile(),
              builder: (context, snapshot) {
                final profile = snapshot.data;
                return ListTile(
                  leading: profile?.avatarUrl != null
                      ? CircleAvatar(
                          backgroundImage: NetworkImage(profile!.avatarUrl!),
                        )
                      : const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                  title: Text(profile?.displayName ?? 'Loading...'),
                  subtitle: Text(profile?.github?.email ?? 'Not loaded'),
                );
              },
            );
          },
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
      children: [
        Consumer(
          builder: (context, ref, child) {
            return FutureBuilder<List<ConnectedServiceInfo>>(
              future: AuthService().getConnectedServices(),
              builder: (context, snapshot) {
                final services = snapshot.data ?? [];

                return Column(
                  children: ConnectedService.values.map((service) {
                    final info = services.firstWhere(
                      (s) => s.service == service,
                      orElse: () => ConnectedServiceInfo(
                        service: service,
                        isConnected: false,
                      ),
                    );
                    return ServiceTile(service: info);
                  }).toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _showBackupKeyDialog(BuildContext context) async {
    try {
      final key = await AuthService().generateBackupKey();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Backup Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Save this key in a safe place. You can use it to restore your account.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
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
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _copyBackupKey(BuildContext context) async {
    try {
      final key = await AuthService().generateBackupKey();
      await Clipboard.setData(ClipboardData(text: key));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup key copied to clipboard')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

/// Service tile for connected services
class ServiceTile extends StatelessWidget {
  final ConnectedServiceInfo service;

  const ServiceTile({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_getServiceIcon(), color: _getServiceColor()),
      title: Text(service.service.displayName),
      subtitle: service.isConnected
          ? Text(service.accountName ?? service.accountEmail ?? 'Connected')
          : const Text('Not connected'),
      trailing: service.isConnected
          ? Icon(Icons.check_circle, color: Colors.green[400])
          : Icon(Icons.circle_outlined, color: Colors.grey[400]),
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

  Color _getServiceColor() {
    switch (service.service) {
      case ConnectedService.claude:
        return Colors.orange;
      case ConnectedService.github:
        return Colors.grey[800]!;
      case ConnectedService.gemini:
        return Colors.blue;
      case ConnectedService.openai:
        return Colors.green;
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your backup key to restore your account.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
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
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => _pasteFromClipboard(context),
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
        _controller.text = data.text!;
      });
    }
  }

  Future<void> _restoreAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AuthService().restoreAccount(_controller.text.trim());
      if (mounted) {
        ref.read(authStateNotifierProvider.notifier).checkAuth();
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

/// Device linking screen
class LinkDeviceScreen extends ConsumerStatefulWidget {
  const LinkDeviceScreen({super.key});

  @override
  ConsumerState<LinkDeviceScreen> createState() => _LinkDeviceScreenState();
}

class _LinkDeviceScreenState extends ConsumerState<LinkDeviceScreen> {
  DeviceLinkingResult? _linkingResult;
  bool _isLoading = false;
  bool _isPolling = false;
  String? _error;
  bool _showQR = true;
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startLinking();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _startLinking() async {
    if (!_showQR) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await AuthService().startDeviceLinking();
      setState(() {
        _linkingResult = result;
        _isLoading = false;
        _isPolling = true;
      });

      _pollForApproval();
    } catch (e) {
      setState(() {
        _error = 'Failed to start device linking: $e';
        _isLoading = false;
      });
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

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AuthService().approveLinkingRequest(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device link approved successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to approve linking: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pollForApproval() async {
    if (_linkingResult == null) return;

    try {
      await AuthService().waitForLinkingApproval(_linkingResult!.linkingId);
      if (mounted) {
        ref.read(authStateNotifierProvider.notifier).checkAuth();
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

  String _formatError(dynamic e) {
    if (e is ExpiredError) {
      return 'Linking timed out. Please try again.';
    } else if (e is AuthForbiddenError) {
      return 'Linking rejected by server.';
    }
    return 'Linking failed: $e';
  }

  void _toggleMode() {
    setState(() {
      _showQR = !_showQR;
      _error = null;
      if (_showQR && _linkingResult == null) {
        _startLinking();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Device'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Link a New Device',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _showQR ? null : () => _toggleMode(),
                      style: ButtonStyle(
                        backgroundColor: _showQR
                            ? MaterialStateProperty.all<Color>(
                                Theme.of(context).colorScheme.primary.withOpacity(0.1))
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code, size: 18),
                            const SizedBox(width: 8),
                            const Text('Show QR'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: !_showQR ? null : () => _toggleMode(),
                      style: ButtonStyle(
                        backgroundColor: !_showQR
                            ? MaterialStateProperty.all<Color>(
                                Theme.of(context).colorScheme.primary.withOpacity(0.1))
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.link, size: 18),
                            const SizedBox(width: 8),
                            const Text('Enter URL'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red[700], fontSize: 12),
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
              const SizedBox(height: 32),
              if (_showQR) ...[
                const Text(
                  '1. Open Happy on another device\n'
                  '2. Go to Settings → Account\n'
                  '3. Tap "Restore Account"\n'
                  '4. Scan this QR code',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                if (_isLoading)
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
                  )
                else if (_linkingResult != null)
                  QRCodeDisplay(
                    data: _linkingResult!.getQRData(),
                    size: 250,
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
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              if (!_showQR) ...[
                const Text(
                  'Enter the linking URL from another device:\n\n'
                  'happy://terminal?...\n\n'
                  'Or happy:///account?...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _urlController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    hintText: 'happy://terminal?...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 200,
                  height: 44,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _submitUrl,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Approve Linking'),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                height: 44,
                child: OutlinedButton(
                  onPressed: _isPolling && _error != null
                      ? _startLinking
                      : () => context.pop(),
                  child: Text(
                    _isPolling && _error != null ? 'Try Again' : 'Cancel',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
      debugPrint('Error loading devices: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unlinkDevice(DeviceInfo device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Device'),
        content: Text(
          'Are you sure you want to unlink "${device.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await AuthService().unlinkDevice(device.id);
    if (success) {
      _loadDevices();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to unlink device')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Linked Devices'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.devices, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No linked devices',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
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
  final DeviceInfo device;
  final VoidCallback onUnlink;

  const DeviceTile({
    super.key,
    required this.device,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(_getPlatformIcon()),
        title: Row(
          children: [
            Expanded(child: Text(device.name)),
            if (device.isCurrentDevice)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'This Device',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[700],
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
                icon: Icon(Icons.delete_outline, color: Colors.red[400]),
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

/// Settings section wrapper
class SettingsSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const SettingsSection({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              title!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ),
        Card(child: Column(children: children)),
      ],
    );
  }
}
