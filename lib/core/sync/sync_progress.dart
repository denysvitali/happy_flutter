/// Progress update emitted during long-running sync operations.
class SyncProgress {
  const SyncProgress({required this.label, this.completed, this.total});

  final String label;
  final int? completed;
  final int? total;

  double? get fraction {
    final totalValue = total;
    final completedValue = completed;
    if (totalValue == null || totalValue <= 0 || completedValue == null) {
      return null;
    }
    return (completedValue / totalValue).clamp(0.0, 1.0);
  }

  String get displayText {
    final totalValue = total;
    final completedValue = completed;
    if (totalValue == null || completedValue == null || totalValue <= 0) {
      return label;
    }
    return '$label $completedValue/$totalValue';
  }
}
