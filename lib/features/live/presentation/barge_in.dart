/// Detects the user speaking over the assistant (barge-in).
///
/// While the assistant talks, the microphone is only measured, never sent. If
/// it stays above a level for [minMs] in a row, that counts as a cut-in.
class BargeIn {
  static const minLevel = 0.02;
  static const minMs = 250;
  static const echoFrames = 125;

  double _run = 0;
  double? _floor;
  final List<double> _echo = [];

  /// Remembers the room's quiet level while the assistant is silent, and
  /// returns the level to beat while it talks (null when it is silent).
  double? levelToBeat(double rms, {required bool assistantTalking}) {
    if (!assistantTalking) {
      final f = _floor;
      _floor = f == null ? rms : _min(f * 1.02, 0.9 * f + 0.1 * rms);
      _echo.clear();
      return null;
    }
    _echo.add(rms);
    if (_echo.length > echoFrames) _echo.removeAt(0);
    // The assistant's own voice leaking into the mic: the 60th percentile of
    // the last second. Not the maximum, or the user's voice would raise it.
    final sorted = [..._echo]..sort();
    final echo = sorted[((sorted.length - 1) * 0.6).floor()];
    return _max(minLevel, _max(3 * (_floor ?? 0), 1.5 * echo));
  }

  /// True once the level has been beaten for long enough.
  bool feed(double rms, double chunkMs, double need) {
    _run = rms >= need ? _run + chunkMs : 0;
    return _run >= minMs;
  }

  void reset() => _run = 0;

  static double _min(double a, double b) => a < b ? a : b;
  static double _max(double a, double b) => a > b ? a : b;
}
