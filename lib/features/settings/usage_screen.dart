import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';

/// Usage screen - Token usage, costs, limits display
class UsageScreen extends ConsumerWidget {
  const UsageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Usage data - in a real app this would come from the API
    final usage = _MockUsageData();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Token usage card
          _buildUsageCard(
            context: context,
            title: 'Token Usage',
            items: [
              _UsageItem(
                label: 'Input Tokens',
                value: usage.inputTokens,
                limit: usage.inputTokenLimit,
              ),
              _UsageItem(
                label: 'Output Tokens',
                value: usage.outputTokens,
                limit: usage.outputTokenLimit,
              ),
              _UsageItem(
                label: 'Total Tokens',
                value: usage.inputTokens + usage.outputTokens,
                limit: usage.totalTokenLimit,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Cost breakdown
          _buildUsageCard(
            context: context,
            title: 'Cost Breakdown',
            items: [
              _UsageItem(label: 'Anthropic (Claude)', value: usage.claudeCost),
              _UsageItem(label: 'OpenAI', value: usage.openaiCost),
              _UsageItem(label: 'Google (Gemini)', value: usage.geminiCost),
            ],
          ),
          const SizedBox(height: 16),
          // Summary
          _buildSummaryCard(
            context: context,
            totalCost: usage.totalCost,
            remainingCredits: usage.remainingCredits,
            period: usage.period,
          ),
          const SizedBox(height: 16),
          // API Limits
          _buildLimitsCard(context, usage),
        ],
      ),
    );
  }

  Widget _buildUsageCard({
    required BuildContext context,
    required String title,
    required List<_UsageItem> items,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.label),
                        if (item.limit != null)
                          Text(
                            '${_formatNumber(item.value)} / ${_formatNumber(item.limit!)}',
                            style: const TextStyle(color: Colors.grey),
                          )
                        else
                          Text(
                            _formatCurrency(item.value),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                    if (item.limit != null)
                      LinearProgressIndicator(
                        value: (item.value / item.limit!).clamp(0, 1),
                        minHeight: 4,
                      ),
                    const SizedBox(height: 8),
                  ],
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required double totalCost,
    required double remainingCredits,
    required String period,
  }) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Cost ($period)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  _formatCurrency(totalCost),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Remaining Credits'),
                Text(
                  _formatCurrency(remainingCredits),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitsCard(BuildContext context, _MockUsageData usage) {
    return Card(
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ListTile(
            title: const Text('API Rate Limits'),
            subtitle: const Text('Requests per minute'),
            trailing: Text('${usage.requestsPerMinute} / min'),
          ),
          ListTile(
            title: const Text('Concurrent Sessions'),
            subtitle: const Text('Maximum active sessions'),
            trailing: Text('${usage.maxConcurrentSessions}'),
          ),
          ListTile(
            title: const Text('Token Context Window'),
            subtitle: const Text('Maximum context tokens'),
            trailing: Text('${_formatNumber(usage.maxContextTokens)}'),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  String _formatCurrency(num value) {
    return '\$${value.toStringAsFixed(2)}';
  }
}

class _UsageItem {
  final String label;
  final num value;
  final int? limit;

  _UsageItem({required this.label, required this.value, this.limit});
}

class _MockUsageData {
  final int inputTokens = 1250000;
  final int outputTokens = 320000;
  final int inputTokenLimit = 2000000;
  final int outputTokenLimit = 500000;
  final int totalTokenLimit = 2500000;

  final double claudeCost = 45.67;
  final double openaiCost = 12.34;
  final double geminiCost = 8.90;
  final double totalCost = 66.91;
  final double remainingCredits = 133.09;
  final String period = 'January 2026';

  final int requestsPerMinute = 60;
  final int maxConcurrentSessions = 5;
  final int maxContextTokens = 200000;
}
