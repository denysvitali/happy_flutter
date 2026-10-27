import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import 'model_mode.dart';

/// Sets a provider default without changing the active session's model.
class FavoriteModelPicker extends StatefulWidget {
  const FavoriteModelPicker({
    required this.models,
    required this.current,
    required this.favorite,
    required this.onChanged,
    super.key,
  });

  final List<ChatModelMode> models;
  final ChatModelMode current;
  final String? favorite;
  final ValueChanged<String?> onChanged;

  @override
  State<FavoriteModelPicker> createState() => _FavoriteModelPickerState();
}

class _FavoriteModelPickerState extends State<FavoriteModelPicker> {
  late String? _favorite = widget.favorite;

  @override
  Widget build(BuildContext context) {
    final favorite = _favorite;
    final choices = <String, String>{
      for (final model in widget.models) model.modeString: model.label,
    };
    choices.putIfAbsent(widget.current.modeString, () => widget.current.label);
    if (favorite != null) {
      choices.putIfAbsent(
        favorite,
        () => ChatModelMode.fromString(favorite).label,
      );
    }
    final entries = choices.entries.toList();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ListTile(
        key: const ValueKey('favorite-model-picker'),
        leading: const Icon(Icons.star_rounded),
        title: const Text('Favorite / default model'),
        subtitle: Text(
          '${favorite == null ? 'No favorite' : choices[favorite]}\n'
          'For this provider; keeps this session unchanged.',
        ),
        trailing: const Icon(Icons.arrow_drop_down),
        onTap: () async {
          final result = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Favorite / default model'),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.sizeOf(context).height * 0.5,
                child: ListView.builder(
                  itemCount: entries.length + 1,
                  itemBuilder: (context, index) {
                    final value = index == 0 ? '' : entries[index - 1].key;
                    final label = index == 0
                        ? 'No favorite'
                        : entries[index - 1].value;
                    return ListTile(
                      title: Text(label),
                      selected: value == (favorite ?? ''),
                      onTap: () => Navigator.pop(context, value),
                    );
                  },
                ),
              ),
            ),
          );
          if (!mounted || result == null) return;
          final selected = result.isEmpty ? null : result;
          setState(() => _favorite = selected);
          widget.onChanged(selected);
        },
      ),
    );
  }
}
