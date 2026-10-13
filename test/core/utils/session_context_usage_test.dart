import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/session_context_usage.dart';

Map<String, dynamic> _snapshot({
  Object? used = 11978,
  Object? window = 500000,
  String model = 'gpt-6-luna',
}) => {
  'source': 'prime-agent-daemon',
  'scope': 'session',
  'context_size': used,
  'context_window': window,
  'context_is_estimate': true,
  'model': model,
  'provider': 'openai-codex',
  'input_tokens': 139982,
  'output_tokens': 101,
  'cache_read_input_tokens': 1000,
  'cache_creation_input_tokens': 2000,
};

void main() {
  test('positive wire sequence orders shared timestamps and clock changes', () {
    final cleared = reduceSessionUsage(
      null,
      _snapshot(used: null, window: null),
      1000,
      seq: 17,
    );
    final known = reduceSessionUsage(cleared, _snapshot(), 1000, seq: 18);
    expect(known['contextSize'], 11978);
    expect(known['seq'], 18);
    for (final staleSeq in [17, 18]) {
      expect(
        reduceSessionUsage(
          known,
          _snapshot(used: null, window: null),
          2000,
          seq: staleSeq,
        ),
        same(known),
      );
    }
    final compacted = reduceSessionUsage(
      known,
      _snapshot(used: 50),
      900,
      seq: 19,
    );
    expect(compacted['contextSize'], 50);
    expect(compacted['timestamp'], 900);
    expect(compacted['seq'], 19);
  });

  test('missing or nonpositive sequence retains legacy timestamp ordering', () {
    final initial = reduceSessionUsage(null, _snapshot(), 1000);
    for (final seq in <int?>[null, 0, -1]) {
      expect(
        reduceSessionUsage(initial, _snapshot(used: 50), 1000, seq: seq),
        same(initial),
      );
      expect(
        reduceSessionUsage(
          initial,
          _snapshot(used: 50),
          1001,
          seq: seq,
        )['contextSize'],
        50,
      );
    }
  });

  test('explicit Prime context is separate from cumulative token totals', () {
    final reduced = reduceSessionUsage(null, _snapshot(), 1000);
    expect(reduced['inputTokens'], 139982);
    expect(reduced['contextSize'], 11978);
    expect(reduced['contextWindow'], 500000);
    expect(reduced['contextIsEstimate'], isTrue);
    expect(reduced['timestamp'], 1000);
    final gauge = projectSessionContext(
      usage: reduced,
      flavor: 'prime-agent',
      currentModel: 'openai-codex/gpt-6-luna:high',
      fallbackWindow: 190000,
    );
    expect(gauge.contextSize, 11978);
    expect(gauge.contextWindow, 500000);
  });

  test(
    'newer compaction count wins, older and equal snapshots cannot revert',
    () {
      final original = reduceSessionUsage(null, _snapshot(), 1000);
      final compacted = reduceSessionUsage(original, _snapshot(used: 50), 2000);
      expect(compacted['contextSize'], 50);
      expect(
        reduceSessionUsage(compacted, _snapshot(used: 10000), 1500),
        same(compacted),
      );
      expect(
        reduceSessionUsage(compacted, _snapshot(used: 10000), 2000),
        same(compacted),
      );
      final cleared = reduceSessionUsage(
        compacted,
        _snapshot(used: null, window: null),
        3000,
      );
      expect(cleared['contextSize'], isNull);
      expect(cleared['contextWindow'], isNull);
    },
  );

  for (final invalid in <Object?>[
    null,
    -1,
    double.nan,
    double.infinity,
    double.negativeInfinity,
    0.5,
    '11978',
    <String, dynamic>{},
  ]) {
    test('invalid context $invalid is unknown, never cumulative fallback', () {
      final reduced = reduceSessionUsage(
        null,
        _snapshot(used: invalid, window: invalid),
        1000,
      );
      expect(reduced['contextSize'], isNull);
      expect(reduced['contextWindow'], isNull);
    });
  }

  test('zero used context is valid and zero capacity is unknown', () {
    final reduced = reduceSessionUsage(
      null,
      _snapshot(used: 0, window: 0),
      1000,
    );
    expect(reduced['contextSize'], 0);
    expect(reduced['contextWindow'], isNull);
  });

  test('model changes clear stale projection until a matching snapshot', () {
    final old = reduceSessionUsage(null, _snapshot(), 1000);
    final switched = projectSessionContext(
      usage: old,
      flavor: 'prime-agent',
      currentModel: 'openai-codex/gpt-6.1-sol',
      fallbackWindow: 200000,
    );
    expect(switched.contextSize, isNull);
    expect(switched.contextWindow, isNull);
    final pending = projectSessionContext(
      usage: old,
      flavor: 'prime-agent',
      currentModel: 'openai-codex/gpt-6-luna',
      selectedModel: 'openai-codex/gpt-6.1-sol:high',
    );
    expect(pending.contextSize, isNull);
    final next = reduceSessionUsage(
      old,
      _snapshot(used: 1234, window: 256000, model: 'gpt-6.1-sol'),
      2000,
    );
    final fresh = projectSessionContext(
      usage: next,
      flavor: 'prime-agent',
      currentModel: 'openai-codex/gpt-6.1-sol',
    );
    expect(fresh.contextSize, 1234);
    expect(fresh.contextWindow, 256000);
  });

  test('provider route change clears context even when model leaf matches', () {
    final old = reduceSessionUsage(null, _snapshot(), 1000);
    expect(old['contextProvider'], 'openai-codex');
    final switched = projectSessionContext(
      usage: old,
      flavor: 'prime-agent',
      currentModel: 'other-provider/gpt-6-luna',
    );
    expect(switched.contextSize, isNull);
    expect(switched.contextWindow, isNull);
    final pending = projectSessionContext(
      usage: old,
      flavor: 'prime-agent',
      currentModel: 'openai-codex/gpt-6-luna',
      selectedModel: 'other-provider/gpt-6-luna:high',
    );
    expect(pending.contextSize, isNull);
    final next = reduceSessionUsage(old, {
      ..._snapshot(used: 1234, window: 256000),
      'provider': 'other-provider',
    }, 2000);
    final fresh = projectSessionContext(
      usage: next,
      flavor: 'prime-agent',
      currentModel: 'other-provider/gpt-6-luna',
    );
    expect(fresh.contextSize, 1234);
    expect(fresh.contextWindow, 256000);
    final unknown = reduceSessionUsage(next, {
      ..._snapshot(),
      'provider': null,
    }, 3000);
    expect(
      projectSessionContext(
        usage: unknown,
        flavor: 'prime-agent',
        currentModel: 'openai-codex/gpt-6-luna',
      ).contextSize,
      isNull,
    );
  });

  test('legacy input and cache context reduction remains intact', () {
    final reduced = reduceSessionUsage(null, {
      'scope': 'session',
      'input_tokens': 11,
      'output_tokens': 7,
      'cache_creation_input_tokens': 13,
      'cache_read_input_tokens': 17,
    }, 1000);
    expect(reduced['contextSize'], 41);
    expect(reduced['outputTokens'], 7);
    final gauge = projectSessionContext(
      usage: reduced,
      flavor: 'claude',
      fallbackWindow: 200000,
    );
    expect(gauge.contextSize, 41);
    expect(gauge.contextWindow, 200000);
    final prime = projectSessionContext(usage: reduced, flavor: 'prime-agent');
    expect(prime.contextSize, isNull);
    expect(prime.contextWindow, isNull);
  });

  test('repeated snapshots keep cumulative totals out of the gauge', () {
    Map<String, dynamic>? state;
    for (var i = 1; i <= 1000; i++) {
      state = reduceSessionUsage(state, _snapshot(used: i % 7), i);
    }
    expect(state!['contextSize'], 6);
    expect(state['inputTokens'], 139982);
    expect(state['timestamp'], 1000);
  });
}
