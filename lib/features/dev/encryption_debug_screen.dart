import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/settings_section.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/clipboard_utils.dart';

/// Debug screen showing encryption status and configuration.
class EncryptionDebugScreen extends ConsumerWidget {
  const EncryptionDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final syncInitialized = sync.isInitialized;

    // Gather encryption info from sync singleton
    final sessionCount = sync.sessions.length;
    final machineCount = sync.machines.length;
    final artifactCount = sync.artifacts.length;

    // Encryption cache stats
    final cacheStats = syncInitialized
        ? sync.encryption.getCacheStats()
        : <String, int>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Encryption Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy debug info',
            onPressed: () => _copyDebugInfo(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        children: [
          // Encryption Status
          SettingsSection(
            title: 'Status',
            children: [
              _InfoRow(
                icon: Icons.power,
                label: 'Encryption initialized',
                value: syncInitialized ? 'Yes' : 'No',
                valueColor: syncInitialized ? AppColors.success : cs.error,
              ),
              if (syncInitialized) ...[
                _InfoRow(
                  icon: Icons.fingerprint,
                  label: 'Anonymous ID',
                  value: sync.anonID.isNotEmpty
                      ? '${sync.anonID.substring(0, 8)}...'
                      : 'N/A',
                ),
                _InfoRow(
                  icon: Icons.storage,
                  label: 'Server ID',
                  value: sync.serverID.isNotEmpty
                      ? '${sync.serverID.substring(0, 8)}...'
                      : 'N/A',
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Encryption Algorithms
          SettingsSection(
            title: 'Algorithms',
            children: [
              _InfoRow(
                icon: Icons.lock,
                label: 'Legacy',
                value: 'NaCl SecretBox (XSalsa20-Poly1305)',
              ),
              _InfoRow(
                icon: Icons.lock_outline,
                label: 'Sessions',
                value: 'AES-256-GCM',
              ),
              _InfoRow(
                icon: Icons.vpn_key,
                label: 'Key Derivation',
                value: 'HMAC-SHA512 (BIP32-like)',
              ),
              _InfoRow(
                icon: Icons.key,
                label: 'Key Exchange',
                value: 'NaCl CryptoBox (X25519-XSalsa20)',
              ),
              _InfoRow(
                icon: Icons.tag,
                label: 'AES-GCM Nonce',
                value: '12 bytes (IV)',
              ),
              _InfoRow(
                icon: Icons.verified,
                label: 'AES-GCM Auth Tag',
                value: '16 bytes',
              ),
              _InfoRow(
                icon: Icons.password,
                label: 'SecretBox Nonce',
                value: '24 bytes (libsodium)',
              ),
              _InfoRow(
                icon: Icons.key_off,
                label: 'Key Size',
                value: '256 bits (32 bytes)',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Data Key Counts
          SettingsSection(
            title: 'Data Keys',
            children: [
              _InfoRow(
                icon: Icons.chat,
                label: 'Sessions with keys',
                value: '$sessionCount',
              ),
              _InfoRow(
                icon: Icons.computer,
                label: 'Machines with keys',
                value: '$machineCount',
              ),
              _InfoRow(
                icon: Icons.description,
                label: 'Artifacts with keys',
                value: '$artifactCount',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Encryption Cache
          SettingsSection(
            title: 'Cache Stats',
            children: [
              _InfoRow(
                icon: Icons.cached,
                label: 'Agent states',
                value: '${cacheStats['agentStates'] ?? 0}',
              ),
              _InfoRow(
                icon: Icons.data_object,
                label: 'Metadata entries',
                value: '${cacheStats['metadata'] ?? 0}',
              ),
              _InfoRow(
                icon: Icons.message,
                label: 'Decrypted messages',
                value: '${cacheStats['messages'] ?? 0}',
              ),
              _InfoRow(
                icon: Icons.memory,
                label: 'Machine metadata',
                value: '${cacheStats['machineMetadata'] ?? 0}',
              ),
              _InfoRow(
                icon: Icons.settings,
                label: 'Daemon states',
                value: '${cacheStats['daemonStates'] ?? 0}',
              ),
              _InfoRow(
                icon: Icons.all_inbox,
                label: 'Total cached',
                value: '${cacheStats['totalEntries'] ?? 0}',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text('Clear caches'),
                    onPressed: () {
                      if (syncInitialized) {
                        ref
                            .read(encryptionNotifierProvider.notifier)
                            .clearAllCaches();
                        logger.info('Encryption caches cleared');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Encryption caches cleared'),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Cache Limits
          SettingsSection(
            title: 'Cache Limits',
            children: [
              _InfoRow(
                icon: Icons.format_list_numbered,
                label: 'Agent states max',
                value: '1000',
              ),
              _InfoRow(
                icon: Icons.format_list_numbered,
                label: 'Metadata max',
                value: '1000',
              ),
              _InfoRow(
                icon: Icons.format_list_numbered,
                label: 'Messages max',
                value: '1000',
              ),
              _InfoRow(
                icon: Icons.format_list_numbered,
                label: 'Machine metadata max',
                value: '500',
              ),
              _InfoRow(
                icon: Icons.format_list_numbered,
                label: 'Daemon states max',
                value: '500',
              ),
              _InfoRow(
                icon: Icons.auto_delete,
                label: 'Eviction policy',
                value: 'LRU (Least Recently Used)',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Future<void> _copyDebugInfo(BuildContext context) async {
    final syncInitialized = sync.isInitialized;
    final cacheStats = syncInitialized
        ? sync.encryption.getCacheStats()
        : <String, int>{};

    final buffer = StringBuffer()
      ..writeln('=== Encryption Debug Info ===')
      ..writeln('Initialized: $syncInitialized');

    if (syncInitialized) {
      buffer
        ..writeln('Anon ID: ${sync.anonID}')
        ..writeln('Server ID: ${sync.serverID}');
    }

    buffer
      ..writeln('')
      ..writeln('Algorithms:')
      ..writeln('  Legacy: NaCl SecretBox (XSalsa20-Poly1305)')
      ..writeln('  Sessions: AES-256-GCM')
      ..writeln('  Key Derivation: HMAC-SHA512 (BIP32-like)')
      ..writeln('  Key Exchange: NaCl CryptoBox (X25519-XSalsa20)')
      ..writeln('')
      ..writeln('Data Keys:')
      ..writeln('  Sessions: ${sync.sessions.length}')
      ..writeln('  Machines: ${sync.machines.length}')
      ..writeln('  Artifacts: ${sync.artifacts.length}')
      ..writeln('')
      ..writeln('Cache Stats:')
      ..writeln('  Agent states: ${cacheStats['agentStates'] ?? 0}')
      ..writeln('  Metadata: ${cacheStats['metadata'] ?? 0}')
      ..writeln('  Messages: ${cacheStats['messages'] ?? 0}')
      ..writeln('  Machine metadata: ${cacheStats['machineMetadata'] ?? 0}')
      ..writeln('  Daemon states: ${cacheStats['daemonStates'] ?? 0}')
      ..writeln('  Total: ${cacheStats['totalEntries'] ?? 0}');

    await setClipboardTextSafely(buffer.toString());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Encryption debug info copied')),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SettingsRow(
      icon: icon,
      title: label,
      iconColor: valueColor,
      trailing: Flexible(
        child: Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: valueColor ?? cs.onSurfaceVariant,
            fontFamily: 'monospace',
            fontSize: AppFontSize.md,
          ),
          textAlign: TextAlign.end,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
