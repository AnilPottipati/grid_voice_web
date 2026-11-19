class VoiceOption {
  const VoiceOption({
    required this.name,
    required this.gender,
    required this.tone,
  });

  factory VoiceOption.fromJson(Map<String, dynamic> j) => VoiceOption(
    name: '${j['name']}',
    gender: '${j['gender'] ?? ''}',
    tone: '${j['tone'] ?? ''}',
  );

  final String name;
  final String gender;
  final String tone;

  String get label => '$name · $tone ($gender)';
}

class StyleOption {
  const StyleOption({required this.key, required this.label});

  factory StyleOption.fromJson(Map<String, dynamic> j) =>
      StyleOption(key: '${j['key']}', label: '${j['label']}');

  final String key;
  final String label;
}

/// What the server tells the app before it starts (`/api/live/config`).
class ServerConfig {
  const ServerConfig({
    required this.authRequired,
    required this.voices,
    required this.styles,
    required this.defaultVoice,
    required this.voiceLock,
  });

  factory ServerConfig.fromJson(Map<String, dynamic> j) => ServerConfig(
    authRequired: j['auth_required'] == true,
    voiceLock: j['voicelock'] == true,
    defaultVoice: '${j['default_voice'] ?? 'Puck'}',
    voices: [
      for (final v in (j['voices'] as List? ?? const []))
        VoiceOption.fromJson(v as Map<String, dynamic>),
    ],
    styles: [
      for (final s in (j['styles'] as List? ?? const []))
        StyleOption.fromJson(s as Map<String, dynamic>),
    ],
  );

  final bool authRequired;
  final bool voiceLock;
  final String defaultVoice;
  final List<VoiceOption> voices;
  final List<StyleOption> styles;
}
