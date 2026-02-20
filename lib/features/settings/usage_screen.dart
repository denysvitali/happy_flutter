import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/app_empty_state.dart';

/// Usage screen — token usage, costs, and limits display.
///
/// Currently shows a placeholder until the usage API is integrated.
class UsageScreen extends ConsumerWidget {
  const UsageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage'),
      ),
      body: const AppEmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'Usage data coming soon',
        subtitle:
            'Token usage, cost breakdowns, and API limits'
            ' will appear here once the feature is available.',
      ),
    );
  }
}
