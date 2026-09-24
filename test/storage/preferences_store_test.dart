import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:canblackhomescraper_mobile/models/app_settings.dart';
import 'package:canblackhomescraper_mobile/storage/preferences_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PreferencesStore, app settings', () {
    test('returns the model defaults when nothing has been saved yet', () async {
      final store = PreferencesStore();
      final settings = await store.readAppSettings();
      expect(settings.timeZone, const AppSettings().timeZone);
      expect(settings.lookaheadDays, const AppSettings().lookaheadDays);
    });

    test('round trips a saved value', () async {
      final store = PreferencesStore();
      await store.writeAppSettings(
        const AppSettings(timeZone: 'America/New_York', lookaheadDays: 30),
      );

      final settings = await store.readAppSettings();
      expect(settings.timeZone, 'America/New_York');
      expect(settings.lookaheadDays, 30);
    });
  });

  group('PreferencesStore, canvas non secret fields', () {
    test('returns null and false when nothing has been saved yet', () async {
      final store = PreferencesStore();
      expect(await store.readCanvasBaseUrl(), isNull);
      expect(await store.readCanvasUseSso(), isFalse);
    });

    test('round trips the base url', () async {
      final store = PreferencesStore();
      await store.writeCanvasBaseUrl('https://canvas.example.edu');
      expect(await store.readCanvasBaseUrl(), 'https://canvas.example.edu');
    });

    test('an empty base url is treated as clearing it', () async {
      final store = PreferencesStore();
      await store.writeCanvasBaseUrl('https://canvas.example.edu');
      await store.writeCanvasBaseUrl('');
      expect(await store.readCanvasBaseUrl(), isNull);
    });

    test('round trips the use single sign on flag', () async {
      final store = PreferencesStore();
      await store.writeCanvasUseSso(true);
      expect(await store.readCanvasUseSso(), isTrue);
    });
  });
}
