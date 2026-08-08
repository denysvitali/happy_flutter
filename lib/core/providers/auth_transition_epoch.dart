/// Invalidates continuations from superseded authentication transitions.
final class AuthTransitionEpoch {
  int _epoch = 0;

  int begin() => ++_epoch;

  void invalidate() {
    _epoch++;
  }

  bool isCurrent(int epoch) => epoch == _epoch;
}
