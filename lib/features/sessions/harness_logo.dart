import 'package:flutter/material.dart';

import '../../core/components/prime_agent_logo.dart';

/// Shared harness identity for session badges and launch choices.
///
/// Brand assets are bundled from their publishers, not approximated with icons:
/// - Codex: openai/codex, skills/openai-docs/assets/openai.png (OpenAI mark).
/// - OpenCode: https://opencode.ai/favicon-96x96-v3.png
/// - Grok: https://grok.com/images/android-chrome-192x192.png
/// Existing Claude, Gemini, Pi and Prime assets retain their original marks.
/// Unknown harnesses use a neutral terminal, never another provider's brand.
class HarnessLogo extends StatelessWidget {
  const HarnessLogo({required this.flavor, required this.size, super.key});

  final String flavor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = switch (flavor) {
      'claude' => 'assets/images/icon-claude.png',
      'codex' => 'assets/images/icon-codex.png',
      'agy' || 'gemini' => 'assets/images/icon-gemini.png',
      'pi' => 'assets/images/icon-pi.png',
      'opencode' => 'assets/images/icon-opencode.png',
      'grok' || 'grok-build' => 'assets/images/icon-grok.png',
      _ => null,
    };
    final mark = flavor == 'prime-agent'
        ? PrimeAgentLogo(size: size)
        : asset != null
        ? Image.asset(
            asset,
            width: size,
            height: size,
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) => _fallback(context),
          )
        : _fallback(context);
    return Semantics(
      label: switch (flavor) {
        'claude' => 'Claude Code',
        'codex' => 'Codex',
        'opencode' => 'OpenCode',
        'agy' || 'gemini' => 'AgY',
        'prime-agent' => 'Prime Agent',
        'grok' || 'grok-build' => 'Grok',
        'har' => 'Har',
        _ => flavor,
      },
      image: true,
      child: SizedBox.square(dimension: size, child: mark),
    );
  }

  Widget _fallback(BuildContext context) => Icon(
    Icons.terminal_rounded,
    size: size,
    color: Theme.of(context).colorScheme.onSurface,
  );
}
