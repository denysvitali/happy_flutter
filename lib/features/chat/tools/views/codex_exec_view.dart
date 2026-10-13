import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/app_badge.dart';
import 'package:happy_flutter/core/components/app_inline_row.dart';
import 'package:happy_flutter/core/components/tool_view_buttons.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/text_truncate.dart';
import 'package:happy_flutter/core/wire/wire_parsers.dart';

import '../../markdown/markdown_view.dart';
import '../codex_exec_result.dart';
import '../tool_view_helpers.dart' show mcpToolTextResult;

/// The attributed Markdown answer, independent of collapsed execution details.
class CodexExecAnswerView extends StatelessWidget {
  const CodexExecAnswerView({required this.result, super.key});

  final CodexExecResult result;

  @override
  Widget build(BuildContext context) {
    if (!result.hasAnswer) return const SizedBox.shrink();
    final answer = result.finalMessage!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInlineRow(
          leading: const Icon(Icons.smart_toy_outlined),
          action: ToolViewCopyButton(text: answer),
          child: Text('Codex', style: AppInlineText.title(context)),
        ),
        const SizedBox(height: AppSpacing.xs),
        SimpleMarkdownView(markdown: answer),
      ],
    );
  }
}

/// Prompt, configuration, execution metadata and optional Codex answer.
class CodexExecView extends StatelessWidget {
  const CodexExecView({required this.tool, super.key, this.showAnswer = true});

  final Map<String, dynamic> tool;
  final bool showAnswer;

  @override
  Widget build(BuildContext context) {
    final input = WireParsers.toolInput(tool);
    final result = CodexExecResult.tryParse(tool['result']);
    final prompt = _text(input['prompt']);
    final state = tool['state'];
    final failed =
        state == 'error' || (result?.exitCode != null && result!.exitCode != 0);
    final items = <Widget>[
      for (final (label, keys) in const [
        ('Model', ['model']),
        ('Working directory', ['cwd', 'workdir', 'working_directory']),
        ('Sandbox', ['sandbox']),
        ('Approval', ['approval-policy', 'approval_policy']),
        ('Reasoning effort', ['reasoning_effort', 'effort']),
      ])
        if (_field(input, keys) case final String value)
          _Detail(label: label, value: value),
      if (prompt != null) ...[
        AppInlineRow(
          leading: const Icon(Icons.notes_outlined),
          action: ToolViewCopyButton(text: prompt),
          child: const Text('Prompt'),
        ),
        _TextPreview(
          text: prompt,
          hint: 'Full prompt available via Copy or Raw JSON.',
        ),
      ],
      if (state == 'running')
        const _Status(icon: Icons.hourglass_empty, text: 'Codex is working…')
      else if (failed) ...[
        _Status(
          icon: Icons.error_outline,
          text: result?.exitCode == null
              ? 'Codex execution failed.'
              : 'Codex execution failed (exit ${result!.exitCode}).',
          error: true,
        ),
        if (result == null)
          if (_plainError(tool['result']) case final String text)
            _TextPreview(text: text, hint: 'Full error available in Raw JSON.'),
      ] else if (state == 'completed' && !(result?.hasAnswer ?? false))
        _Status(
          icon: Icons.info_outline,
          text: result == null
              ? 'No readable Codex answer. See Tool Details for the result.'
              : 'Codex completed without a final answer.',
        ),
      if (result != null) ...[
        _ExecutionMetadata(result: result),
        if (showAnswer && result.hasAnswer) CodexExecAnswerView(result: result),
      ],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          items[i],
        ],
      ],
    );
  }

  static String? _text(dynamic value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  static String? _field(Map<String, dynamic> input, List<String> keys) {
    for (final key in keys) {
      final value = _text(input[key]);
      if (value != null) return value;
    }
    return null;
  }

  static String? _plainError(dynamic result) {
    final text = mcpToolTextResult(result)?.trim();
    if (text == null || text.startsWith('{') || text.startsWith('[')) {
      return null;
    }
    return _text(text);
  }
}

class _ExecutionMetadata extends StatelessWidget {
  const _ExecutionMetadata({required this.result});

  final CodexExecResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            if (result.exitCode != null)
              AppBadge(
                label: 'Exit ${result.exitCode}',
                tone: result.exitCode == 0
                    ? AppBadgeTone.success
                    : AppBadgeTone.danger,
              ),
            if (result.elapsedMs != null)
              AppBadge(label: 'Elapsed ${_elapsed(result.elapsedMs!)}'),
            if (result.rawEventCount != null)
              AppBadge(label: '${result.rawEventCount} events'),
          ],
        ),
        for (final (label, value) in [
          ('Thread', result.threadId),
          ('Input tokens', result.inputTokens?.toString()),
          ('Cached input tokens', result.cachedInputTokens?.toString()),
          ('Output tokens', result.outputTokens?.toString()),
        ])
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: _Detail(label: label, value: value),
            ),
      ],
    );
  }

  static String _elapsed(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    }
    return '${(milliseconds / 1000).toStringAsFixed(1)} s';
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppInlineText.secondary(context)),
        _TextPreview(text: value, hint: 'Full value available in Raw JSON.'),
      ],
    );
  }
}

class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.text, required this.hint});

  final String text;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final preview = truncateGraphemes(text, 4000);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(preview, style: Theme.of(context).textTheme.bodyMedium),
        if (preview != text)
          Text(hint, style: AppInlineText.secondary(context)),
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.icon, required this.text, this.error = false});

  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? Theme.of(context).colorScheme.error : null;
    return AppInlineRow(
      leading: Icon(icon, color: color),
      child: Text(
        text,
        style: AppInlineText.body(context).copyWith(color: color),
      ),
    );
  }
}
