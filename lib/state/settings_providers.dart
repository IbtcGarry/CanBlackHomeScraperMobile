import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/source_config.dart';
import '../session/shared_session_manager.dart';
import '../storage/preferences_store.dart';
import '../storage/secure_credential_store.dart';

/// The single PreferencesStore instance the app uses. A Provider rather
/// than a plain global, so a test can override it if it ever needs to.
final preferencesStoreProvider = Provider<PreferencesStore>(
  (ref) => PreferencesStore(),
);

/// The single CredentialStore instance the app uses for secret data.
/// Overridden with InMemoryCredentialStore in tests so nothing touches
/// a real device's encrypted storage.
final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => SecureCredentialStore(),
);

/// The single SharedSessionManager instance the app uses to load and
/// save single sign on sessions, built on top of whichever
/// CredentialStore is in scope so a test can reach the same in memory
/// sessions a SsoWebviewLoginScreen would save on a real device.
final sharedSessionManagerProvider = Provider<SharedSessionManager>(
  (ref) => SharedSessionManager(ref.read(credentialStoreProvider)),
);

/// Holds the general, cross source settings (timezone, lookahead days),
/// loaded from and saved to PreferencesStore.
class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() {
    return ref.read(preferencesStoreProvider).readAppSettings();
  }

  /// Saves new settings and updates the provider's state to match, so
  /// every widget watching it rebuilds with the new values. Named save
  /// rather than update, since AsyncNotifier already declares a
  /// differently shaped inherited method with that name.
  Future<void> save(AppSettings settings) async {
    await ref.read(preferencesStoreProvider).writeAppSettings(settings);
    state = AsyncData(settings);
  }
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
      AppSettingsNotifier.new,
    );

/// Holds Canvas's settings, split across PreferencesStore for the non
/// secret fields (base url, whether single sign on is turned on) and
/// CredentialStore for the token, the calendar feed url, and any
/// username and password, see the note on CredentialKeys for why a
/// calendar feed url counts as a secret here.
class CanvasConfigNotifier extends AsyncNotifier<CanvasConfig> {
  @override
  Future<CanvasConfig> build() async {
    final prefs = ref.read(preferencesStoreProvider);
    final credentials = ref.read(credentialStoreProvider);

    final baseUrl = await prefs.readCanvasBaseUrl();
    final useSso = await prefs.readCanvasUseSso();
    final token = await credentials.read(CredentialKeys.canvasToken);
    final icalUrl = await credentials.read(CredentialKeys.canvasIcalUrl);
    final username = await credentials.read(CredentialKeys.canvasUsername);
    final password = await credentials.read(CredentialKeys.canvasPassword);

    return CanvasConfig(
      baseUrl: baseUrl,
      useSso: useSso,
      token: token,
      icalUrl: icalUrl,
      username: username,
      password: password,
    );
  }

  /// Saves a new Canvas configuration across both stores and updates
  /// the provider's state to match. Named save rather than update,
  /// since AsyncNotifier already declares a differently shaped
  /// inherited method with that name.
  Future<void> save(CanvasConfig config) async {
    final prefs = ref.read(preferencesStoreProvider);
    final credentials = ref.read(credentialStoreProvider);

    await prefs.writeCanvasBaseUrl(config.baseUrl);
    await prefs.writeCanvasUseSso(config.useSso);
    await _writeOrDelete(credentials, CredentialKeys.canvasToken, config.token);
    await _writeOrDelete(
      credentials,
      CredentialKeys.canvasIcalUrl,
      config.icalUrl,
    );
    await _writeOrDelete(
      credentials,
      CredentialKeys.canvasUsername,
      config.username,
    );
    await _writeOrDelete(
      credentials,
      CredentialKeys.canvasPassword,
      config.password,
    );

    state = AsyncData(config);
  }

  Future<void> _writeOrDelete(
    CredentialStore store,
    String key,
    String? value,
  ) async {
    if (value == null || value.isEmpty) {
      await store.delete(key);
    } else {
      await store.write(key, value);
    }
  }
}

final canvasConfigProvider =
    AsyncNotifierProvider<CanvasConfigNotifier, CanvasConfig>(
      CanvasConfigNotifier.new,
    );
