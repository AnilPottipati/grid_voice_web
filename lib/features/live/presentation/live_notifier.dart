import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../../core/audio/mic_capture.dart';
import '../../../core/audio/pcm_player.dart';
import '../../../core/audio/pcm_resampler.dart';
import '../../../core/config/app_config.dart';
import '../../../core/wake/wake_word.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../settings/presentation/settings_providers.dart';
import '../../voice/presentation/voiceprint_notifier.dart';
import '../data/live_socket.dart';
import '../domain/chat_item.dart';
import '../domain/live_message.dart';
import '../domain/live_phase.dart';
import '../domain/live_state.dart';
import 'barge_in.dart';

const _lookupText = {
  'run_sql': 'Looking that up…',
  'search_products': 'Looking up products…',
  'my_schemes': 'Finding your schemes…',
  'prepare_order': 'Preparing the order…',
  'save_cart': 'Filling your cart…',
  'fit_cart_to_budget': 'Fitting your budget…',
  'edit_cart': 'Changing your cart…',
  'prepare_cart_order': 'Reading your cart…',
  'confirm_order': 'Placing the order…',
  'cancel_order_draft': 'Cancelling the order…',
};

/// After "Hey Grid", go back to waiting once it has been quiet this long.
const _wakeIdle = Duration(seconds: 12);

/// The voice conversation: opens the microphone and the live socket, sends
/// what you say, plays the assistant's voice, and keeps the screen's state.
///
/// The notifier's [state] is what the screen shows. The fields below the
/// state are the machinery (audio, socket, timers) that the screen never sees.
class LiveNotifier extends Notifier<LiveState> {
  AudioSession? _session;
  MicCapture? _mic;
  PcmPlayer? _player;
  PcmResampler? _resampler;
  LiveSocket? _socket;
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _ticker;
  Timer? _messageTimer;

  final BargeIn _barge = BargeIn();
  final List<Int16List> _pre = [];
  Int16List _buf = Int16List(0);

  bool _active = false;
  bool _busy = false;
  bool _hearing = false;
  bool _dropAudio = false;
  bool _turnDone = false;
  String _lookup = '';
  double _level = 0;
  int _captionIndex = -1;
  DateTime _resumeAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastActivity = DateTime.now();
  bool _starting = false;

  // "Hey Grid"
  bool _wakeArmed = false;
  bool _wakePaused = false;
  bool _wakeWarned = false;
  double _wakeTh = 0;
  int _wakeNeed = 0;
  Timer? _wakeTimer;
  Timer? _rearm;

