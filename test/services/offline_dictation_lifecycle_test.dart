import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/_offline_dictation_service_native.dart';
import 'package:record/record.dart';

class _Recorder implements AudioRecorder {
  bool recording = false;
  int starts = 0;
  int cancels = 0;
  Completer<void>? openBarrier;
  final openEntered = Completer<void>();

  @override
  Future<bool> isRecording() async => recording;
  @override
  Future<bool> hasPermission({bool request = true}) async => true;
  @override
  Future<bool> isEncoderSupported(AudioEncoder encoder) async => true;
  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    starts++;
    openEntered.complete();
    if (openBarrier != null) await openBarrier!.future;
    recording = true;
    return const Stream.empty();
  }

  @override
  Future<void> cancel() async {
    cancels++;
    recording = false;
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Service extends OfflineDictationService {
  _Service(_Recorder recorder) : super(recorder: recorder);
  final readyBarrier = Completer<void>();
  final readyEntered = Completer<void>();

  @override
  Future<void> ensureReady() async {
    readyEntered.complete();
    await readyBarrier.future;
  }
}

void main() {
  test('cancel during model preparation never opens the recorder', () async {
    final recorder = _Recorder();
    final service = _Service(recorder);
    addTearDown(service.dispose);
    final start = service.start();
    await service.readyEntered.future;
    await service.cancel();
    service.readyBarrier.complete();
    await start;
    expect(recorder.starts, 0);
    expect(recorder.recording, isFalse);
  });

  test('owner cancellation before model readiness prevents capture', () async {
    final recorder = _Recorder();
    final service = _Service(recorder);
    addTearDown(service.dispose);
    var current = true;
    final start = service.start(shouldContinue: () => current);
    await service.readyEntered.future;
    current = false;
    service.readyBarrier.complete();
    await start;
    expect(recorder.starts, 0);
  });

  test('capture opened after cancellation is immediately canceled', () async {
    final recorder = _Recorder()..openBarrier = Completer<void>();
    final service = _Service(recorder);
    addTearDown(service.dispose);
    final start = service.start();
    await service.readyEntered.future;
    service.readyBarrier.complete();
    await recorder.openEntered.future;
    expect(recorder.starts, 1);
    await service.cancel();
    recorder.openBarrier!.complete();
    await start;
    expect(recorder.recording, isFalse);
    expect(recorder.cancels, 1);
  });
}
