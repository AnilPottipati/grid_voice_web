import 'chat_item.dart';
import 'live_phase.dart';

class LiveState {
  const LiveState({
    this.phase = LivePhase.idle,
    this.hearing = false,
    this.lookup = '',
    this.level = 0,
    this.items = const [],
    this.message,
    this.wakeText = '',
  });

  final LivePhase phase;

  /// The server heard you start speaking.
  final bool hearing;

  /// What the assistant is doing while it thinks ("Looking that up…").
  final String lookup;

  /// Loudness 0 to 1, so the orb moves with your voice.
  final double level;
  final List<ChatItem> items;

  /// A short message to show on top (errors).
  final String? message;

  /// What the wake word is doing ("Say Hey Grid"), empty when it is off.
  final String wakeText;

  bool get active => phase != LivePhase.idle;

  String get statusText {
    switch (phase) {
      case LivePhase.idle:
        return wakeText.isNotEmpty ? wakeText : 'Tap to talk';
      case LivePhase.listening:
        return hearing ? 'Hearing you…' : 'Listening… just speak. Tap to stop';
      case LivePhase.thinking:
        return lookup.isEmpty ? 'Thinking…' : lookup;
      case LivePhase.speaking:
        return 'Speaking… just speak or tap to interrupt';
    }
  }

  LiveState copyWith({
    LivePhase? phase,
    bool? hearing,
    String? lookup,
    double? level,
    List<ChatItem>? items,
    String? message,
    String? wakeText,
    bool clearMessage = false,
  }) => LiveState(
    phase: phase ?? this.phase,
    hearing: hearing ?? this.hearing,
    lookup: lookup ?? this.lookup,
    level: level ?? this.level,
    items: items ?? this.items,
    message: clearMessage ? null : (message ?? this.message),
    wakeText: wakeText ?? this.wakeText,
  );
}