  @override
  LiveState build() {
    ref.onDispose(() {
      _wakeTimer?.cancel();
      _rearm?.cancel();
      if (_wakeArmed) WakeWord.stop();
      _release();
    });
    ref.listen(settingsProvider, (_, _) => _syncWake());
    ref.listen(authProvider.select((s) => s.user?.key), (_, _) => _syncWake());
    _wakeTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _pollWake(),
    );
    Future.microtask(_syncWake);
    return const LiveState();
  }

  // --------------------------------------------------------------- wake word

  /// Starts or stops listening for "Hey Grid" so it matches the settings.
  void _syncWake() {
    if (!ref.mounted) return;
    final s = ref.read(settingsProvider);
    final user = ref.read(authProvider).user;
    final want =
        s.wake && user != null && !_active && !_starting && !_wakePaused;
    if (!want) {
      if (_wakeArmed) _stopWake();
      return;
    }
    if (!WakeWord.available) {
      if (!_wakeWarned) {
        _wakeWarned = true;
        _toast('The wake word could not load.');
      }
      return;
    }
    if (_wakeArmed && (_wakeTh != s.wakeThreshold || _wakeNeed != s.wakeNeed)) {
      _stopWake();
    }
    if (!_wakeArmed) _armWake(s.wakeThreshold, s.wakeNeed);
  }

  void _armWake(double threshold, int need) {
    _wakeArmed = true;
    _wakeTh = threshold;
    _wakeNeed = need;
    WakeWord.start(
      threshold: threshold,
      need: need,
      onWake: _onWake,
      onError: (message) {
        _wakeArmed = false;
        _toast('Wake word stopped: $message');
      },
    ).catchError((Object e) {
      _wakeArmed = false;
      _toast('Wake word stopped: $e');
    });
  }

  void _stopWake() {
    WakeWord.stop();
    _wakeArmed = false;
    if (state.wakeText.isNotEmpty) state = state.copyWith(wakeText: '');
  }

  void _scheduleRearm([Duration after = const Duration(milliseconds: 600)]) {
    _rearm?.cancel();
    _rearm = Timer(after, _syncWake);
  }

  /// Recording the voice (or anything else that needs the microphone) asks
  /// the wake word to wait.
  void pauseWake(bool paused) {
    _wakePaused = paused;
    if (paused) {
      _stopWake();
    } else {
      _scheduleRearm();
    }
  }

  Future<void> _onWake(web.MediaStream stream, Int16List clip) async {
    _wakeArmed = false;
    void dropMic() {
      for (final t in stream.getTracks().toDart) {
        t.stop();
      }
    }

    final user = ref.read(authProvider).user;
    if (user == null || _active || _starting) {
      dropMic();
      return;
    }
    // With a saved voice, only that voice may wake Grid.
    if (ref.read(voiceprintProvider).status.saved) {
      final ok = await ref
          .read(voiceprintRepositoryProvider)
          .wakeIsUser(user.key, clip);
      if (!ok) {
        dropMic();
        _toast('Hey Grid heard, but not in your saved voice.');
        _scheduleRearm(const Duration(milliseconds: 300));
        return;
      }
    }
    _toast('Hey Grid heard');
    await _start(given: stream, woke: true);
  }

  void _pollWake() {
    if (!ref.mounted) return;
    var text = '';
    if (_wakeArmed && !_active && !_starting) {
      final w = WakeWord.status();
      if (w.needsTap) {
        text = 'Tap anywhere once to start listening for "Hey Grid"';
      } else if (w.error.isNotEmpty) {
        text = 'Wake word problem: ${w.error}';
      } else if (!w.warm) {
        text = 'Getting ready to hear "Hey Grid"…';
      } else {
        text =
            'Say "Hey Grid"  [match ${w.score.toStringAsFixed(2)} · peak '
            '${w.peak.toStringAsFixed(2)} · needs '
            '${_wakeTh.toStringAsFixed(2)}]';
      }
    }
    if (text != state.wakeText) state = state.copyWith(wakeText: text);
  }

  /// The orb was tapped.
  Future<void> toggle() async {
    if (_starting) return;
    if (_active) {
      if (state.phase == LivePhase.speaking) {
        // Tap while it talks: interrupt, keep listening.
        _player?.stop();
        _dropAudio = true;
        _socket?.sendCommand('flush');
        return;
      }
      await stop();
    } else {
      await _start();
    }
  }

  Future<void> _start({web.MediaStream? given, bool woke = false}) async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      _dropStream(given);
      return;
    }
    _starting = true;
    _stopWake();

    // Must be first, before any await: iOS only starts audio from a tap.
    final AudioSession session;
    try {
      session = AudioSession.create();
    } catch (e) {
      _starting = false;
      _dropStream(given);
      _toast('This browser cannot play audio ($e).');
      _scheduleRearm();
      return;
    }
    _session = session;
    _active = true;
    _busy = true;
    _lookup = '';
    _publish();

    final settings = ref.read(settingsProvider);
    final config = ref.read(serverConfigProvider).value;
    try {
      _resampler = PcmResampler(session.sampleRate);
      _player = PcmPlayer(session);
      _mic = await MicCapture.start(session, _onMicChunk, stream: given);
      _socket = await LiveSocket.connect(
        AppConfig.liveSocketUri({
          'who': user.key,
          'lang': settings.replyLanguage,
          'voice': settings.voice ?? config?.defaultVoice ?? 'Puck',
          'style': settings.style,
          if (woke) 'greet': '1',
        }),
      );
    } catch (e) {
      await _release();
      _dropStream(given);
      _starting = false;
      _toast(_friendlyError(e));
      _scheduleRearm();
      return;
    }

    final socket = _socket!;
    _subs
      ..add(socket.messages.listen(_onMessage))
      ..add(socket.audio.listen(_onAudio));
    socket.onClosed.then((_) {
      if (_active && identical(_socket, socket)) {
        _toast('The connection closed. Tap the button to start again.');
        stop();
      }
    });

    _busy = false;
    _lastActivity = DateTime.now();
    _starting = false;
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
    _publish();
  }

  Future<void> stop() async {
    if (!_active && _socket == null) return;
    _socket?.sendCommand('flush');
    await _release();
    _publish();
    _scheduleRearm();
  }

  void _dropStream(web.MediaStream? stream) {
    if (stream == null) return;
    for (final t in stream.getTracks().toDart) {
      t.stop();
    }
  }

  /// Stops everything and clears the machinery, leaving the chat as it is.
  Future<void> _release() async {
    _active = false;
    _busy = false;
    _hearing = false;
    _turnDone = false;
    _lookup = '';
    _ticker?.cancel();
    _ticker = null;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _player?.stop();
    _mic?.stop();
    final session = _session;
    final socket = _socket;
    _player = null;
    _mic = null;
    _session = null;
    _socket = null;
    _buf = Int16List(0);
    _pre.clear();
    _captionIndex = -1;
    // Give the server a moment to receive the last command.
    Timer(const Duration(seconds: 1), () => socket?.close());
    await session?.close();
  }

  // ---------------------------------------------------------------- audio in

  void _onMicChunk(Float32List chunk, double rate) {
    final socket = _socket;
    final resampler = _resampler;
    final player = _player;
    if (!_active || socket == null || resampler == null || player == null) {
      return;
    }
    var sum = 0.0;
    for (final v in chunk) {
      sum += v * v;
    }
    final rms = math.sqrt(sum / chunk.length);
    _level = math.max(_level, rms);
    final samples = resampler.process(chunk);
    final talking = player.isSpeaking;
    final need = _barge.levelToBeat(rms, assistantTalking: talking);
    final now = DateTime.now();

    if (talking || now.isBefore(_resumeAt)) {
      // The assistant is talking: its own voice must not go to the server.
      _keepRecent(samples);
      final cutIn =
          talking &&
          ref.read(settingsProvider).bargeIn &&
          _barge.feed(rms, chunk.length / rate * 1000, need ?? BargeIn.minLevel);
      if (!cutIn) return;
      // The user spoke over it: stop it now, and send the last moments
      // before the cut-in so the first words are not lost.
      _barge.reset();
      player.stop();
      _dropAudio = true;
      _append(_lastMillis(350));
      _pre.clear();
    } else {
      _barge.reset();
      _pre.clear();
      _append(samples);
    }
    _flush(socket);
  }

  void _keepRecent(Int16List samples) {
    _pre.add(samples);
    var n = _pre.fold<int>(0, (a, c) => a + c.length);
    const maxSamples = 800 * 16;
    while (_pre.length > 1 && n - _pre.first.length >= maxSamples) {
      n -= _pre.first.length;
      _pre.removeAt(0);
    }
  }

  Int16List _lastMillis(int ms) {
    final all = Int16List(_pre.fold<int>(0, (a, c) => a + c.length));
    var p = 0;
    for (final c in _pre) {
      all.setAll(p, c);
      p += c.length;
    }
    final keep = math.min(all.length, ms * 16);
    return Int16List.sublistView(all, all.length - keep);
  }

  void _append(Int16List more) {
    if (more.isEmpty) return;
    final merged = Int16List(_buf.length + more.length)
      ..setAll(0, _buf)
      ..setAll(_buf.length, more);
    _buf = merged;
  }

  void _flush(LiveSocket socket) {
    const piece = 1600;
    var offset = 0;
    while (_buf.length - offset >= piece && socket.isOpen) {
      socket.sendAudio(Int16List.sublistView(_buf, offset, offset + piece));
      offset += piece;
    }
    if (offset > 0) _buf = Int16List.sublistView(_buf, offset);
  }

  // ------------------------------------------------------------ audio / text in

  void _onAudio(Uint8List bytes) {
    if (_dropAudio) return;
    final player = _player;
    if (player == null) return;
    _level = math.max(_level, player.play(bytes));
    _busy = false;
  }

  void _onMessage(LiveMessage m) {
    _lastActivity = DateTime.now();
    switch (m) {
      case ReadyMessage():
        break;
      case GateMessage():
        _onGate(m);
      case ToolStartMessage():
        _busy = true;
        _lookup = _lookupText[m.name] ?? 'Looking that up…';
      case ToolDoneMessage():
        _busy = true;
        _lookup = '';
      case SaidMessage():
        if (!_dropAudio) _caption(m.text);
      case CardMessage():
        _captionIndex = -1;
        state = state.copyWith(items: [...state.items, CardItem(m.card)]);
      case InterruptedMessage():
        _player?.stop();
        _dropAudio = false;
        _captionIndex = -1;
      case TurnCompleteMessage():
        _dropAudio = false;
        _turnDone = true;
        _captionIndex = -1;
        if (!(_player?.isSpeaking ?? false)) _busy = false;
      case ErrorMessage():
        _toast(m.message);
        _busy = false;
        if (m.isSignInProblem) {
          stop();
          ref.read(authProvider.notifier).sessionExpired();
        }
    }
  }

  void _onGate(GateMessage m) {
    switch (m.event) {
      case 'start_speech':
        _hearing = true;
      case 'end_speech':
        _hearing = false;
      case 'accepted':
        _dropAudio = false;
        _busy = true;
        _captionIndex = -1;
      case 'ignored':
        _toast('That did not sound like you (match ${m.score}).');
    }
  }

  void _caption(String text) {
    final items = [...state.items];
    if (_captionIndex < 0 || _captionIndex >= items.length) {
      items.add(CaptionItem(text));
      _captionIndex = items.length - 1;
    } else {
      final current = items[_captionIndex];
      if (current is CaptionItem) items[_captionIndex] = current.append(text);
    }
    state = state.copyWith(items: items);
  }

  // ------------------------------------------------------------------ ticker

  void _tick() {
    final session = _session;
    final player = _player;
    if (!_active || session == null || player == null) return;
    session.resume();

    // The answer has been fully played: tell the server (follow-up window).
    if (_turnDone && !player.isSpeaking) {
      _turnDone = false;
      _resumeAt = DateTime.now().add(const Duration(milliseconds: 400));
      _socket?.sendCommand('replied');
    }

    final working = _busy || _hearing || player.isSpeaking;
    if (working) {
      _lastActivity = DateTime.now();
    } else if (ref.read(settingsProvider).wake &&
        DateTime.now().difference(_lastActivity) > _wakeIdle) {
      // Woken by "Hey Grid": go back to waiting after a quiet spell.
      stop();
      return;
    } else if (DateTime.now().difference(_lastActivity) >
        AppConfig.idleStop) {
      _note('Stopped after 5 quiet minutes.');
      stop();
      return;
    }

    _level *= 0.8;
    _publish();
  }

  void _publish() {
    final player = _player;
    final LivePhase phase;
    if (!_active) {
      phase = LivePhase.idle;
    } else if (player != null && player.isSpeaking) {
      phase = LivePhase.speaking;
    } else if (_busy) {
      phase = LivePhase.thinking;
    } else {
      phase = LivePhase.listening;
    }
    final level = (phase == LivePhase.listening || phase == LivePhase.speaking)
        ? math.min(1.0, _level * 6)
        : 0.0;
    final rounded = (level * 20).round() / 20;
    if (phase == state.phase &&
        _hearing == state.hearing &&
        _lookup == state.lookup &&
        rounded == state.level) {
      return;
    }
    state = state.copyWith(
      phase: phase,
      hearing: _hearing,
      lookup: _lookup,
      level: rounded,
    );
  }

  // ---------------------------------------------------------------- messages

  void _note(String text) {
    state = state.copyWith(items: [...state.items, NoteItem(text)]);
  }

  void _toast(String text) {
    state = state.copyWith(message: text);
    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(seconds: 4), () {
      if (ref.mounted) state = state.copyWith(clearMessage: true);
    });
  }

  String _friendlyError(Object e) {
    final text = '$e';
    if (text.contains('NotAllowed') || text.contains('Permission')) {
      return 'Microphone not allowed. Allow it in the browser and try again.';
    }
    if (text.contains('NotFound')) return 'No microphone found.';
    return 'Could not start ($text).';
  }
}

final liveProvider = NotifierProvider<LiveNotifier, LiveState>(
  LiveNotifier.new,
);
