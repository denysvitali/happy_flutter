import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/settings_section.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Debug screen for testing and inspecting push notification configuration.
class NotificationTestScreen extends ConsumerStatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  ConsumerState<NotificationTestScreen> createState() =>
      _NotificationTestScreenState();
}

class _NotificationTestScreenState
    extends ConsumerState<NotificationTestScreen> {
  String? _fcmToken;
  AuthorizationStatus? _authStatus;
  String? _apnsToken;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotificationInfo();
  }

  Future<void> _loadNotificationInfo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final messaging = FirebaseMessaging.instance;

      // Get notification settings
      final settings = await messaging.getNotificationSettings();

      // Get FCM token
      String? token;
      try {
        token = await messaging.getToken();
      } catch (e) {
        logger.warning('Failed to get FCM token', e);
      }

      // Get APNS token (iOS only)
      String? apns;
      try {
        apns = await messaging.getAPNSToken();
      } catch (e) {
        // Not available on Android
      }

      if (mounted) {
        setState(() {
          _authStatus = settings.authorizationStatus;
          _fcmToken = token;
          _apnsToken = apns;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _requestPermission() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();

      if (mounted) {
        setState(() {
          _authStatus = settings.authorizationStatus;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Permission: ${settings.authorizationStatus.name}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _refreshToken() async {
    try {
      // Delete and re-generate token
      await FirebaseMessaging.instance.deleteToken();
      final token = await FirebaseMessaging.instance.getToken();

      if (mounted) {
        setState(() {
          _fcmToken = token;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token refreshed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _copyToken(String? token) {
    if (token == null) return;
    Clipboard.setData(ClipboardData(text: token));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Token copied')),
    );
  }

  static String _truncateToken(String token) {
    if (token.length <= 30) return token;
    return '${token.substring(0, 20)}...'
        '${token.substring(token.length - 10)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification Test')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadNotificationInfo,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        children: [
          if (_error != null) ...[
            Card(
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.error, color: cs.onErrorContainer),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Authorization
          SettingsSection(
            title: 'Authorization',
            children: [
              _InfoRow(
                icon: Icons.shield,
                label: 'Status',
                value: _authStatus?.name ?? 'Unknown',
                valueColor: _authColor(_authStatus, cs),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.perm_device_info),
                    label: const Text('Request Permission'),
                    onPressed: _requestPermission,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // FCM Token
          SettingsSection(
            title: 'FCM Token',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.token,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Token',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        if (_fcmToken != null)
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () => _copyToken(_fcmToken),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        _fcmToken != null
                            ? _truncateToken(_fcmToken!)
                            : 'No token available',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Token'),
                    onPressed: _refreshToken,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // APNS Token (iOS)
          SettingsSection(
            title: 'APNS Token (iOS)',
            children: [
              _InfoRow(
                icon: Icons.phone_iphone,
                label: 'Token',
                value: _apnsToken != null
                    ? '${_apnsToken!.substring(0, 16)}...'
                    : 'Not available',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Debug Actions
          SettingsSection(
            title: 'Debug Actions',
            children: [
              _ActionRow(
                icon: Icons.send,
                title: 'Log token to console',
                subtitle: 'Print FCM token to debug logs',
                onTap: () {
                  logger
                    ..info('FCM Token: $_fcmToken')
                    ..info('APNS Token: $_apnsToken')
                    ..info('Auth status: ${_authStatus?.name}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Token info logged'),
                    ),
                  );
                },
              ),
              _ActionRow(
                icon: Icons.copy_all,
                title: 'Copy all info',
                subtitle: 'Copy notification debug info',
                onTap: () {
                  final buffer = StringBuffer()
                    ..writeln('=== Notification Debug Info ===')
                    ..writeln('Auth status: ${_authStatus?.name}')
                    ..writeln('FCM Token: ${_fcmToken ?? 'N/A'}')
                    ..writeln('APNS Token: ${_apnsToken ?? 'N/A'}')
                    ..writeln(
                      'Sync registered token: '
                      '${sync.isInitialized ? 'Yes' : 'No'}',
                    );

                  Clipboard.setData(
                    ClipboardData(text: buffer.toString()),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notification info copied'),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Color _authColor(AuthorizationStatus? status, ColorScheme cs) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return AppColors.success;
      case AuthorizationStatus.denied:
        return cs.error;
      case AuthorizationStatus.notDetermined:
        return AppColors.warning;
      default:
        return cs.onSurfaceVariant;
    }
  }
}

/// A simple row showing a label and value with an icon.
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

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor ?? cs.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// An action row with icon, title, subtitle, and onTap handler.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
