import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/logger_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_circular_progress_indicator.dart';
import 'model_mode.dart';

typedef ModelPickerCatalogData = ({List<ChatModelMode> models, String? notice});

typedef ModelCatalogLoader = Future<ModelPickerCatalogData> Function();

class ModelPickerCatalog extends StatefulWidget {
  const ModelPickerCatalog({
    required this.models,
    required this.builder,
    this.notice,
    this.onRefresh,
    super.key,
  });

  final List<ChatModelMode> models;
  final String? notice;
  final ModelCatalogLoader? onRefresh;
  final Widget Function(BuildContext, List<ChatModelMode>) builder;

  @override
  State<ModelPickerCatalog> createState() => _ModelPickerCatalogState();
}

class _ModelPickerCatalogState extends State<ModelPickerCatalog> {
  late List<ChatModelMode> _models = widget.models;
  late String? _notice = widget.notice;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.onRefresh != null) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final loader = widget.onRefresh;
    if (_loading || loader == null) return;
    setState(() => _loading = true);
    try {
      final result = await loader();
      if (!mounted) return;
      setState(() {
        _models = result.models;
        _notice = result.notice;
      });
    } catch (error) {
      logger.warning('Model catalog refresh failed: $error');
      if (!mounted) return;
      setState(() {
        _notice = 'Could not refresh models. Try again when connected.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.onRefresh != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Model catalog',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: SizedBox.square(
                      dimension: 20,
                      child: AppCircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Refresh models',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
              ],
            ),
          ),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(_notice!),
          ),
        Flexible(
          child: IgnorePointer(
            ignoring: _loading,
            child: widget.builder(context, _models),
          ),
        ),
      ],
    );
  }
}
