import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/socket_io_client.dart' show ConnectionStatus;
import '../../../core/components/settings_section.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_colors.dart';

class SettingsHealthSection extends ConsumerWidget {
  const SettingsHealthSection({
    required this.sessionTotal,
    required this.onlineSessions,
    required this.machineTotal,
    required this.onlineMachines,
    super.key,
  });

  final int sessionTotal;
  final int onlineSessions;
  final int machineTotal;
  final int onlineMachines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final syncState = ref.watch(syncStateNotifierProvider);
    final isOnline = ref.watch(networkNotifierProvider);
    final connected = connectionStatus == ConnectionStatus.connected;
    final syncReady = sync.isReady && connected && isOnline;
    final syncInitialized = sync.isInitialized;
    final syncColor = syncReady
        ? AppColors.success
        : syncInitialized
        ? AppColors.warning
        : AppColors.error;
    final syncSubtitle = syncReady
        ? syncState.isSyncing
              ? 'Connected and applying the latest updates'
              : 'Ready for sessions, messages, and settings updates'
        : !isOnline
        ? 'Offline. Updates will resume when the network returns'
        : connected && syncInitialized
        ? 'Connected, waiting for initial data to finish loading'
        : 'Reconnecting to live updates';
    final machineSubtitle = machineTotal == 0
        ? 'No machines linked yet'
        : '$onlineMachines online of $machineTotal linked';

    return SettingsSection(
      title: 'Status',
      children: [
        SettingsRow(
          icon: Icons.sync,
          iconColor: syncColor,
          title: syncReady ? 'Sync ready' : 'Sync needs attention',
          subtitle: syncSubtitle,
          trailing: Icon(
            syncReady ? Icons.check_circle : Icons.error_outline,
            color: syncColor,
          ),
          onTap: syncReady ? null : () => context.goNamed('sessions'),
        ),
        SettingsRow(
          icon: Icons.chat_bubble_outline,
          iconColor: AppColors.iosBlue,
          title: 'Sessions',
          subtitle: '$onlineSessions online of $sessionTotal total',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.goNamed('sessions'),
        ),
        SettingsRow(
          icon: Icons.computer_outlined,
          iconColor: machineTotal == 0 ? AppColors.warning : AppColors.success,
          title: 'Machines',
          subtitle: machineSubtitle,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed('machines'),
        ),
        SettingsRow(
          icon: Icons.person_outline,
          iconColor: AppColors.iosBlue,
          title: 'Account and recovery',
          subtitle: 'Backup key, linked devices, restore, and services',
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed('account'),
        ),
      ],
    );
  }
}
