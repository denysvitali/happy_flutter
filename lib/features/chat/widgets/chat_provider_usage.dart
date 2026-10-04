import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/components/app_inline_row.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/claude_usage_limits.dart';
import '../../../core/models/settings.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_linear_progress_indicator.dart';
import '../model_selection_resolver.dart';

/// Only known official configurations can report these machine account limits.
String? officialUsageFlavor(String? flavor, AIBackendProfile? profile) {
  if (flavor == 'codex' && profile == null) return 'codex';
  if ((flavor == null || flavor == 'claude') &&
      (profile == null ||
          (profile.isBuiltIn &&
              profile.id == 'anthropic' &&
              !profileUsesThirdPartyAnthropicBaseUrl(profile)))) {
    return 'claude';
  }
  return null;
}

class ChatUsageWindow {
  const ChatUsageWindow(this.label, this.percent, {this.resetsAt});

  final String label;
  final double percent;
  final DateTime? resetsAt;
}

typedef ChatUsageFetcher =
    Future<List<ChatUsageWindow>> Function(String machineId, String flavor);

Future<List<ChatUsageWindow>> fetchChatProviderUsage(
  String machineId,
  String flavor,
) async {
  final sync = Sync();
  if (!sync.isInitialized) throw StateError('Usage unavailable');
  final credentials = sync.credentials;
  final windows = <ChatUsageWindow>[];
  if (flavor == 'codex') {
    final response = await sync.machineGetCodexUsage(machineId: machineId);
    if (!response.success) throw StateError('Usage unavailable');
    final limits = response.data?.rateLimit;
    for (final (label, window) in [
      ('primary', limits?.primaryWindow),
      ('secondary', limits?.secondaryWindow),
    ]) {
      if (window == null) continue;
      windows.add(
        ChatUsageWindow(
          switch (window.limitWindowSeconds) {
            18000 => '5-Hour',
            604800 => '7-Day',
            _ => label,
          },
          window.usedPercent.toDouble(),
          resetsAt: window.expiresAt,
        ),
      );
    }
  } else {
    final response = await sync.machineGetClaudeUsageLimits(
      machineId: machineId,
    );
    if (!response.success || response.data == null) {
      throw StateError('Usage unavailable');
    }
    final limits = ClaudeUsageLimits.fromJson(
      jsonDecode(response.data!) as Map<String, dynamic>,
    );
    for (final (label, window) in limits.activeWindows) {
      windows.add(
        ChatUsageWindow(
          label,
          window.utilization,
          resetsAt: DateTime.tryParse(window.resetsAt ?? ''),
        ),
      );
    }
  }
  // Account replacement must not publish a previous account's limits.
  if (!sync.isInitialized || !identical(credentials, sync.credentials)) {
    throw StateError('Account changed');
  }
  return windows;
}

/// A small live account-limit strip independent of transcript/composer state.
class ChatProviderUsage extends StatefulWidget {
  const ChatProviderUsage({
    required this.machineId,
    required this.flavor,
    required this.onTap,
    this.fetch = fetchChatProviderUsage,
    super.key,
  });

  final String machineId;
  final String flavor;
  final VoidCallback onTap;
  final ChatUsageFetcher fetch;

  @override
  State<ChatProviderUsage> createState() => _ChatProviderUsageState();
}

class _ChatProviderUsageState extends State<ChatProviderUsage>
    with WidgetsBindingObserver {
  Timer? _timer;
  List<ChatUsageWindow> _windows = const [];
  bool _failed = false;
  bool _visible = false;
  bool _inFlight = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateVisibility();
  }

  @override
  void didUpdateWidget(ChatProviderUsage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.machineId != widget.machineId ||
        oldWidget.flavor != widget.flavor ||
        oldWidget.fetch != widget.fetch) {
      _generation++;
      _inFlight = false;
      _windows = const [];
      _failed = false;
      if (_visible) unawaited(_refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _updateVisibility();
  }

  void _updateVisibility() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final visible =
        TickerMode.valuesOf(context).enabled &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    if (visible == _visible) return;
    _visible = visible;
    _timer?.cancel();
    if (visible) {
      unawaited(_refresh());
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        unawaited(_refresh());
      });
    } else {
      _generation++;
      _inFlight = false;
    }
  }

  Future<void> _refresh() async {
    if (_inFlight || !_visible) return;
    _inFlight = true;
    final generation = _generation;
    try {
      final windows = await widget.fetch(widget.machineId, widget.flavor);
      if (!mounted || generation != _generation) return;
      setState(() {
        _windows = windows;
        _failed = windows.isEmpty;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _failed = true);
    } finally {
      if (generation == _generation) _inFlight = false;
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final title = widget.flavor == 'codex'
        ? l10n.codexUsageTitle
        : l10n.claudeLimitsTitle;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: AppInlineRow(
          onTap: widget.onTap,
          leading: Tooltip(
            message: title,
            child: const Icon(Icons.speed, size: AppIconSize.md),
          ),
          trailing: const Icon(Icons.chevron_right, size: AppIconSize.sm),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_windows.isEmpty)
                  Text(
                    _failed
                        ? (widget.flavor == 'codex'
                              ? l10n.codexUsageNotAvailable
                              : l10n.claudeLimitsNotAvailable)
                        : title,
                    style: AppText.secondary(theme),
                    maxLines: 1,
                  ),
                if (_failed && _windows.isNotEmpty) ...[
                  Text(
                    l10n.providersUsageStale,
                    style: AppText.secondary(theme),
                    maxLines: 1,
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                for (var i = 0; i < _windows.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  _window(context, _windows[i]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _window(BuildContext context, ChatUsageWindow window) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final percent = window.percent.clamp(0, 100);
    final label = switch (window.label) {
      '5-Hour' => l10n.codexUsageFiveHourWindow,
      '7-Day' => l10n.codexUsageWeeklyWindow,
      'primary' => l10n.codexUsagePrimaryWindow,
      'secondary' => l10n.codexUsageSecondaryWindow,
      _ => window.label,
    };
    final reset = window.resetsAt;
    final tooltip = reset == null
        ? label
        : l10n.codexUsageResetsAt(
            DateFormat.yMMMd(
              Localizations.localeOf(context).toLanguageTag(),
            ).add_jm().format(reset.toLocal()),
          );
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.secondary(theme), maxLines: 1),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: AppText.badge(
              theme,
              percent >= 90 ? theme.colorScheme.error : null,
            ),
            maxLines: 1,
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: AppSpacing.xl,
            child: AppLinearProgressIndicator(
              value: percent / 100,
              minHeight: 3,
              color: percent >= 90
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              semanticsLabel: label,
            ),
          ),
        ],
      ),
    );
  }
}
