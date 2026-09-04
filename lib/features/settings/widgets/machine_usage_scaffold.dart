import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_empty_state.dart';
import '../../../core/components/app_loading_indicator.dart';
import '../../../core/components/settings_section.dart';
import '../../../core/models/machine.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/opentelemetry_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'machine_picker.dart';

/// Outcome of one machine fetch round: either [data] or an [error]
/// message suitable for the blocking error state.
class MachineUsageSnapshot<T> {
  const MachineUsageSnapshot.data(this.data) : error = null;
  const MachineUsageSnapshot.error(this.error) : data = null;

  final T? data;
  final String? error;
}

/// Fetches the report shown for the selected machine. Resolve with
/// [MachineUsageSnapshot.error] to surface the blocking error state
/// (picker + retry); any side fetch whose failure must not block the
/// report stays inside the screen instead.
typedef MachineUsageFetcher<T> =
    Future<MachineUsageSnapshot<T>> Function(String machineId);

/// Builds the section widgets rendered below the machine picker once the
/// selected machine's report is available.
typedef MachineUsageContentBuilder<T> =
    List<Widget> Function(BuildContext context, T data);

/// Builds AppBar actions with access to the scaffold's reload affordances.
typedef MachineUsageActionsBuilder =
    List<Widget>? Function(MachineUsageController controller);

/// Reload surface handed to [MachineUsageScaffold.actionsBuilder].
abstract interface class MachineUsageController {
  /// Currently selected machine, or null before auto-selection ran or
  /// when no machine is online.
  String? get selectedMachineId;

  /// Re-runs the fetch round for [selectedMachineId]. No-op when no
  /// machine is selected.
  Future<void> refresh();
}

/// Scaffold shared by the machine-scoped usage screens (Claude limits,
/// Codex usage, Grok usage).
///
/// Owns everything those screens used to duplicate:
///
/// * online-machine auto-selection ([compareMachinesByAvailabilityAt],
///   first online machine) in a microtask after init,
/// * the fetch lifecycle — loading indicator, blocking error body with
///   retry, "not available" empty body, loaded content,
/// * the [MachinePicker] row (pinned above every state via
///   [MachineScopedEmptyBody] so a broken machine can always be switched),
/// * pull-to-refresh on the loaded list and the [AppBar] pattern.
///
/// Screens provide [fetch], localized copy, and a [contentBuilder] that
/// returns their sections below the picker.
class MachineUsageScaffold<T> extends ConsumerStatefulWidget {
  const MachineUsageScaffold({
    required this.title,
    required this.pickerTitle,
    required this.noMachinesIcon,
    required this.noMachinesTitle,
    required this.noMachinesSubtitle,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.operationName,
    required this.fetch,
    required this.contentBuilder,
    this.actionsBuilder,
    super.key,
  });

  final String title;
  final String pickerTitle;

  /// Empty-state copy shown when there are no machines at all.
  final IconData noMachinesIcon;
  final String noMachinesTitle;
  final String noMachinesSubtitle;

  /// Copy for the "selected machine has no data" body (also used as the
  /// title of the blocking error body).
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final String operationName;

  final MachineUsageFetcher<T> fetch;
  final MachineUsageContentBuilder<T> contentBuilder;
  final MachineUsageActionsBuilder? actionsBuilder;

  @override
  ConsumerState<MachineUsageScaffold<T>> createState() =>
      _MachineUsageScaffoldState<T>();
}

