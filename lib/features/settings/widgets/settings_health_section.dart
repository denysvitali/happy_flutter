import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/settings_section.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_colors.dart';

class SettingsHealthSection extends StatelessWidget {
  const SettingsHealthSection({
    required this.sessionTotal,
    required this.onlineSessions,
    required this.machineTotal,
    required this.activeMachines,
    super.key,
  });

  final int sessionTotal;
  final int onlineSessions;
  final int machineTotal;
  final int activeMachines;

  @override
  Widget build(BuildContext context) {
    final syncReady = sync.isReady;
    final syncInitialized = sync.isInitialized;
    final syncColor = syncReady
        ? AppColors.success
        : syncInitialized
        ? AppColors.warning
        : AppColors.error;
    final syncSubtitle = syncReady
        ? 'Ready for sessions, messages, and settings updates'
        : syncInitialized
        ? 'Connected, waiting for initial data to finish loading'
        : 'Waiting for account data to initialize';
    final machineSubtitle = machineTotal == 0
        ? 'No machines linked yet'
        : '$activeMachines active of $machineTotal linked';

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
          onTap: () => context.pushNamed('developer'),
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
