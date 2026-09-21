import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/widgets/model_mode.dart';

void main() {
  test('grok flavor exposes more than the default model', () {
    final models = ChatModelMode.availableForProfile(
      flavor: 'grok',
      claudeCompatible: false,
    );
    expect(models.length, greaterThan(1));
    expect(
      models.map((m) => m.modeString),
      containsAll(['default', 'grok-4.7', 'grok-4.6', 'grok-4.5']),
    );
  });

  test('grok-4.7 survives flavor normalization', () {
    final normalized = ChatModelMode.normalizeForFlavor(
      ChatModelMode.fromString('grok-4.7'),
      'grok',
    );
    expect(normalized.modeString, 'grok-4.7');
  });
}
