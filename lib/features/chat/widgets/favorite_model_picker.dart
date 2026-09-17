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
      widget.current.modeString: widget.current.label,
      ?favorite: ChatModelMode.fromString(favorite).label,
    };
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: DropdownButtonFormField<String>(
        initialValue: _favorite ?? '',
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Favorite / default model',
          helperText: 'For this provider; keeps this session unchanged.',
          helperMaxLines: 2,
          prefixIcon: Icon(Icons.star_rounded),
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('No favorite')),
          for (final entry in choices.entries)
            DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) {
          final favorite = value == null || value.isEmpty ? null : value;
          setState(() => _favorite = favorite);
          widget.onChanged(favorite);
        },
      ),
    );
  }
}
