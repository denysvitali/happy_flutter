import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/app_badge.dart';

/// Small pill label used to tag profile rows and preset suggestions
/// (e.g. "Built-in", "Custom", "Suggested").
class ProfilePill extends StatelessWidget {
  const ProfilePill({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppBadge(label: label, color: color);
  }
}
