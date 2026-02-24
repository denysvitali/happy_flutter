import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';

/// Features settings screen
class FeaturesSettingsScreen extends ConsumerWidget {
  const FeaturesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.featuresTitle),
      ),
      body: const SizedBox.shrink(),
    );
  }
}
