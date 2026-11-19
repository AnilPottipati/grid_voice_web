import 'dart:typed_data';

import '../../../core/network/api_client.dart';

/// Whether this user has a saved voice (numbers only, never audio).
class VoiceprintStatus {
  const VoiceprintStatus({
    this.available = false,
    this.saved = false,
    this.quality,
  });

  factory VoiceprintStatus.fromJson(Map<String, dynamic> j) => VoiceprintStatus(
    available: j['available'] == true,
    saved: j['saved'] == true,
    quality: j['quality'] == null ? null : '${j['quality']}',
  );

  /// The server can store voices.
  final bool available;
  final bool saved;
  final String? quality;
}

class VoiceprintRepository {
  const VoiceprintRepository(this._api);

  final ApiClient _api;

  Future<VoiceprintStatus> status(String userKey) async {
    try {
      return VoiceprintStatus.fromJson(
        await _api.getJson('/api/voiceprint', query: {'user': userKey}),
      );
    } on ApiException {
      return const VoiceprintStatus();
    }
  }

  /// Saves the voice from [pcm]: the user reading a few sentences
  /// (16 kHz, 16-bit, mono). Replaces any saved voice.
  Future<void> enrol(String userKey, Int16List pcm) async {
    await _api.postBytes(
      '/api/voiceprint/enrol',
      pcm.buffer.asUint8List(pcm.offsetInBytes, pcm.lengthInBytes),
      query: {'user': userKey, 'consent': 'true'},
    );
  }

  /// Returns true when a voice was deleted.
  Future<bool> delete(String userKey) async {
    final j = await _api.delete('/api/voiceprint', query: {'user': userKey});
    return j['deleted'] != false;
  }

  /// Was "Hey Grid" said by the saved voice? Only a clear "no" returns
  /// false; if the check cannot run, anyone may wake it.
  Future<bool> wakeIsUser(String userKey, Int16List clip) async {
    try {
      final j = await _api.postBytes(
        '/api/live/wake-verify',
        clip.buffer.asUint8List(clip.offsetInBytes, clip.lengthInBytes),
        query: {'who': userKey},
      );
      return j['accepted'] != false;
    } on ApiException {
      return true;
    }
  }
}
