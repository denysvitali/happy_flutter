// FSM codegen for the architecture overhaul.
//
// Reads spec/message.fsm.yaml and emits a sealed Dart hierarchy at
// lib/core/fsm/message_state.g.dart. The output is checked in so it
// is visible in CI without running a full build_runner cycle; the
// generator can be re-run by humans with:
//
//   dart run tools/fsm_codegen.dart
//
// The YAML parser here is intentionally tiny — it understands the
// limited shape of the spec file, not full YAML. Keep the spec file
// regular (no anchors, no flow-style maps inside fields except the
// inline `{ name: x, type: T }` form we already use).

import 'dart:io';

void main(List<String> args) {
  final inputPath = args.isNotEmpty ? args[0] : 'spec/message.fsm.yaml';
  final outputPath = args.length > 1
      ? args[1]
      : 'lib/core/fsm/message_state.g.dart';

  final spec = _parse(File(inputPath).readAsStringSync());
  final dart = _emit(spec);
  File(outputPath).writeAsStringSync(dart);
  stdout.writeln('Wrote ${spec.states.length} states + '
      '${spec.transitions.length} transitions to $outputPath');
}

class _State {
  _State(this.name, this.fields);
  final String name;
  final List<_Field> fields;
}

class _Field {
  _Field(this.name, this.type, this.defaultValue);
  final String name;
  final String type;
  final String? defaultValue;
}

class _Transition {
  _Transition(this.from, this.event, this.to);
  final String from;
  final String event;
  final String to;
}

class _Spec {
  _Spec(this.name, this.states, this.transitions);
  final String name;
  final List<_State> states;
  final List<_Transition> transitions;
}

_Spec _parse(String yaml) {
  String? name;
  final states = <_State>[];
  final transitions = <_Transition>[];

  final lines = yaml.split('\n');
  var section = '';
  _State? currentState;

  for (final raw in lines) {
    final line = raw.trimRight();
    if (line.isEmpty || line.trimLeft().startsWith('#')) continue;
    final unindented = line.trimLeft();
    final indent = line.length - unindented.length;

    if (indent == 0) {
      if (unindented.startsWith('name:')) {
        name = _scalar(unindented.substring(5));
      } else if (unindented.startsWith('states:')) {
        section = 'states';
        currentState = null;
      } else if (unindented.startsWith('transitions:')) {
        section = 'transitions';
      } else if (unindented.startsWith('description:')) {
        section = 'description';
      }
      continue;
    }

    if (section == 'states') {
      if (unindented.startsWith('- name:')) {
        currentState =
            _State(_scalar(unindented.substring(7)), <_Field>[]);
        states.add(currentState);
      } else if (unindented.startsWith('fields:')) {
        // marker, fields follow
      } else if (unindented.startsWith('-') && currentState != null) {
        final field = _parseInlineField(unindented.substring(1).trim());
        currentState.fields.add(field);
      }
    } else if (section == 'transitions') {
      if (unindented.startsWith('-')) {
        final body = unindented.substring(1).trim();
        transitions.add(_parseInlineTransition(body));
      }
    }
  }

  return _Spec(name ?? 'State', states, transitions);
}

_Field _parseInlineField(String body) {
  final inner = body.replaceAll('{', '').replaceAll('}', '').trim();
  final parts = inner.split(',').map((p) => p.trim()).toList();
  String? n;
  String? t;
  String? d;
  for (final p in parts) {
    final kv = p.split(':');
    final k = kv[0].trim();
    final v = kv.sublist(1).join(':').trim();
    if (k == 'name') n = v;
    if (k == 'type') t = v;
    if (k == 'default') d = v;
  }
  return _Field(n ?? 'unknown', t ?? 'Object', d);
}

_Transition _parseInlineTransition(String body) {
  final inner = body.replaceAll('{', '').replaceAll('}', '').trim();
  final parts = inner.split(',').map((p) => p.trim()).toList();
  String? f;
  String? on;
  String? to;
  for (final p in parts) {
    final kv = p.split(':');
    final k = kv[0].trim();
    final v = kv.sublist(1).join(':').trim();
    if (k == 'from') f = v;
    if (k == 'on') on = v;
    if (k == 'to') to = v;
  }
  return _Transition(f ?? '?', on ?? '?', to ?? '?');
}

String _scalar(String raw) {
  final v = raw.trim();
  if (v.startsWith('"') && v.endsWith('"')) {
    return v.substring(1, v.length - 1);
  }
  if (v.startsWith("'") && v.endsWith("'")) {
    return v.substring(1, v.length - 1);
  }
  return v;
}

