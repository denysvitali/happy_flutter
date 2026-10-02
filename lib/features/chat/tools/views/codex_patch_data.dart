import 'package:happy_flutter/core/wire/wire_parsers.dart';

/// Normalized changes and approval state for a Codex patch tool result.
class CodexPatchData {
  const CodexPatchData._({required this.fileChanges, this.autoApproved});

  /// Reads supported provider envelopes in input, content, raw, result order.
  /// Structured changes take precedence over a textual apply_patch body.
  factory CodexPatchData.fromTool(Map<String, dynamic> tool) {
    final rawInput = tool['input'];
    final input = WireParsers.asMap(rawInput) ?? {};
    final sourceValues = <dynamic>[
      rawInput,
      tool['content'],
      tool['raw'],
      tool['result'],
    ];
    final changes = _extractChanges(sourceValues);
    final patch = _extractPatchText(sourceValues);
    final autoApproved = input['auto_approved'] as bool?;
    final parsedChanges = _parseChanges(changes);

    return CodexPatchData._(
      fileChanges: parsedChanges.isNotEmpty
          ? parsedChanges
          : patch != null
          ? _parsePatch(patch)
          : const [],
      autoApproved: autoApproved,
    );
  }

  /// Changes in the provider's order, with normalized operation names.
  final List<FileChange> fileChanges;

  /// Approval flag from the tool input, if supplied.
  final bool? autoApproved;
}

/// File change model for CodexPatch results.
class FileChange {
  /// Creates a [FileChange].
  FileChange({
    required this.path,
    required this.hasAdd,
    required this.hasModify,
    required this.hasDelete,
    required this.changeData,
  });

  /// The full file path.
  final String path;

  /// Whether this change includes an add operation.
  final bool hasAdd;

  /// Whether this change includes a modify operation.
  final bool hasModify;

  /// Whether this change includes a delete operation.
  final bool hasDelete;

  /// The raw change data for detailed display.
  final Map<String, dynamic> changeData;

  /// Directory portion of the path.
  String get dir {
    final lastSlash = path.lastIndexOf('/');
    return lastSlash >= 0 ? path.substring(0, lastSlash + 1) : '';
  }

  /// Filename portion of the path.
  String get displayName {
    final lastSlash = path.lastIndexOf('/');
    return lastSlash >= 0 ? path.substring(lastSlash + 1) : path;
  }

  /// Human-readable operation label.
  String get operationLabel {
    final ops = <String>[];
    if (hasAdd) ops.add('add');
    if (hasModify) ops.add('modify');
    if (hasDelete) ops.add('delete');
    return ops.join(', ');
  }
}

List<FileChange> _parseChanges(dynamic changes) {
  final list = WireParsers.asList(changes);
  if (list != null) return _parseChangeList(list);

  final map = WireParsers.asMap(changes);
  if (map == null || map.isEmpty) return const [];

  final result = <FileChange>[];
  if (_pathFromChangeData(map) != null) {
    final change = _fileChangeFromData(map);
    if (change != null) result.add(change);
    return result;
  }

  for (final entry in map.entries) {
    final path = entry.key.toString();
    final change = _fileChangeFromValue(entry.value, pathHint: path);
    if (change != null) result.add(change);
  }
  return result;
}

List<FileChange> _parseChangeList(List<dynamic> changes) {
  final result = <FileChange>[];
  for (final item in changes) {
    final data = WireParsers.asMap(item);
    if (data == null) continue;
    final change = _fileChangeFromData(data);
    if (change != null) result.add(change);
  }
  return result;
}

FileChange? _fileChangeFromData(Map<String, dynamic> data) {
  return _fileChangeFromValue(data);
}

