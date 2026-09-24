import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Reads and writes the settings that are not sensitive: the general
/// AppSettings (timezone, lookahead days) and, for each source, the
/// plain, non secret fields such as a school's base url or whether that
/// source is set to use single sign on. None of the values stored here
/// would harm a student if exposed, unlike tokens, passwords, and
/// calendar feed urls, which live in CredentialStore instead.
///
/// Only the fields Phase 3 actually uses, AppSettings and Canvas's non
/// secret fields, are implemented so far. Blackboard's and Gradescope's
/// equivalents are added alongside their own connectors in later
/// phases, see the project plan's phased build order.
class PreferencesStore {
  static const _timeZoneKey = 'time_zone';
  static const _lookaheadDaysKey = 'lookahead_days';
  static const _canvasBaseUrlKey = 'canvas_base_url';
  static const _canvasUseSsoKey = 'canvas_use_sso';

  Future<AppSettings> readAppSettings() async {
    final prefs = await SharedPreferences.getInstance();
    const defaults = AppSettings();
    return AppSettings(
      timeZone: prefs.getString(_timeZoneKey) ?? defaults.timeZone,
      lookaheadDays: prefs.getInt(_lookaheadDaysKey) ?? defaults.lookaheadDays,
    );
  }

  Future<void> writeAppSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_timeZoneKey, settings.timeZone);
    await prefs.setInt(_lookaheadDaysKey, settings.lookaheadDays);
  }

  Future<String?> readCanvasBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_canvasBaseUrlKey);
  }

  Future<void> writeCanvasBaseUrl(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await prefs.remove(_canvasBaseUrlKey);
    } else {
      await prefs.setString(_canvasBaseUrlKey, value);
    }
  }

  Future<bool> readCanvasUseSso() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_canvasUseSsoKey) ?? false;
  }

  Future<void> writeCanvasUseSso(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_canvasUseSsoKey, value);
  }
}
