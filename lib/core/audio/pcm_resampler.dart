import 'dart:typed_data';

/// Turns microphone audio (floats at the browser's rate) into 16 kHz 16-bit
/// samples, the format the server expects.
class PcmResampler {
  PcmResampler(this.inputRate) : _ratio = inputRate / 16000;

  final double inputRate;
  final double _ratio;
  Float32List _carry = Float32List(0);
  double _pos = 0;

  static int _toInt16(double v) {
    final c = v.clamp(-1.0, 1.0);
    return (c < 0 ? c * 32768 : c * 32767).toInt();
  }

  Int16List process(Float32List input) {
    if (inputRate == 16000) {
      final out = Int16List(input.length);
      for (var i = 0; i < input.length; i++) {
        out[i] = _toInt16(input[i]);
      }
      return out;
    }
    final buf = Float32List(_carry.length + input.length)
      ..setAll(0, _carry)
      ..setAll(_carry.length, input);
    final out = <int>[];
    while (_pos + 1 < buf.length) {
      final i = _pos.floor();
      final frac = _pos - i;
      out.add(_toInt16(buf[i] + (buf[i + 1] - buf[i]) * frac));
      _pos += _ratio;
    }
    final keep = _pos.floor();
    _carry = Float32List.fromList(buf.sublist(keep));
    _pos -= keep;
    return Int16List.fromList(out);
  }
}
