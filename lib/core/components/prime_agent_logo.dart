import 'package:flutter/material.dart';

/// Official Prime Intellect mark used by Prime Agent.
/// Source: https://www.primeintellect.ai/icons/logo-icon.png
class PrimeAgentLogo extends StatelessWidget {
  const PrimeAgentLogo({required this.size, super.key});

  static const assetPath = 'assets/images/icon-prime-agent.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipOval(
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        fit: BoxFit.contain,
      ),
    );
  }
}
