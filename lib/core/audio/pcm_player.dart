import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'mic_capture.dart';

/// Plays the assistant's voice: 24 kHz, 16-bit, mono PCM that arrives in
/// pieces. Pieces are scheduled one after another so there are no gaps.
class PcmPlayer {
  PcmPlayer(this._session) : _gain = _session.context.createGain() {
    _gain.connect(_session.context.destination);
  }

  final AudioSession _session;
  final web.GainNode _gain;
  final List<web.AudioBufferSourceNode> _sources = [];
  double _playAt = 0;

  web.AudioContext get _ctx => _session.context;

  /// The assistant's voice is coming out of the speaker right now.
  bool get isSpeaking => _playAt > _ctx.currentTime + 0.02;

  /// Loudness of this piece, 0 to 1, so the orb can move.
  double play(Uint8List bytes) {
    final samples = bytes.buffer.asInt16List(
      bytes.offsetInBytes,
      bytes.lengthInBytes ~/ 2,
    );
    final floats = Float32List(samples.length);
    var sum = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final v = samples[i] / 32768;
      floats[i] = v;
      sum += v * v;
    }
    final buffer = _ctx.createBuffer(1, samples.length, 24000);
    buffer.copyToChannel(floats.toJS, 0);
    final source = _ctx.createBufferSource()
      ..buffer = buffer
      ..connect(_gain);
    final now = _ctx.currentTime;
    // 0.2 s lead when starting, so late pieces do not leave gaps.
    _playAt = _playAt > now ? _playAt : now + 0.2;
    source.start(_playAt);
    _playAt += buffer.duration;
    _sources.add(source);
    source.onended = ((web.Event _) => _sources.remove(source)).toJS;
    return samples.isEmpty ? 0 : math.sqrt(sum / samples.length);
  }

  void stop() {
    for (final s in List.of(_sources)) {
      try {
        s.stop();
      } catch (_) {}
    }
    _sources.clear();
    _playAt = 0;
  }
}
