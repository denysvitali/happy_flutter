import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';

/// Claude API connect screen — allows entry of a Claude API key and
/// optional base URL override.
///
/// Full API key management is out of scope; this screen shows a command
/// hint matching the RN reference (happy connect claude).
class ClaudeConnectScreen extends ConsumerStatefulWidget {
  const ClaudeConnectScreen({super.key});

  @override
  ConsumerState<ClaudeConnectScreen> createState() =>
      _ClaudeConnectScreenState();
}

class _ClaudeConnectScreenState
    extends ConsumerState<ClaudeConnectScreen> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  bool _obscureApiKey = true;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  void _handleConnect() {
    // API key management is out of scope — show informational snackbar.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'API key management is handled via the CLI. '
          'Run: happy connect claude',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.claudeConnectTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Terminal command card (matches RN reference UX)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: Colors.white12,
                ),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect Claude',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFD4D4D4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Run the following command in your terminal:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          r'$ ',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            color: Color(0xFF4EC94E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'happy connect claude',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            color: Color(0xFFD4D4D4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            const Divider(),
            const SizedBox(height: AppSpacing.xxl),

            // Manual API key entry section
            Text(
              'MANUAL API KEY ENTRY',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Alternatively, enter your Anthropic API key directly.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // API key field
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-ant-...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.key_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureApiKey
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureApiKey = !_obscureApiKey;
                    });
                  },
                ),
              ),
              autocorrect: false,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Optional base URL field
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL (optional)',
                hintText: 'https://api.anthropic.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Connect button
            FilledButton.icon(
              onPressed: _handleConnect,
              icon: const Icon(Icons.smart_toy_outlined),
              label: const Text('Connect'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Disclaimer footer
            Text(
              'Your API key is stored locally on this device only.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
