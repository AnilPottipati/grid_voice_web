import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/prefs.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';
import '../domain/server_config.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

/// The server's options: auth on or off, the voices and the speaking styles.
final serverConfigProvider = FutureProvider<ServerConfig>((ref) async {
  final json = await ref.watch(apiClientProvider).getJson('/api/live/config');
  return ServerConfig.fromJson(json);
});

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  void _set(AppSettings next) {
    state = next;
    ref.read(settingsRepositoryProvider).save(next);
  }

  void setReplyLanguage(String v) => _set(state.copyWith(replyLanguage: v));
  void setVoiceGender(String v) => _set(state.copyWith(voiceGender: v));
  void setVoice(String v) => _set(state.copyWith(voice: v));
  void setStyle(String v) => _set(state.copyWith(style: v));
  void setBargeIn(bool v) => _set(state.copyWith(bargeIn: v));
  void setWake(bool v) => _set(state.copyWith(wake: v));
  void setWakeThreshold(double v) => _set(state.copyWith(wakeThreshold: v));
  void setWakeNeed(int v) => _set(state.copyWith(wakeNeed: v));
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
