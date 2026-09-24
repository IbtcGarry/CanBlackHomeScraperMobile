import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:canblackhomescraper_mobile/models/source_config.dart';
import 'package:canblackhomescraper_mobile/state/settings_providers.dart';
import 'package:canblackhomescraper_mobile/storage/secure_credential_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        credentialStoreProvider.overrideWithValue(InMemoryCredentialStore()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('canvasConfigProvider', () {
    test('starts empty when nothing has been saved yet', () async {
      final container = makeContainer();
      final config = await container.read(canvasConfigProvider.future);

      expect(config.baseUrl, isNull);
      expect(config.token, isNull);
      expect(config.icalUrl, isNull);
      expect(config.isConfigured, isFalse);
    });

    test('saving updates the provider state immediately', () async {
      final container = makeContainer();
      await container.read(canvasConfigProvider.future);

      await container
          .read(canvasConfigProvider.notifier)
          .save(
            const CanvasConfig(
              baseUrl: 'https://canvas.example.edu',
              token: 'a real token',
            ),
          );

      final state = container.read(canvasConfigProvider);
      expect(state.value?.baseUrl, 'https://canvas.example.edu');
      expect(state.value?.token, 'a real token');
      expect(state.value?.isConfigured, isTrue);
    });

    test('a saved token and base url survive a fresh read, split across the two stores', () async {
      final firstContainer = makeContainer();
      final credentials = firstContainer.read(credentialStoreProvider);
      await firstContainer
          .read(canvasConfigProvider.notifier)
          .save(
            const CanvasConfig(
              baseUrl: 'https://canvas.example.edu',
              token: 'a real token',
              icalUrl: 'https://canvas.example.edu/feed.ics',
            ),
          );

      // A second, independent container, sharing the same credential
      // store and the same mocked shared preferences, stands in for a
      // fresh app launch reading back what an earlier launch saved.
      final secondContainer = ProviderContainer(
        overrides: [credentialStoreProvider.overrideWithValue(credentials)],
      );
      addTearDown(secondContainer.dispose);

      final reloaded = await secondContainer.read(canvasConfigProvider.future);
      expect(reloaded.baseUrl, 'https://canvas.example.edu');
      expect(reloaded.token, 'a real token');
      expect(reloaded.icalUrl, 'https://canvas.example.edu/feed.ics');
    });

    test('saving an empty token clears it rather than storing an empty string', () async {
      final container = makeContainer();
      await container
          .read(canvasConfigProvider.notifier)
          .save(const CanvasConfig(token: 'a real token'));
      await container
          .read(canvasConfigProvider.notifier)
          .save(const CanvasConfig(token: ''));

      final credentials = container.read(credentialStoreProvider);
      expect(await credentials.read(CredentialKeys.canvasToken), isNull);
    });
  });
}
