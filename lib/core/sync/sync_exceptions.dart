/// Thrown when the requested model is not supported by the selected
/// provider/profile during session spawning.
class IncompatibleProviderAndModelError implements Exception {
  const IncompatibleProviderAndModelError(this.message);

  final String message;

  @override
  String toString() => message;
}