FileChange? _fileChangeFromValue(dynamic rawData, {String? pathHint}) {
  final data = WireParsers.asMap(rawData);
  if (data == null) {
    final patch = _extractChangeText(rawData);
    if (pathHint == null || patch == null || patch.isEmpty) return null;
    return FileChange(
      path: pathHint,
      hasAdd: false,
      hasModify: true,
      hasDelete: false,
      changeData: {
        'modify': {'patch': patch},
      },
    );
  }

  final path = _pathFromChangeData(data) ?? pathHint;
  if (path == null || path.isEmpty) return null;

  final normalizedKind = _normalizedKind(data);
  var changeData = _normalizedChangeData(data, normalizedKind);
  // Some providers use a path → patch-text map, or wrap the patch in a
  // provider-specific envelope without an operation discriminator. Keep
  // those changes visible as edits instead of producing a blank file row.
  if (!_hasOperation(changeData)) {
    final extractedText = _extractChangeText(data);
    final fallbackData = <String, dynamic>{...data};
    if (extractedText != null) fallbackData['patch'] = extractedText;
    changeData = {'modify': fallbackData};
  }
  return FileChange(
    path: path,
    hasAdd: changeData['add'] != null,
    hasModify: changeData['modify'] != null,
    hasDelete: changeData['delete'] != null,
    changeData: changeData,
  );
}

