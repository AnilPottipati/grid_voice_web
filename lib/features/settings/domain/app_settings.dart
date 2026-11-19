/// What the user picked in Settings. Saved on the device.
class AppSettings {
  const AppSettings({
    this.replyLanguage = 'auto',
    this.voiceGender = '',
    this.voice,
    this.style = 'natural',
    this.bargeIn = true,
    this.wake = false,
    this.wakeThreshold = 0.5,
    this.wakeNeed = 2,
  });

  /// `auto` (same as spoken), or `en`, `te`, `hi`, `kn`.
  final String replyLanguage;

  /// `''` (any), `male` or `female`: narrows the list of voices.
  final String voiceGender;

  /// The assistant's voice name; null means the server's default.
  final String? voice;
  final String style;

  /// Speak over the assistant to interrupt it.
  final bool bargeIn;

  /// Listen for "Hey Grid" while idle.
  final bool wake;

  /// 0.1 to 0.99; lower wakes more easily.
  final double wakeThreshold;

  /// Matches in a row needed to wake (1 to 6).
  final int wakeNeed;

  AppSettings copyWith({
    String? replyLanguage,
    String? voiceGender,
    String? voice,
    String? style,
    bool? bargeIn,
    bool? wake,
    double? wakeThreshold,
    int? wakeNeed,
  }) => AppSettings(
    replyLanguage: replyLanguage ?? this.replyLanguage,
    voiceGender: voiceGender ?? this.voiceGender,
    voice: voice ?? this.voice,
    style: style ?? this.style,
    bargeIn: bargeIn ?? this.bargeIn,
    wake: wake ?? this.wake,
    wakeThreshold: wakeThreshold ?? this.wakeThreshold,
    wakeNeed: wakeNeed ?? this.wakeNeed,
  );
}
