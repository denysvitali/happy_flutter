import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/offline_dictation_service.dart';

void main() {
  group('OfflineSttCatalog', () {
    test('defaultModel is Parakeet TDT 0.6B v3', () {
      expect(
        OfflineSttCatalog.defaultModel.id,
        'parakeet-tdt-0.6b-v3-int8-v1',
      );
      expect(
        OfflineSttCatalog.defaultModel.family,
        OfflineSttFamily.transducer,
      );
      expect(
        OfflineSttCatalog.defaultModel.modelType,
        'nemo_transducer',
      );
    });

    test('byId resolves every Core 6 entry and rejects unknown', () {
      expect(OfflineSttCatalog.all, hasLength(6));
      for (final model in OfflineSttCatalog.all) {
        expect(OfflineSttCatalog.byId(model.id), same(model));
        expect(model.archiveSha256, isNotEmpty);
        expect(model.archiveUrl, contains('asr-models'));
        expect(model.requiredFiles, isNotEmpty);
        expect(model.sizeLabel, startsWith('~'));
      }
      expect(OfflineSttCatalog.byId(null), isNull);
      expect(OfflineSttCatalog.byId(''), isNull);
      expect(OfflineSttCatalog.byId('nope'), isNull);
    });

    test('sizeLabel formats MB without decimals above 10', () {
      final tiny = OfflineSttCatalog.byId('moonshine-tiny-en-int8-v1')!;
      expect(tiny.sizeLabel, '~103MB');
      final parakeet = OfflineSttCatalog.defaultModel;
      expect(parakeet.sizeLabel, '~465MB');
    });
  });

  group('resolveOfflineSttFiles', () {
    test('builds moonshine paths', () {
      final model = OfflineSttCatalog.byId('moonshine-tiny-en-int8-v1')!;
      final files = resolveOfflineSttFiles(model, '/cache/moonshine');
      final desc = files.toConfigDescriptor();
      expect(desc['family'], 'moonshine');
      expect(desc['preprocessor'], '/cache/moonshine/preprocess.onnx');
      expect(desc['encoder'], '/cache/moonshine/encode.int8.onnx');
      expect(
        desc['uncachedDecoder'],
        '/cache/moonshine/uncached_decode.int8.onnx',
      );
      expect(
        desc['cachedDecoder'],
        '/cache/moonshine/cached_decode.int8.onnx',
      );
      expect(desc['tokens'], '/cache/moonshine/tokens.txt');
    });

    test('builds transducer paths with nemo modelType', () {
      final model = OfflineSttCatalog.defaultModel;
      final files = resolveOfflineSttFiles(model, '/cache/parakeet');
      final desc = files.toConfigDescriptor();
      expect(desc['family'], 'transducer');
      expect(desc['modelType'], 'nemo_transducer');
      expect(desc['encoder'], '/cache/parakeet/encoder.int8.onnx');
      expect(desc['decoder'], '/cache/parakeet/decoder.int8.onnx');
      expect(desc['joiner'], '/cache/parakeet/joiner.int8.onnx');
    });

    test('builds whisper paths', () {
      final model = OfflineSttCatalog.byId('whisper-tiny-en-v1')!;
      final files = resolveOfflineSttFiles(model, '/cache/whisper');
      final desc = files.toConfigDescriptor();
      expect(desc['family'], 'whisper');
      expect(desc['modelType'], 'whisper');
      expect(desc['encoder'], endsWith('tiny.en-encoder.int8.onnx'));
      expect(desc['decoder'], endsWith('tiny.en-decoder.int8.onnx'));
    });

    test('builds senseVoice paths', () {
      final model =
          OfflineSttCatalog.byId('sense-voice-int8-2024-07-17-v1')!;
      final files = resolveOfflineSttFiles(model, '/cache/sense');
      final desc = files.toConfigDescriptor();
      expect(desc['family'], 'senseVoice');
      expect(desc['model'], '/cache/sense/model.int8.onnx');
      expect(desc['tokens'], '/cache/sense/tokens.txt');
    });
  });
}
