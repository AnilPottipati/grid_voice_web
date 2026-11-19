import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_settings.dart';

/// Reads and writes [AppSettings] on the device. The keys match the old web
/// page, so nothing is lost for people who used it in the same browser.
class SettingsRepository {
  const SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  AppSettings load() => AppSettings(
    replyLanguage: _prefs.getString('live.lang') ?? 'auto',
    voiceGender: _prefs.getString('live.vgender') ?? '',
    voice: _prefs.getString('live.voice'),
    style: _prefs.getString('live.style') ?? 'natural',
    bargeIn: _prefs.getString('live.bargein') != '0',
    wake: _prefs.getString('live.wake') == '1',
    wakeThreshold: _threshold(_prefs.getString('live.waketh')),
    wakeNeed: _need(_prefs.getString('live.wakeneed')),
  );

  static double _threshold(String? v) {
    final d = double.tryParse(v ?? '');
    return d != null && d >= 0.1 && d <= 0.99 ? d : 0.5;
  }

  static int _need(String? v) {
    final n = int.tryParse(v ?? '');
    return n != null && n >= 1 && n <= 6 ? n : 2;
  }

  Future<void> save(AppSettings s) async {
    await _prefs.setString('live.lang', s.replyLanguage);
    await _prefs.setString('live.vgender', s.voiceGender);
    if (s.voice != null) await _prefs.setString('live.voice', s.voice!);
    await _prefs.setString('live.style', s.style);
    await _prefs.setString('live.bargein', s.bargeIn ? '1' : '0');
    await _prefs.setString('live.wake', s.wake ? '1' : '0');
    await _prefs.setString('live.waketh', s.wakeThreshold.toStringAsFixed(2));
    await _prefs.setString('live.wakeneed', '${s.wakeNeed}');
  }

  String? get chosenUserKey => _prefs.getString('grid.chosen.key');
  String? get chosenUserName => _prefs.getString('grid.chosen.name');

  Future<void> saveChosenUser(String key, String name) async {
    await _prefs.setString('grid.chosen.key', key);
    await _prefs.setString('grid.chosen.name', name);
  }
}