String? _pathFromChangeData(Map<String, dynamic> data) {
  for (final key in const [
    'path',
    'file',
    'filePath',
    'file_path',
    'filename',
    'name',
  ]) {
    final value = data[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

String? _normalizedKind(Map<String, dynamic> data) {
  final rawKind =
      data['kind'] ??
      data['operation'] ??
      data['op'] ??
      data['action'] ??
      data['type'];
  final kind = rawKind is String ? rawKind.toLowerCase() : null;
  return switch (kind) {
    'create' || 'created' || 'add' || 'added' => 'add',
    'update' ||
    'updated' ||
    'modify' ||
    'modified' ||
    'edit' ||
    'edited' => 'modify',
    'delete' || 'deleted' || 'remove' || 'removed' => 'delete',
    _ => null,
  };
}

Map<String, dynamic> _normalizedChangeData(
  Map<String, dynamic> data,
  String? normalizedKind,
) {
  final changeData = <String, dynamic>{};
  for (final entry in data.entries) {
    final op = _canonicalOperation(entry.key);
    if (op == null) continue;
    final opValue = entry.value;
    if (opValue == null) continue;
    final opMap = WireParsers.asMap(opValue);
    changeData[op] = opMap ?? {'content': opValue.toString()};
  }

  if (changeData.isNotEmpty) return changeData;

  final kind = normalizedKind ?? _inferKindFromFields(data);
  if (kind == null) return data;

  final details = <String, dynamic>{...data}
    ..remove('path')
    ..remove('file')
    ..remove('filePath')
    ..remove('file_path')
    ..remove('filename')
    ..remove('name')
    ..remove('kind')
    ..remove('operation')
    ..remove('op')
    ..remove('action')
    ..remove('type')
    ..remove('add')
    ..remove('added')
    ..remove('create')
    ..remove('created')
    ..remove('modify')
    ..remove('modified')
    ..remove('update')
    ..remove('updated')
    ..remove('edit')
    ..remove('edited')
    ..remove('delete')
    ..remove('deleted')
    ..remove('remove')
    ..remove('removed');
  return {kind: details};
}

String? _canonicalOperation(Object? key) {
  return switch (key?.toString().toLowerCase()) {
    'add' || 'added' || 'create' || 'created' => 'add',
    'modify' ||
    'modified' ||
    'update' ||
    'updated' ||
    'edit' ||
    'edited' => 'modify',
    'delete' || 'deleted' || 'remove' || 'removed' => 'delete',
    _ => null,
  };
}

bool _hasOperation(Map<String, dynamic> data) =>
    data.containsKey('add') ||
    data.containsKey('modify') ||
    data.containsKey('delete');

String? _extractChangeText(dynamic value) {
  if (value is String) return value.isEmpty ? null : value;

  final list = WireParsers.asList(value);
  if (list != null) {
    final parts = list
        .map(_extractChangeText)
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join('\n');
  }

  final map = WireParsers.asMap(value);
  if (map == null) return null;

  // Prefer actual patch/content fields over metadata such as `kind` or
  // `operation`, which would otherwise be displayed as the diff body.
  for (final key in const [
    'patch',
    'diff',
    'unified_diff',
    'before',
    'old',
    'original',
    'after',
    'new',
    'oldText',
    'newText',
    'old_string',
    'new_string',
    'content',
    'text',
    'body',
    'changes',
    'edits',
    'output',
  ]) {
    final text = _extractChangeText(map[key]);
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

String? _inferKindFromFields(Map<String, dynamic> data) {
  if (data.containsKey('before') ||
      data.containsKey('old') ||
      data.containsKey('original') ||
      data.containsKey('diff') ||
      data.containsKey('patch') ||
      data.containsKey('unified_diff') ||
      data.containsKey('oldText') ||
      data.containsKey('newText') ||
      data.containsKey('old_string') ||
      data.containsKey('new_string')) {
    return 'modify';
  }
  if (data.containsKey('after') ||
      data.containsKey('new') ||
      data.containsKey('content') ||
      data.containsKey('text')) {
    return 'add';
  }
  return null;
}

dynamic _extractChanges(dynamic value) {
  final map = WireParsers.asMap(value);
  if (map != null) {
    if (map.containsKey('changes')) return map['changes'];

    for (final key in const [
      'args',
      'arguments',
      'input',
      'content',
      'structuredContent',
      'data',
    ]) {
      if (!map.containsKey(key)) continue;
      final nested = _extractChanges(map[key]);
      if (nested != null) return nested;
    }

    for (final entry in map.values) {
      final nested = _extractChanges(entry);
      if (nested != null) return nested;
    }
    return null;
  }

  final list = WireParsers.asList(value);
  if (list != null) {
    for (final item in list) {
      final nested = _extractChanges(item);
      if (nested != null) return nested;
    }
  }

  return null;
}

String? _extractPatchText(dynamic input) {
  if (input is String && input.contains('*** Begin Patch')) return input;
  final inputMap = WireParsers.asMap(input);
  if (inputMap == null) {
    final inputList = WireParsers.asList(input);
    return inputList != null ? _findPatchText(inputList) : null;
  }
  for (final key in const ['patch', 'input', 'content']) {
    final value = inputMap[key];
    if (value is String && value.contains('*** Begin Patch')) return value;
  }
  return _findPatchText(inputMap);
}

String? _findPatchText(dynamic value) {
  if (value is String && value.contains('*** Begin Patch')) return value;
  final map = WireParsers.asMap(value);
  if (map != null) {
    for (final entry in map.values) {
      final patch = _findPatchText(entry);
      if (patch != null) return patch;
    }
    return null;
  }
  final list = WireParsers.asList(value);
  if (list != null) {
    for (final item in list) {
      final patch = _findPatchText(item);
      if (patch != null) return patch;
    }
  }
  return null;
}

List<FileChange> _parsePatch(String patch) {
  final result = <FileChange>[];
  String? currentPath;
  String? currentKind;
  final buffer = StringBuffer();

  void flush() {
    if (currentPath == null || currentKind == null) return;
    final patchText = buffer.toString().trimRight();
    final changeData = <String, dynamic>{
      currentKind: {'patch': patchText},
    };
    result.add(
      FileChange(
        path: currentPath,
        hasAdd: currentKind == 'add',
        hasModify: currentKind == 'modify',
        hasDelete: currentKind == 'delete',
        changeData: changeData,
      ),
    );
  }

  for (final line in patch.split('\n')) {
    String? nextPath;
    String? nextKind;
    if (line.startsWith('*** Add File: ')) {
      nextPath = line.substring('*** Add File: '.length);
      nextKind = 'add';
    } else if (line.startsWith('*** Update File: ')) {
      nextPath = line.substring('*** Update File: '.length);
      nextKind = 'modify';
    } else if (line.startsWith('*** Delete File: ')) {
      nextPath = line.substring('*** Delete File: '.length);
      nextKind = 'delete';
    }

    if (nextPath != null && nextKind != null) {
      flush();
      currentPath = nextPath;
      currentKind = nextKind;
      buffer
        ..clear()
        ..writeln(line);
      continue;
    }

    if (currentPath != null &&
        !line.startsWith('*** Begin Patch') &&
        !line.startsWith('*** End Patch')) {
      buffer.writeln(line);
    }
  }
  flush();

  if (result.isNotEmpty) return result;

  return [
    FileChange(
      path: 'patch',
      hasAdd: false,
      hasModify: true,
      hasDelete: false,
      changeData: {
        'modify': {'patch': patch},
      },
    ),
  ];
}
