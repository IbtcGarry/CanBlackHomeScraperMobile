/// A saved single sign on session for one identity provider key, for
/// example the shared "school sso" key every source can opt into.
///
/// Captures the raw cookie value obtained from a WebView login, plus
/// when it was captured, so SharedSessionManager can decide when to
/// treat it as stale and show the login screen again before even
/// attempting a request with it.
class SsoSession {
  /// Which identity provider this session belongs to. Every source
  /// configured to use the same key shares this one session, so signing
  /// in once covers all of them.
  final String key;

  /// The raw Cookie request header value captured from the WebView
  /// after a successful login, for example
  /// "JSESSIONID=abc123; other=value".
  final String cookieHeader;

  /// When this session was captured, used to estimate staleness before
  /// the app even tries a request with it.
  final DateTime capturedAt;

  const SsoSession({
    required this.key,
    required this.cookieHeader,
    required this.capturedAt,
  });
}
