import '../models/sso_session.dart';
import '../storage/secure_credential_store.dart';

/// Owns every shared single sign on session this app has captured, one
/// per identity provider key (see schoolSsoSessionKey in
/// source_config.dart). A session captured while signing into one
/// source is available to every other source configured with the same
/// key, so one WebView login covers all of them, the same outcome the
/// desktop tool gets from its own shared browser session file, reached
/// here through a real device WebView and encrypted storage instead of
/// a headless automation browser.
class SharedSessionManager {
  final CredentialStore _credentials;

  SharedSessionManager(this._credentials);

  String _cookieKey(String sessionKey) => 'sso_session_${sessionKey}_cookie';

  String _capturedAtKey(String sessionKey) =>
      'sso_session_${sessionKey}_captured_at';

  /// Returns the saved session for [sessionKey], or null when none has
  /// been captured yet, or what was saved could not be read back as a
  /// valid session.
  Future<SsoSession?> loadSession(String sessionKey) async {
    final cookieHeader = await _credentials.read(_cookieKey(sessionKey));
    final capturedAtRaw = await _credentials.read(_capturedAtKey(sessionKey));
    if (cookieHeader == null || capturedAtRaw == null) return null;

    final capturedAt = DateTime.tryParse(capturedAtRaw);
    if (capturedAt == null) return null;

    return SsoSession(
      key: sessionKey,
      cookieHeader: cookieHeader,
      capturedAt: capturedAt,
    );
  }

  /// Saves a freshly captured session, replacing any earlier one under
  /// the same key.
  Future<void> saveSession(SsoSession session) async {
    await _credentials.write(_cookieKey(session.key), session.cookieHeader);
    await _credentials.write(
      _capturedAtKey(session.key),
      session.capturedAt.toIso8601String(),
    );
  }

  /// Clears a saved session, for example once a connector reports it no
  /// longer works, so the next attempt asks the student to sign in
  /// again immediately rather than retrying a session already known to
  /// be dead.
  Future<void> clearSession(String sessionKey) async {
    await _credentials.delete(_cookieKey(sessionKey));
    await _credentials.delete(_capturedAtKey(sessionKey));
  }
}
