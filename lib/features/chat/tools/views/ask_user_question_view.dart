import 'package:flutter/material.dart';
import '../tool_section_view.dart';

/// Question option model.
class QuestionOption {
  final String label;
  final String description;

  QuestionOption({required this.label, required this.description});
}

/// Question model.
class Question {
  final String question;
  final String header;
  final List<QuestionOption> options;
  final bool multiSelect;

  Question({
    required this.question,
    required this.header,
    required this.options,
    required this.multiSelect,
  });
}

/// View for displaying AskUserQuestion tool with interactive options.
class AskUserQuestionView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;
  final String? sessionId;

  const AskUserQuestionView({
    super.key,
    required this.tool,
    this.metadata,
    this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final questions = input['questions'] as List?;
    final state = tool['state'] as String? ?? 'running';

    if (questions == null || questions.isEmpty) {
      return const SizedBox.shrink();
    }

    final parsedQuestions = questions
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

    if (parsedQuestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final isCompleted = state == 'completed';
    final isRunning = state == 'running';

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: parsedQuestions.map((question) {
          return _QuestionSection(question: question, isInteractive: isRunning);
        }).toList(),
      ),
    );
  }
}

class _QuestionSection extends StatefulWidget {
  final Question question;
  final bool isInteractive;

  const _QuestionSection({required this.question, required this.isInteractive});

  @override
  State<_QuestionSection> createState() => _QuestionSectionState();
}

class _QuestionSectionState extends State<_QuestionSection> {
  final Set<int> _selectedOptions = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.question.header.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Question text
          Text(
            widget.question.question,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // Options
          ...widget.question.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = _selectedOptions.contains(index);

            return _OptionButton(
              option: option,
              isSelected: isSelected,
              isMultiSelect: widget.question.multiSelect,
              isInteractive: widget.isInteractive,
              onTap: () => _handleToggle(index),
            );
          }),
        ],
      ),
    );
  }

  void _handleToggle(int index) {
    if (!widget.isInteractive) return;

    setState(() {
      if (widget.question.multiSelect) {
        if (_selectedOptions.contains(index)) {
          _selectedOptions.remove(index);
        } else {
          _selectedOptions.add(index);
        }
      } else {
        _selectedOptions.clear();
        _selectedOptions.add(index);
      }
    });
  }
}

class _OptionButton extends StatelessWidget {
  final QuestionOption option;
  final bool isSelected;
  final bool isMultiSelect;
  final bool isInteractive;
  final VoidCallback onTap;

  const _OptionButton({
    required this.option,
    required this.isSelected,
    required this.isMultiSelect,
    required this.isInteractive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: isInteractive ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                : Colors.transparent,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Radio/checkbox indicator
              _buildIndicator(theme),
              const SizedBox(width: 10),
              // Option content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (option.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          option.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator(ThemeData theme) {
    final borderColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    if (isMultiSelect) {
      // Checkbox style
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(4),
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
        ),
        child: isSelected
            ? Icon(Icons.check, size: 14, color: theme.colorScheme.onPrimary)
            : null,
      );
    }

    // Radio style
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          ),
        ),
      ),
    );
  }
}
