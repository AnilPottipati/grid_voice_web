import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../domain/live_message.dart';

/// The WebSocket to `/ws/live`: sends microphone audio and a few text
/// commands, receives the assistant's voice and messages.
class LiveSocket {
  LiveSocket._(this._ws);

  final web.WebSocket _ws;

  final _messages = StreamController<LiveMessage>.broadcast();
  final _audio = StreamController<Uint8List>.broadcast();
  final _closed = Completer<void>();

  Stream<LiveMessage> get messages => _messages.stream;
  Stream<Uint8List> get audio => _audio.stream;
  Future<void> get onClosed => _closed.future;

  bool get isOpen => _ws.readyState == 1;

  /// Connects and waits for the server's `ready` message.
  /// Throws on a failed connection or after [timeout].
  static Future<LiveSocket> connect(
    Uri uri, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final ws = web.WebSocket(uri.toString())..binaryType = 'arraybuffer';
    final socket = LiveSocket._(ws);
    final ready = Completer<void>();

    ws.onmessage = ((web.MessageEvent e) {
      final data = e.data;
      if (data == null) return;
      if (data.isA<JSString>()) {
        final msg = LiveMessage.parse((data as JSString).toDart);
        if (msg == null) return;
        if (msg is ReadyMessage && !ready.isCompleted) ready.complete();
        socket._messages.add(msg);
      } else {
        socket._audio.add(
          (data as JSArrayBuffer).toDart.asUint8List(),
        );
      }
    }).toJS;
    ws.onerror = ((web.Event _) {
      if (!ready.isCompleted) {
        ready.completeError(Exception('connection failed'));
      }
    }).toJS;
    ws.onclose = ((web.CloseEvent _) {
      if (!ready.isCompleted) {
        ready.completeError(Exception('connection closed'));
      }
      if (!socket._closed.isCompleted) socket._closed.complete();
    }).toJS;

    try {
      await ready.future.timeout(
        timeout,
        onTimeout: () => throw Exception('timeout'),
      );
    } catch (_) {
      socket.close();
      rethrow;
    }
    return socket;
  }

  /// 16 kHz 16-bit audio from the microphone.
  void sendAudio(Int16List samples) {
    if (!isOpen) return;
    _ws.send(samples.buffer.toJS);
  }

  /// Text commands the server understands: `replied`, `flush`, `barge`…
  void sendCommand(String command) {
    if (!isOpen) return;
    _ws.send(command.toJS);
  }

  void close() {
    try {
      _ws.close();
    } catch (_) {}
  }
}