class _MachineUsageScaffoldState<T>
    extends ConsumerState<MachineUsageScaffold<T>>
    implements MachineUsageController {
  String? _selectedMachineId;
  T? _report;
  bool _isLoading = false;
  String? _error;

  @override
  String? get selectedMachineId => _selectedMachineId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_autoSelectMachine);
  }

  void _autoSelectMachine() {
    final machineSortNow = DateTime.now().millisecondsSinceEpoch;
    final machines = ref.read(machinesNotifierProvider).values.toList()
      ..sort((a, b) => compareMachinesByAvailabilityAt(machineSortNow, a, b));
    final online = machines.where((machine) => machine.isOnline).toList();
    final target = online.isNotEmpty ? online.first : null;
    if (target != null) {
      setState(() => _selectedMachineId = target.id);
      unawaited(_load(target.id));
    }
  }

  Future<void> _load(String machineId) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _report = null;
    });

    final stopwatch = Stopwatch()..start();
    MachineUsageSnapshot<T> snapshot;
    try {
      snapshot = await widget.fetch(machineId);
    } catch (_) {
      OpenTelemetryService().recordDuration(
        'app.operation',
        stopwatch.elapsed,
        attributes: {'operation': widget.operationName, 'outcome': 'exception'},
      );
      rethrow;
    }
    OpenTelemetryService().recordDuration(
      'app.operation',
      stopwatch.elapsed,
      attributes: {
        'operation': widget.operationName,
        'outcome': snapshot.error == null ? 'ok' : 'error',
      },
    );
    if (!mounted) return;

    setState(() {
      if (snapshot.error != null) {
        _error = snapshot.error;
        _report = null;
      } else {
        _report = snapshot.data;
        _error = null;
      }
      _isLoading = false;
    });
  }

  void _onMachineChanged(String? id) {
    setState(() => _selectedMachineId = id);
    if (id != null) {
      unawaited(_load(id));
    }
  }

  @override
  Future<void> refresh() {
    final machineId = _selectedMachineId;
    if (machineId == null) return Future<void>.value();
    return _load(machineId);
  }

  @override
  Widget build(BuildContext context) {
    final machines = ref.watch(machinesNotifierProvider);

    if (machines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: AppEmptyState(
          icon: widget.noMachinesIcon,
          title: widget.noMachinesTitle,
          subtitle: widget.noMachinesSubtitle,
        ),
      );
    }

    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: widget.actionsBuilder?.call(this),
      ),
      body: _isLoading
          ? const AppLoadingIndicator()
          : _error != null
          ? MachineScopedEmptyBody(
              machines: machines,
              selectedMachineId: _selectedMachineId,
              onMachineChanged: _onMachineChanged,
              pickerTitle: widget.pickerTitle,
              icon: Icons.error_outline,
              title: widget.emptyTitle,
              subtitle: _error!,
              onRetry: refresh,
            )
          : report != null
          ? RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                padding: AppScreenPadding.settings,
                children: [
                  MachinePicker(
                    machines: machines,
                    selectedMachineId: _selectedMachineId,
                    onChanged: _onMachineChanged,
                    sectionTitle: widget.pickerTitle,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ...widget.contentBuilder(context, report),
                ],
              ),
            )
          : MachineScopedEmptyBody(
              machines: machines,
              selectedMachineId: _selectedMachineId,
              onMachineChanged: _onMachineChanged,
              pickerTitle: widget.pickerTitle,
              icon: widget.emptyIcon,
              title: widget.emptyTitle,
              subtitle: widget.emptySubtitle,
            ),
    );
  }
}

/// Icon-led label/value stat row shared by the Codex and Grok usage
/// sections.
class UsageStatRow extends StatelessWidget {
  const UsageStatRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.iconColor,
    this.flexValue = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;

  /// Wrap the value in a [Flexible] with end alignment so long values
  /// stay on one line instead of overflowing (Grok variant). Codex lets
  /// the value size itself.
  final bool flexValue;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final valueText = Text(
      value,
      textAlign: flexValue ? TextAlign.end : null,
      style: textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(title, style: textTheme.bodyMedium)),
          if (flexValue) Flexible(child: valueText) else valueText,
        ],
      ),
    );
  }
}

/// Label/value stat row led by a [SettingsIconContainer]-style icon tile —
/// the Claude limits variant.
class ContainerUsageStatRow extends StatelessWidget {
  const ContainerUsageStatRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.iconColor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SettingsIconContainer(icon: icon, color: iconColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Utilization window row: header (optional icon, title, percent), a
/// progress bar coloured by threshold (red ≥90%, amber ≥70%, green
/// below), and an optional footer line.
///
/// The colour thresholds and bar geometry were copy-pasted across the
/// Claude limits, Codex usage, and Grok usage screens; this is the single
/// definition.
class UsageWindowRow extends StatelessWidget {
  const UsageWindowRow({
    required this.title,
    required this.percent,
    this.icon,
    this.iconColor,
    this.footer,
    this.emphasizedTitle = true,
    this.percentUsesBarColor = true,
    this.dense = true,
    super.key,
  });

  final String title;

  /// Utilization percentage (0–100 scale; clamped internally).
  final double percent;

  /// Optional small leading icon (Codex/Grok style).
  final IconData? icon;
  final Color? iconColor;

  /// Pre-styled footer line (reset countdown, used/limit summary, …).
  final Widget? footer;

  /// Claude/Codex render the title semi-bold; Grok uses the default weight.
  final bool emphasizedTitle;

  /// Claude/Codex colour the percent with the bar colour; Grok uses
  /// [ColorScheme.onSurface].
  final bool percentUsesBarColor;

  /// Claude/Codex use the tighter spacing cluster; Grok the roomier one.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final safePercent = percent.clamp(0, 100);
    final fraction = safePercent / 100.0;

    final Color barColor;
    if (safePercent >= 90) {
      barColor = AppColors.error;
    } else if (safePercent >= 70) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.success;
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: dense ? AppSpacing.smd : AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: emphasizedTitle ? FontWeight.w500 : null,
                  ),
                ),
              ),
              Text(
                '${safePercent.toStringAsFixed(0)}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: percentUsesBarColor ? barColor : cs.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: dense ? AppSpacing.xs : AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          if (footer != null) ...[
            SizedBox(height: dense ? AppSpacing.xxs : AppSpacing.xs),
            footer!,
          ],
        ],
      ),
    );
  }
}
