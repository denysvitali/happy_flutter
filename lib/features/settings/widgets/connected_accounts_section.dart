import 'package:flutter/material.dart';

import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/profile.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Loads connected services once in initState to avoid re-fetching on
/// rebuild.
class ConnectedServicesLoader extends StatefulWidget {
  const ConnectedServicesLoader({super.key, this.loadServices});

  final Future<List<ConnectedServiceInfo>> Function()? loadServices;

  @override
  State<ConnectedServicesLoader> createState() =>
      _ConnectedServicesLoaderState();
}

class _ConnectedServicesLoaderState extends State<ConnectedServicesLoader> {
  late final Future<List<ConnectedServiceInfo>> _future;

  @override
  void initState() {
    super.initState();
    _future =
        widget.loadServices?.call() ?? AuthService().getConnectedServices();
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
    return SettingsRow(
      icon: _getServiceIcon(),
      iconColor: _getServiceColor(cs),
      title: service.service.displayName,
      subtitle: service.isConnected
          ? service.accountName ?? service.accountEmail ?? 'Connected'
          : context.l10n.accountNotConnected,
      trailing: service.isConnected
          ? Icon(Icons.check_circle, color: cs.primary, size: AppSpacing.xl)
          : Icon(
              Icons.circle_outlined,
              size: AppSpacing.xl,
              color: cs.onSurface.withValues(alpha: AppOpacity.medium),
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
                title: Text(context.l10n.accountName),
                subtitle: Text(service.accountName!),
              ),
            if (service.accountEmail != null)
              ListTile(
                title: Text(context.l10n.accountEmail),
                subtitle: Text(service.accountEmail!),
              ),
            if (service.connectedAt != null)
              ListTile(
                title: Text(context.l10n.accountName),
                subtitle: Text(service.connectedAt!.toLocal().toString()),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonClose),
          ),
        ],
      ),
    );
  }
}
