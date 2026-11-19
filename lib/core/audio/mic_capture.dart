import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// One chunk of microphone audio, straight from the browser.
typedef MicChunkHandler = void Function(Float32List samples, double sampleRate);

/// The browser's AudioContext, started from a tap.
///
/// iOS Safari only lets a page start audio from a tap, so [create] is called
/// first thing in the tap handler, before anything is awaited.
class AudioSession {
  AudioSession._(this.context);

  final web.AudioContext context;

  factory AudioSession.create() {
    final ctx = web.AudioContext(web.AudioContextOptions(sampleRate: 16000));
    // Start now, while the tap is fresh. Safari may leave it suspended
    // otherwise, and then nothing plays and no microphone audio arrives.
    ctx.resume();
    return AudioSession._(ctx);
  }

  double get sampleRate => context.sampleRate.toDouble();

  /// Wake the context if the system paused it (a phone call, lock screen…).
  void resume() {
    if (context.state != 'running' && context.state != 'closed') {
      context.resume();
    }
  }

  Future<void> close() async {
    try {
      await context.close().toDart;
    } catch (_) {}
  }
}

/// The microphone, tapped through an AudioWorklet.
class MicCapture {
  MicCapture._(this._stream, this._node, this._silence);

  final web.MediaStream _stream;
  final web.AudioWorkletNode _node;
  final web.GainNode _silence;

  static const _workletSource =
      'class P extends AudioWorkletProcessor{process(i){const c=i[0][0];'
      'if(c)this.port.postMessage(c.slice(0));return true}}'
      'registerProcessor("pcm-tap",P);';

  /// Opens the microphone and starts sending chunks to [onChunk].
  /// Throws when the microphone is not allowed.
  static Future<MicCapture> start(
    AudioSession session,
    MicChunkHandler onChunk, {
    web.MediaStream? stream,
  }) async {
    final constraints = {
      'audio': {
        'channelCount': 1,
        'echoCancellation': true,
        'noiseSuppression': true,
      },
    }.jsify() as web.MediaStreamConstraints;
    // A stream handed over by the wake word is already open, so the first
    // words after "Hey Grid" are not lost.
    final media =
        stream ??
        await web.window.navigator.mediaDevices
            .getUserMedia(constraints)
            .toDart;

    final ctx = session.context;
    final blob = web.Blob(
      [_workletSource.toJS].toJS,
      web.BlobPropertyBag(type: 'application/javascript'),
    );
    final url = web.URL.createObjectURL(blob);
    await ctx.audioWorklet.addModule(url).toDart;
    web.URL.revokeObjectURL(url);

    final node = web.AudioWorkletNode(ctx, 'pcm-tap');
    final rate = session.sampleRate;
    node.port.onmessage = ((web.MessageEvent e) {
      final data = e.data;
      if (data == null) return;
      onChunk((data as JSFloat32Array).toDart, rate);
    }).toJS;

    ctx.createMediaStreamSource(media).connect(node);
    // Safari only runs a worklet that is connected to the output, so it is
    // connected through a gain of zero (the worklet makes no sound anyway).
    final silence = ctx.createGain()..gain.value = 0;
    node.connect(silence);
    silence.connect(ctx.destination);
    return MicCapture._(media, node, silence);
  }

  void stop() {
    try {
      _node.port.onmessage = null;
      _node.disconnect();
      _silence.disconnect();
    } catch (_) {}
    final tracks = _stream.getTracks().toDart;
    for (final t in tracks) {
      t.stop();
    }
  }
}
