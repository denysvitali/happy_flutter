class OfflineDictationException implements Exception {
  const OfflineDictationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OfflineDictationService {
  Future<void> start() async {
    throw const OfflineDictationException(
      'Offline dictation is not supported on this platform',
    );
  }

  Future<String?> stop() async => null;

  Future<void> cancel() async {}

  Stream<double> levels({
    Duration interval = const Duration(milliseconds: 200),
  }) {
    return const Stream<double>.empty();
  }

  Future<String> transcribe({required String audioPath}) async {
    throw const OfflineDictationException(
      'Offline dictation is not supported on this platform',
    );
  }

  Future<void> dispose() async {}
}
