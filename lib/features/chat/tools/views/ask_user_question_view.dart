import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/logger_service.dart' show logger;
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/wire/wire_parsers.dart';
import 'ask_user_question_widgets.dart';

/// Question option model.
class QuestionOption {
  QuestionOption({required this.label, required this.description});
  final String label;
  final String description;
}

/// Question model.
class Question {
  Question({
    required this.question,
    required this.header,
    required this.options,
    required this.multiSelect,
  });
  final String question;
  final String header;
  final List<QuestionOption> options;
  final bool multiSelect;
}

/// View for displaying AskUserQuestion tool with interactive options.
class AskUserQuestionView extends ConsumerStatefulWidget {
  const AskUserQuestionView({
    required this.tool,
    super.key,
    this.metadata,
    this.sessionId,
  });

  /// The tool data.
  final Map<String, dynamic> tool;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  /// The session ID for sending responses.
  final String? sessionId;

  @override
  ConsumerState<AskUserQuestionView> createState() =>
      _AskUserQuestionViewState();
}

class _AskUserQuestionViewState extends ConsumerState<AskUserQuestionView>
    with TickerProviderStateMixin {
  final Map<int, Set<int>> _selections = {};
  final Map<int, TextEditingController> _notesControllers = {};
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  /// Attention pulses played before the card settles into its static
  /// highlighted state. Repeating forever would repaint an animated
  /// blurred BoxShadow every frame for as long as the agent waits for
  /// an answer — the canonical walk-away-idle state.
  static const int _kPulseCycles = 3;

  int _pulseCyclesDone = 0;
  bool _pulseStarted = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pulseStarted) return;
    _pulseStarted = true;
    if (AppMotion.reduceMotion(context)) {
      // Skip straight to the settled highlighted state.
      _pulseController.value = 1.0;
      return;
    }
    _runPulseCycle();
  }

  void _runPulseCycle() {
    _pulseController.forward(from: 0).whenComplete(() {
      _pulseCyclesDone++;
      if (!mounted || _pulseCyclesDone >= _kPulseCycles) return;
      _runPulseCycle();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    for (final controller in _notesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsedQuestions = _parseQuestions();
    if (parsedQuestions.isEmpty) {
      return const SizedBox.shrink();
    }

    for (var i = 0; i < parsedQuestions.length; i++) {
      _notesControllers.putIfAbsent(i, TextEditingController.new);
    }

    // Show submitted view if the user submitted locally OR if the
    // server already resolved the permission (e.g. loaded from sync,
    // widget rebuild after submit, or auto-approve).
    final existingPerm = WireParsers.asMap(widget.tool['permission']);
    final permStatus = existingPerm?['status'] as String?;
    final alreadyResolved = permStatus != null && permStatus != 'pending';
    if (_isSubmitted || alreadyResolved) {
      return _buildSubmittedView(context, parsedQuestions);
    }

    final canInteract = !_isSubmitting;
    final allAnswered = parsedQuestions.asMap().entries.every((e) {
      final s = _selections[e.key];
      return s != null && s.isNotEmpty;
    });

    return _buildInteractiveView(
      context,
      parsedQuestions,
      canInteract: canInteract,
      allAnswered: allAnswered,
    );
  }

  List<Question> _parseQuestions() {
    final input = WireParsers.asMap(widget.tool['input']) ?? {};
    final questions = input['questions'] as List?;
    if (questions == null || questions.isEmpty) {
      return const <Question>[];
    }

    return questions
        .map((q) {
          if (q is! Map<String, dynamic>) return null;
          final options =
              (q['options'] as List?)
                  ?.map(
                    (o) => QuestionOption(
                      label: o['label'] as String? ?? '',
                      description: o['description'] as String? ?? '',
                    ),
                  )
                  .toList() ??
              [];

          return Question(
            question: q['question'] as String? ?? '',
            header: q['header'] as String? ?? 'Question',
            options: options,
            multiSelect: q['multiSelect'] as bool? ?? false,
          );
        })
        .whereType<Question>()
        .toList();
  }

  Widget _buildSubmittedView(BuildContext context, List<Question> questions) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md + AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 80 / 255),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xsm),
              Text(
                'Answered',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
          ...questions.asMap().entries.map((entry) {
            final qIndex = entry.key;
            final q = entry.value;
            final selected = _selections[qIndex];
            final labels = selected != null
                ? selected
                      .map(
                        (i) => i < q.options.length ? q.options[i].label : '',
                      )
                      .where((l) => l.isNotEmpty)
                      .join(', ')
                : '-';

            return Padding(
              padding: EdgeInsets.only(top: qIndex > 0 ? 6 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${q.header}: ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          labels,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (_notesControllers[qIndex]?.text.trim().isNotEmpty ??
                            false) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Notes: '
                            '${_notesControllers[qIndex]!.text.trim()}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInteractiveView(
    BuildContext context,
    List<Question> questions, {
    required bool canInteract,
    required bool allAnswered,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final glowAlpha = (12 + (_pulseAnimation.value * 20)).round();
        final borderAlpha = (80 + (_pulseAnimation.value * 80)).round();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: primary.withValues(alpha: borderAlpha / 255),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: glowAlpha / 255),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header bar
          _buildHeader(context),

          // Questions
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ...questions.asMap().entries.map((entry) {
                  final qIndex = entry.key;
                  final question = entry.value;
                  return QuestionSection(
                    question: question,
                    questionIndex: qIndex,
                    selectedOptions: _selections[qIndex] ?? {},
                    isInteractive: canInteract,
                    onToggle: (optionIndex) => _handleToggle(
                      qIndex,
                      optionIndex,
                      question.multiSelect,
                    ),
                    notesController: _notesControllers[qIndex],
                  );
                }),

                // Submit button
                if (canInteract) ...[
                  const SizedBox(height: 4),
                  _buildSubmitButton(context, allAnswered: allAnswered),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 18 / 255),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 22 / 255),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: primary.withValues(alpha: 60 / 255),
                width: 1,
              ),
            ),
            child: Icon(Icons.help_rounded, size: 18, color: primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Input needed',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                Text(
                  'Please choose an option below',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: primary.withValues(alpha: 180 / 255),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 25 / 255),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: primary.withValues(alpha: 60 / 255),
                width: 1,
              ),
            ),
            child: Text(
              'ACTION',
              style: TextStyle(
                fontSize: AppFontSize.xxs,
                fontWeight: FontWeight.w800,
                color: primary,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context, {required bool allAnswered}) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
        onPressed: allAnswered && !_isSubmitting ? _handleSubmit : null,
        icon: _isSubmitting
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onPrimary,
                ),
              )
            : const Icon(Icons.send_rounded, size: 16),
        label: Text(_isSubmitting ? 'Submitting...' : 'Submit'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          backgroundColor: allAnswered && !_isSubmitting
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
      ),
    );
  }

  void _handleToggle(int questionIndex, int optionIndex, bool multiSelect) {
    setState(() {
      final current = _selections[questionIndex] ?? <int>{};
      if (multiSelect) {
        if (current.contains(optionIndex)) {
          current.remove(optionIndex);
        } else {
          current.add(optionIndex);
        }
        _selections[questionIndex] = current;
      } else {
        _selections[questionIndex] = {optionIndex};
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting || widget.sessionId == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final input = WireParsers.asMap(widget.tool['input']) ?? {};
    final parsedQuestions = _parseQuestions();

    // Build the AskUserQuestion answer payload keyed by question
    // text: `answers` maps each question to its selected label(s)
    // (joined with ", " for multi-select), and `annotations` carries
    // per-question free-text notes. Both ride through `updatedInput`
    // so the CLI can resume the blocked turn.
    final answers = <String, String>{};
    final annotations = <String, Map<String, String>>{};
    for (var qIdx = 0; qIdx < parsedQuestions.length; qIdx++) {
      final question = parsedQuestions[qIdx];
      final selected = _selections[qIdx];
      if (selected != null && selected.isNotEmpty) {
        final labels = selected
            .map(
              (i) =>
                  i < question.options.length ? question.options[i].label : '',
            )
            .where((l) => l.isNotEmpty)
            .join(', ');
        answers[question.question] = labels;
      }
      final notes = _notesControllers[qIdx]?.text.trim() ?? '';
      if (notes.isNotEmpty) {
        annotations[question.question] = <String, String>{'notes': notes};
      }
    }

    try {
      final permission = WireParsers.asMap(widget.tool['permission']);
      final permId = permission?['id'] as String?;
      if (permId != null) {
        // Include answers in updatedInput so the CLI
        // receives them via the permission response.
        await ref
            .read(permissionsNotifierProvider.notifier)
            .allow(
              widget.sessionId!,
              permId,
              updatedInput: <String, dynamic>{
                ...input,
                'answers': answers,
                if (annotations.isNotEmpty) 'annotations': annotations,
              },
            );
      } else {
        // Fallback: send as a chat message if there
        // is no permission to approve.
        final lines = <String>[
          ...answers.entries.map((e) => '${e.key}: ${e.value}'),
          ...annotations.entries.map(
            (e) => '${e.key} (notes): ${e.value['notes']}',
          ),
        ];
        await ref
            .read(chatActionNotifierProvider.notifier)
            .sendMessage(widget.sessionId!, lines.join('\n'));
      }
      // Only mark as submitted after the RPC/message
      // actually succeeds — if the CLI agent has
      // disconnected the RPC will fail and the user
      // should see the interactive view again.
      if (mounted) {
        setState(() => _isSubmitted = true);
      }
    } catch (e, st) {
      final msg = e.toString();
      // Expected race condition when server already resolved/expired
      // the permission before the user answered.
      final isExpectedRace =
          msg.contains('no pending permission') ||
          msg.contains('not available') ||
          msg.contains('failed to resolve') ||
          msg.contains('restarted') ||
          msg.contains('expired');
      if (isExpectedRace) {
        logger.info('Submit answer skipped: $e');
        // Permission already resolved — treat as
        // submitted so the UI doesn't show stale
        // interactive controls.
        if (mounted) {
          setState(() => _isSubmitted = true);
        }
      } else {
        logger.warning('Failed to submit answer: $e', e, st);
        // Don't set _isSubmitted — show the
        // interactive view again so the user can
        // retry or see that submission failed.
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
