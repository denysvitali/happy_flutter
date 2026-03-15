import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/components/app_card.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)
              .claudeConnectCliInfo,
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.claudeConnectTitle),
      ),
      body: SingleChildScrollView(
        padding: AppScreenPadding.settings,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(
                    AppRadius.lg,
                  ),
                ),
                padding: const EdgeInsets.all(
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4EC94E)
                                .withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(
                              AppRadius.sm,
                            ),
                          ),
                          child: const Icon(
                            Icons.terminal_rounded,
                            size: 16,
                            color: Color(0xFF4EC94E),
                          ),
                        ),
                        const SizedBox(
                          width: AppSpacing.sm,
                        ),
                        Expanded(
                          child: Text(
                            l10n
                                .claudeConnectTerminalTitle,
                            style: theme
                                .textTheme.titleMedium
                                ?.copyWith(
                              color: const Color(
                                0xFFD4D4D4,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: AppSpacing.sm,
                    ),
                    Text(
                      l10n
                          .claudeConnectTerminalSubtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(
                        color: const Color(0xFF9E9E9E),
                      ),
                    ),
                    const SizedBox(
                      height: AppSpacing.md,
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.smd,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D2D),
                        borderRadius:
                            BorderRadius.circular(
                          AppRadius.xs,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Text(
                            r'$ ',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: AppFontSize.base,
                              color: Color(0xFF4EC94E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'happy connect claude',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: AppFontSize.base,
                              color: Color(0xFFD4D4D4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Divider(color: cs.outlineVariant),
            const SizedBox(height: AppSpacing.xxl),
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xs,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                l10n.claudeConnectManualLabel
                    .toUpperCase(),
                style:
                    theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xs,
                bottom: AppSpacing.md,
              ),
              child: Text(
                l10n.claudeConnectManualDesc,
                style:
                    theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText:
                    l10n.claudeConnectApiKeyLabel,
                hintText:
                    l10n.claudeConnectApiKeyHint,
                border: const OutlineInputBorder(),
                prefixIcon:
                    const Icon(Icons.key_outlined),
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
            TextField(
              controller: _baseUrlController,
              decoration: InputDecoration(
                labelText:
                    l10n.claudeConnectBaseUrlLabel,
                hintText:
                    l10n.claudeConnectBaseUrlHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton.icon(
              onPressed: _handleConnect,
              icon: const Icon(
                Icons.smart_toy_outlined,
              ),
              label: Text(l10n.claudeConnectButton),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: Text(
                l10n.claudeConnectDisclaimer,
                textAlign: TextAlign.center,
                style:
                    theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
