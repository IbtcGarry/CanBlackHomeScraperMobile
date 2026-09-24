import '../models/assignment.dart';
import '../models/source.dart';

/// A read only source of assignments. Every connector in this app
/// implements this same shape, so the refresh flow can run every
/// configured connector uniformly without knowing which service each
/// one actually talks to.
abstract class Connector {
  /// Which service this connector talks to.
  Source get source;

  /// Fetches this connector's current assignment list, or throws when
  /// the fetch fails. The caller is responsible for catching that
  /// failure and turning it into a SourceStatus with an error message,
  /// so a connector itself never needs its own error swallowing logic.
  /// A connector whose single sign on strategy has no usable session
  /// yet throws SsoSessionRequiredException instead of an ordinary
  /// failure, see that class for what the caller should do about it.
  Future<List<Assignment>> fetchAssignments();
}

/// Thrown by a connector's single sign on strategy when no usable
/// session is available yet, or a previously saved one no longer
/// works. A connector cannot show the WebView login screen itself,
/// since that needs a place on screen to appear, so it throws this
/// instead. The caller, a screen, is expected to catch it, run
/// SsoWebviewLoginScreen for [sessionKey], save the resulting session
/// through SharedSessionManager, and call fetchAssignments again.
class SsoSessionRequiredException implements Exception {
  final String sessionKey;

  const SsoSessionRequiredException(this.sessionKey);

  @override
  String toString() =>
      'A single sign on session is needed for the key "$sessionKey" '
      'before this source can be read.';
}
