import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_terminal_colors.dart';
import '../../core/theme/app_tokens.dart'
    show AppFontSize, AppIconSize, AppSpacing, AppBorder, AppDuration,
        AppCurve, AppTouchTarget;
import '../../core/utils/ansi_parser.dart';
import '../../core/routing/safe_pop.dart';

/// Terminal emulator screen — displays terminal output with a dark
/// background and allows entering commands.
///
/// Expects `GoRouterState.extra` to be a `Map<String, dynamic>` with
/// `machineId` (String) and `terminalId` (String) keys, provided by
/// [TerminalConnectScreen].
class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  late final List<String> lines;
  final _commandController = TextEditingController();
  final _scrollController = ScrollController();
  String? _machineId;
  String? _cwd;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    lines = [context.l10n.terminalConnected];
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    _machineId = extra?['machineId'] as String?;
    _cwd = extra?['cwd'] as String? ?? '/';
  }

  static final _terminalTextStyle = TextStyle(
    fontFamily: 'monospace',
    fontSize: AppFontSize.md,
    color: AppTerminalColors.dark.foreground,
    height: 1.5,
  );

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppDuration.fast,
          curve: AppCurve.enter,
        );
      }
    });
  }

  Future<void> _submitCommand(String command) async {
    final trimmed = command.trim();
    if (trimmed.isEmpty || _isSending) return;

    setState(() {
      lines.add('> $trimmed');
      _isSending = true;
    });
    _commandController.clear();
    _scrollToBottom();

    final machineId = _machineId;
    if (machineId == null || machineId.isEmpty) {
      setState(() {
        lines.add('[No machine connected]');
        _isSending = false;
      });
      _scrollToBottom();
      return;
    }

    try {
      final result = await ref
          .read(machinesNotifierProvider.notifier)
          .bash(
            machineId: machineId,
            command: trimmed,
            cwd: _cwd ?? '/',
          );
      final stdout = result.stdout.trim();
      final stderr = result.stderr.trim();
      setState(() {
        if (stdout.isNotEmpty) lines.addAll(stdout.split('\n'));
        if (stderr.isNotEmpty) lines.addAll(stderr.split('\n'));
        if (stdout.isEmpty && stderr.isEmpty) lines.add('');
      });
    } catch (e) {
      setState(() => lines.add('[Error: $e]'));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
    _scrollToBottom();
  }

  void _confirmDisconnect() {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.terminalDisconnect),
        content: Text(context.l10n.terminalDisconnectConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.terminalDisconnect),
          ),
        ],
      ),
    ).then((confirmed) {
      if ((confirmed ?? false) && mounted) {
        safePop<void>(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // Resolved once per build so every nested widget reads the same
    // palette. The extension is registered in ThemeHelper so it's
    // guaranteed to be present.
    final term = Theme.of(context).extension<AppTerminalColors>()!;

    return Scaffold(
      backgroundColor: term.background,
      appBar: AppBar(
        backgroundColor: term.surface,
        foregroundColor: term.foreground,
        title: Row(
          children: [
            const Icon(Icons.terminal, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text(context.l10n.terminalTitle),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: IconButton(
              icon: const Icon(Icons.power_settings_new),
              tooltip: context.l10n.terminalDisconnect,
              onPressed: _confirmDisconnect,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Terminal output area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              itemCount: lines.length,
              itemBuilder: (context, index) {
                final line = lines[index];
                final isCommand = line.startsWith('> ');
                return RepaintBoundary(
                  key: ValueKey(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxs,
                    ),
                    child: isCommand
                        ? Text(
                            line,
                            style: _terminalTextStyle.copyWith(
                              color: term.commandText,
                            ),
                          )
                        : SelectableText.rich(
                            TextSpan(
                              children: AnsiParser.parse(
                                line,
                                defaultStyle: _terminalTextStyle,
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),

          // Command input bar
          Container(
            decoration: BoxDecoration(
              color: term.surface,
              border: Border(
                top: BorderSide(
                  color: term.border,
                  width: AppBorder.hairline,
                ),
              ),
            ),
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.sm,
              top: AppSpacing.sm,
              bottom: AppSpacing.sm + bottomInset,
            ),
            child: Row(
              children: [
                Text(
                  r'$ ',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.base,
                    color: term.commandPrompt,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    style: _terminalTextStyle,
                    enabled: !_isSending,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: context.l10n.terminalEnterCommand,
                      hintStyle: TextStyle(
                        color: term.hint,
                        fontFamily: 'monospace',
                        fontSize: AppFontSize.md,
                        fontStyle: FontStyle.italic,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                    ),
                    cursorColor: term.cursor,
                    textInputAction: TextInputAction.send,
                    autocorrect: false,
                    onSubmitted: _isSending ? null : _submitCommand,
                  ),
                ),
                if (_isSending)
                  SizedBox(
                    width: AppTouchTarget.min,
                    height: AppTouchTarget.min,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.smd),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: term.accent,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: AppTouchTarget.min,
                    height: AppTouchTarget.min,
                    child: IconButton(
                      icon: Icon(
                        Icons.send,
                        color: term.commandPrompt,
                        size: AppIconSize.xl,
                      ),
                      onPressed: () => _submitCommand(_commandController.text),
                      tooltip: context.l10n.terminalSendCommand,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
