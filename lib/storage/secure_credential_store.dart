import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Key names for every secret value this app stores. Grouped here so
/// every reader and writer of a given secret uses the exact same key.
///
/// A personal calendar feed url is included here, in secure storage,
/// rather than in the plain preferences store, since anyone holding
/// that url can read a student's due dates without signing in at all;
/// it is effectively a bearer secret, the same reasoning the project's
/// security notes give for treating it carefully.
class CredentialKeys {
  static const canvasToken = 'canvas_token';
  static const canvasIcalUrl = 'canvas_ical_url';
  static const canvasUsername = 'canvas_username';
  static const canvasPassword = 'canvas_password';

  const CredentialKeys._();
}

/// A minimal key value contract for secret data: access tokens,
/// passwords, personal calendar feed urls, and later the raw single
/// sign on session cookie value.
///
/// Defined as an interface, with SecureCredentialStore below as the
/// real, device backed implementation, so tests can substitute an in
/// memory fake instead of touching a real device's encrypted storage.
abstract class CredentialStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// The real, encrypted implementation, backed by the iOS Keychain and
/// the Android Keystore through package flutter_secure_storage. Every
/// secret this app holds, a Canvas token, a Blackboard or Gradescope
/// password, a calendar feed url, or a captured single sign on session
/// cookie, is written here, never in plain preferences.
class SecureCredentialStore implements CredentialStore {
  final FlutterSecureStorage _storage;

  SecureCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// A plain, process only fake used by tests, so credential dependent
/// logic can be tested without a real device's secure storage.
class InMemoryCredentialStore implements CredentialStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