String _emit(_Spec spec) {
  final base = spec.name;
  final buf = StringBuffer()
    ..writeln('// GENERATED — DO NOT EDIT.')
    ..writeln('// Source: spec/message.fsm.yaml')
    ..writeln('// Run: dart run tools/fsm_codegen.dart')
    ..writeln('//')
    ..writeln('// Sealed hierarchy emitted by tools/fsm_codegen.dart for')
    ..writeln('// item #7 of the architecture overhaul.')
    ..writeln()
    ..writeln('// ignore_for_file: public_member_api_docs')
    ..writeln()
    ..writeln('sealed class $base {')
    ..writeln('  const $base();')
    ..writeln('  String get localId;')
    ..writeln('}')
    ..writeln();

  for (final state in spec.states) {
    buf.writeln('final class $base${state.name} extends $base {');
    final params = state.fields
        .map((f) => f.defaultValue == null
            ? 'required this.${f.name}'
            : 'this.${f.name} = ${f.defaultValue}')
        .join(', ');
    buf.writeln('  const $base${state.name}({$params});');
    for (final f in state.fields) {
      buf.writeln('  @override');
      if (f.name == 'localId') {
        buf.writeln('  final ${f.type} ${f.name};');
      } else {
        // Make non-localId fields not @override (only localId is in base).
      }
    }
    // Re-emit fields cleanly; the loop above incorrectly @override'd
    // non-localId. Rewrite by clearing and re-emitting.
    // Quick reset trick: we'll just re-run after stripping the buffer
    // back to the class declaration line. To keep this simple, we
    // instead rebuild the class body in one go below.
    buf.clear();
  }

  // Rebuild cleanly with the correct field emission.
  buf
    ..writeln('// GENERATED — DO NOT EDIT.')
    ..writeln('// Source: spec/message.fsm.yaml')
    ..writeln('// Run: dart run tools/fsm_codegen.dart')
    ..writeln('//')
    ..writeln('// Sealed hierarchy emitted by tools/fsm_codegen.dart for')
    ..writeln('// item #7 of the architecture overhaul.')
    ..writeln()
    ..writeln('// ignore_for_file: public_member_api_docs')
    ..writeln()
    ..writeln('sealed class $base {')
    ..writeln('  const $base();')
    ..writeln('  String get localId;')
    ..writeln('}')
    ..writeln();

  for (final state in spec.states) {
    final cls = '$base${state.name}';
    buf
      ..writeln('final class $cls extends $base {')
      ..writeln('  const $cls({');
    for (final f in state.fields) {
      if (f.defaultValue == null) {
        buf.writeln('    required this.${f.name},');
      } else {
        buf.writeln('    this.${f.name} = ${f.defaultValue},');
      }
    }
    buf.writeln('  });');
    for (final f in state.fields) {
      if (f.name == 'localId') {
        buf
          ..writeln('  @override')
          ..writeln('  final ${f.type} ${f.name};');
      } else {
        buf.writeln('  final ${f.type} ${f.name};');
      }
    }
    buf
      ..writeln('}')
      ..writeln();
  }

  // Transition functions emitted as static methods on a Transitions
  // helper. Each transition is total over the from-state; illegal
  // events return null instead of throwing so callers can branch on
  // the sealed type.
  buf.writeln('abstract final class ${base}Transitions {');
  for (final t in spec.transitions) {
    final fromCls = '$base${t.from}';
    final toCls = '$base${t.to}';
    final method = '${t.event}From${t.from}';
    buf
      ..writeln('  static $toCls? $method($fromCls from, {')
      ..writeln('    String? serverId,')
      ..writeln('    int? seq,')
      ..writeln('    String? text,')
      ..writeln('    String? reason,')
      ..writeln('    int? attempt,')
      ..writeln('  }) {');
    final toState = spec.states.firstWhere((s) => s.name == t.to);
    final args = StringBuffer();
    for (final f in toState.fields) {
      if (args.isNotEmpty) args.write(', ');
      switch (f.name) {
        case 'localId':
          args.write('localId: from.localId');
        case 'serverId':
          args.write('serverId: serverId ?? '
              "(throw ArgumentError('serverId required for ${t.event}'))");
        case 'seq':
          args.write('seq: seq ?? 0');
        case 'text':
          args.write("text: text ?? ''");
        case 'reason':
          args.write("reason: reason ?? 'unknown'");
        case 'attempt':
          args.write('attempt: attempt ?? 1');
        default:
          args.write('${f.name}: null');
      }
    }
    buf
      ..writeln('    return $toCls($args);')
      ..writeln('  }')
      ..writeln();
  }
  buf.writeln('}');

  return buf.toString();
}
