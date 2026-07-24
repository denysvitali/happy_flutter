import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/profile.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/safe_pop.dart';
import '../../core/utils/utils.dart';
import '../../core/utils/datetime_extensions.dart';

/// Linked devices screen
class LinkedDevicesScreen extends ConsumerStatefulWidget {
  const LinkedDevicesScreen({super.key});

  @override
  ConsumerState<LinkedDevicesScreen> createState() =>
      _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState
    extends ConsumerState<LinkedDevicesScreen> {
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
    } catch (e, st) {
      logger.warning('Error loading devices: $e', e, st);
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
          content: Text(l10nDialog.accountUnlinkConfirm),
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

    final success = await AuthService().unlinkDevice(device.id);
    if (success) {
      unawaited(_loadDevices());
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.accountFailedToUnlink)),
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
          onPressed: () => safePop<void>(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
          ? const AppEmptyState(
              icon: Icons.devices,
              title: 'No linked devices',
            )
          : ListView.builder(
              padding: AppScreenPadding.settings,
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
    required this.device,
    required this.onUnlink,
    super.key,
  });

  final DeviceInfo device;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
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
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  l10n.accountThisDevice,
                  style: TextStyle(
                    fontSize: AppFontSize.xs,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          l10n.accountLastActive(
            device.platform,
            _formatLastActive(),
          ),
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

  String _formatLastActive() => formatRelativeTime(
    device.lastActive,
    absoluteFallback: (d) => d.toLocal().toIsoDateString(),
  );
}
