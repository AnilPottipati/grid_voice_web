import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

@JS('GridWake.available')
external bool _available();

@JS('GridWake.start')
external JSPromise<JSAny?> _start(
  JSNumber threshold,
  JSNumber need,
  JSFunction onWake,
  JSFunction onError,
);

@JS('GridWake.stop')
external web.MediaStream? _stop(JSBoolean keepStream);

@JS('GridWake.resume')
external void _resume();

@JS('GridWake.status')
external String _status();

@JS('GridWake.downloadClip')
external void _downloadClip();

/// What the wake word is doing right now.
class WakeStatus {
  const WakeStatus({
    this.on = false,
    this.warm = false,
    this.score = 0,
    this.peak = 0,
    this.error = '',
  });

  final bool on;
  final bool warm;
  final double score;
  final double peak;
  final String error;

  /// The browser wants one tap before it lets the microphone run.
  bool get needsTap => error == 'tap';
}

/// "Hey Grid": three small models run in the browser (see web/wake/).
/// Nothing is sent anywhere while it listens.
class WakeWord {
  const WakeWord._();

  static bool get available {
    try {
      return _available();
    } catch (_) {
      return false;
    }
  }

  /// Starts listening. [onWake] gets the still-open microphone stream (so
  /// live mode can take it over without losing the first words) and the last
  /// moments of audio (16 kHz, 16-bit) for the voice check.
  static Future<void> start({
    required double threshold,
    required int need,
    required void Function(web.MediaStream stream, Int16List clip) onWake,
    required void Function(String message) onError,
  }) async {
    await _start(
      threshold.toJS,
      need.toJS,
      ((web.MediaStream stream, JSInt16Array clip) {
        onWake(stream, clip.toDart);
      }).toJS,
      ((JSString message) => onError(message.toDart)).toJS,
    ).toDart;
  }

  /// Stops listening. With [keepStream] the microphone stays open and is
  /// returned.
  static web.MediaStream? stop({bool keepStream = false}) {
    try {
      return _stop(keepStream.toJS);
    } catch (_) {
      return null;
    }
  }

  static void resume() {
    try {
      _resume();
    } catch (_) {}
  }

  static WakeStatus status() {
    try {
      final j = jsonDecode(_status()) as Map<String, dynamic>;
      return WakeStatus(
        on: j['on'] == true,
        warm: j['warm'] == true,
        score: (j['score'] as num?)?.toDouble() ?? 0,
        peak: (j['peak'] as num?)?.toDouble() ?? 0,
        error: '${j['error'] ?? ''}',
      );
    } catch (_) {
      return const WakeStatus();
    }
  }

  /// Saves the last 3 seconds heard as a WAV file (never uploaded).
  static void downloadClip() {
    try {
      _downloadClip();
    } catch (_) {}
  }
}
