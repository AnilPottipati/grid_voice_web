import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/mic_capture.dart';
import '../../../core/audio/pcm_resampler.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../live/presentation/live_notifier.dart';
import '../data/voiceprint_repository.dart';

/// The three sentences to read, by language (same as the web page).
const voiceSentences = {
  'en': [
    'I would like to order some packets of atta for my shop.',
    'Please tell me which schemes are running this month.',
    'Check my last order and tell me when it will arrive.',
  ],
  'hi': [
    'मुझे अपनी दुकान के लिए आटे के कुछ पैकेट मंगवाने हैं।',
    'कृपया बताइए इस महीने कौन सी स्कीम चल रही हैं।',
    'मेरा पिछला ऑर्डर देखकर बताइए कि वह कब पहुँचेगा।',
  ],
  'te': [
    'నా దుకాణం కోసం కొన్ని ఆటా ప్యాకెట్లు ఆర్డర్ చేయాలి.',
    'ఈ నెలలో ఏ స్కీములు నడుస్తున్నాయో చెప్పండి.',
    'నా చివరి ఆర్డర్ చూసి అది ఎప్పుడు వస్తుందో చెప్పండి.',
  ],
};

const voiceLanguages = {
  'en': 'English',
  'hi': 'Hindi',
  'te': 'Telugu',
};

class VoiceprintState {
  const VoiceprintState({
    this.status = const VoiceprintStatus(),
    this.language = 'en',
    this.consent = false,
    this.recording = false,
    this.step = '',
    this.sentence = '',
    this.progress = 0,
    this.hearing = false,
    this.message,
  });

  final VoiceprintStatus status;
  final String language;
  final bool consent;

  /// The reading dialog is open.
  final bool recording;
  final String step;
  final String sentence;

  /// 0 to 1 for the current sentence.
  final double progress;
  final bool hearing;

  /// An error or result to show under the buttons.
  final String? message;

  VoiceprintState copyWith({
    VoiceprintStatus? status,
    String? language,
    bool? consent,
    bool? recording,
    String? step,
    String? sentence,
    double? progress,
    bool? hearing,
    String? message,
    bool clearMessage = false,
  }) => VoiceprintState(
    status: status ?? this.status,
    language: language ?? this.language,
    consent: consent ?? this.consent,
    recording: recording ?? this.recording,
    step: step ?? this.step,
    sentence: sentence ?? this.sentence,
    progress: progress ?? this.progress,
    hearing: hearing ?? this.hearing,
    message: clearMessage ? null : (message ?? this.message),
  );
}

final voiceprintRepositoryProvider = Provider<VoiceprintRepository>(
  (ref) => VoiceprintRepository(ref.watch(apiClientProvider)),
);

/// The saved voice of the person Grid is talking as: record it, replace it,
/// delete it. Only that voice may then wake Grid.
class VoiceprintNotifier extends Notifier<VoiceprintState> {
  bool _cancel = false;

  @override
  VoiceprintState build() {
    ref.listen(authProvider.select((s) => s.user?.key), (_, key) {
      refresh();
    });
    Future.microtask(refresh);
    return const VoiceprintState();
  }

  String? get _userKey => ref.read(authProvider).user?.key;

  Future<void> refresh() async {
    final key = _userKey;
    if (key == null) return;
    final status = await ref.read(voiceprintRepositoryProvider).status(key);
    if (!ref.mounted) return;
    state = state.copyWith(status: status);
  }

  void setLanguage(String v) => state = state.copyWith(language: v);
  void setConsent(bool v) => state = state.copyWith(consent: v);
  void skip() => _cancel = true;

  Future<void> delete() async {
    final key = _userKey;
    if (key == null) return;
    state = state.copyWith(clearMessage: true);
    try {
      final gone = await ref.read(voiceprintRepositoryProvider).delete(key);
      state = state.copyWith(
        message: gone ? 'Saved voice deleted.' : 'No saved voice was found.',
      );
    } on ApiException catch (e) {
      state = state.copyWith(message: e.message);
    }
    await refresh();
  }

  /// The user reads three sentences; the audio goes to the server, which
  /// keeps only numbers. Must be called from a tap.
  Future<void> record() async {
    final key = _userKey;
    if (key == null || state.recording) return;
    if (!state.status.saved && !state.consent) {
      state = state.copyWith(message: 'Tick the box to agree before recording.');
      return;
    }

    // Must be first, before any await: browsers start audio from a tap.
    final AudioSession session;
    try {
      session = AudioSession.create();
    } catch (e) {
      state = state.copyWith(message: 'This browser cannot record ($e).');
      return;
    }

    // Nothing may listen while the sentences are read: they are not questions.
    final live = ref.read(liveProvider.notifier);
    live.pauseWake(true);
    await live.stop();

    _cancel = false;
    state = state.copyWith(
      recording: true,
      step: 'Getting the microphone ready…',
      sentence: '',
      progress: 0,
      clearMessage: true,
    );

    MicCapture? mic;
    String? result;
    try {
      final chunks = <Int16List>[];
      var total = 0;
      var level = 0.0;
      final resampler = PcmResampler(session.sampleRate);
      mic = await MicCapture.start(session, (samples, rate) {
        final i16 = resampler.process(samples);
        chunks.add(i16);
        total += i16.length;
        var sum = 0.0;
        for (final v in samples) {
          sum += v * v;
        }
        level = math.sqrt(sum / samples.length);
      });

      final lines = voiceSentences[state.language] ?? voiceSentences['en']!;
      String? error;
      for (var attempt = 0; attempt < 2 && !_cancel; attempt++) {
        chunks.clear();
        total = 0;
        for (var i = 0; i < lines.length && !_cancel; i++) {
          state = state.copyWith(
            step:
                'Sentence ${i + 1} of ${lines.length}. '
                'Read it aloud in your normal voice:',
            sentence: lines[i],
          );
          for (var t = 0; t <= 50 && !_cancel; t++) {
            state = state.copyWith(progress: t / 50, hearing: level > 0.01);
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }
        if (_cancel) break;
        state = state.copyWith(step: 'Setting up your voice…', sentence: '');
        final all = Int16List(total);
        var o = 0;
        for (final c in chunks) {
          all.setAll(o, c);
          o += c.length;
        }
        try {
          await ref.read(voiceprintRepositoryProvider).enrol(key, all);
          result = 'Voice saved. Only this voice will wake Grid.';
          error = null;
          break;
        } on ApiException catch (e) {
          error = e.message;
          // Trying again will not change a refusal.
          if (e.status == 403 || e.status == 400) break;
          state = state.copyWith(
            step: 'That did not work: ${e.message} Let us try once more.',
          );
          await Future<void>.delayed(const Duration(milliseconds: 1500));
        }
      }
      result ??= error ?? 'The voice was not saved.';
    } catch (e) {
      final text = '$e';
      result = text.contains('NotAllowed') || text.contains('Permission')
          ? 'Microphone not allowed. Allow it in the browser and try again.'
          : 'Could not record ($text).';
    } finally {
      mic?.stop();
      await session.close();
      live.pauseWake(false);
    }
    if (!ref.mounted) return;
    state = state.copyWith(recording: false, message: result);
    await refresh();
  }
}

final voiceprintProvider =
    NotifierProvider<VoiceprintNotifier, VoiceprintState>(
      VoiceprintNotifier.new,
    );
