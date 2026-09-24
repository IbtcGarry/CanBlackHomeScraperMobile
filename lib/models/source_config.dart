/// Everything CanvasConnector needs to know, entered by the student on
/// the settings screen rather than read from a text file the way the
/// desktop tool reads its configuration.
///
/// The three strategies below are tried in this order of richness:
/// a personal access token first, a shared single sign on session
/// second, and a personal calendar feed url last, matching the desktop
/// tool's own Canvas connector.
class CanvasConfig {
  /// The school's Canvas address, for example
  /// "https://canvas.example.edu". Required by the token strategy and
  /// the single sign on strategy, not required by the calendar feed
  /// strategy.
  final String? baseUrl;

  /// A personal access token created from Canvas account settings.
  /// When present alongside [baseUrl], this is the strategy used, since
  /// it returns the richest data with the least risk.
  final String? token;

  /// A personal calendar feed url from Canvas calendar settings. Used
  /// only when neither the token strategy nor the single sign on
  /// strategy is available.
  final String? icalUrl;

  /// True when Canvas should be reached through the shared single sign
  /// on session instead of a token, see SharedSessionManager.
  final bool useSso;

  /// A Canvas only username, used for a direct login when the school
  /// has not turned on single sign on. Ignored when [useSso] is true.
  final String? username;

  /// A Canvas only password, paired with [username]. Ignored when
  /// [useSso] is true.
  final String? password;

  const CanvasConfig({
    this.baseUrl,
    this.token,
    this.icalUrl,
    this.useSso = false,
    this.username,
    this.password,
  });

  /// True when at least one of the three Canvas strategies has what it
  /// needs in order to run.
  bool get isConfigured {
    final hasToken = baseUrl != null && token != null;
    final hasSession =
        baseUrl != null && (useSso || (username != null && password != null));
    final hasIcal = icalUrl != null;
    return hasToken || hasSession || hasIcal;
  }
}

/// Everything BlackboardConnector needs. A personal calendar feed url is
/// tried first, a shared single sign on session or a direct username and
/// password second, matching the corrected priority order described in
/// the project plan (the desktop tool has this order backwards, a known
/// bug found during testing of this project).
class BlackboardConfig {
  /// A personal calendar feed url from Blackboard's own external
  /// calendar link. When present, this is always the strategy used,
  /// since it needs no login at all.
  final String? icalUrl;

  /// The school's Blackboard address. Required by the login strategy,
  /// used only when [icalUrl] is absent.
  final String? baseUrl;

  /// True when Blackboard should be reached through the shared single
  /// sign on session instead of a direct login.
  final bool useSso;

  /// A Blackboard only username, used when the school still shows a
  /// local login form rather than redirecting straight to single sign
  /// on. Ignored when [useSso] is true.
  final String? username;

  /// A Blackboard only password, paired with [username].
  final String? password;

  const BlackboardConfig({
    this.icalUrl,
    this.baseUrl,
    this.useSso = false,
    this.username,
    this.password,
  });

  bool get isConfigured {
    final hasIcal = icalUrl != null;
    final hasSession =
        baseUrl != null && (useSso || (username != null && password != null));
    return hasIcal || hasSession;
  }
}

/// Everything GradescopeConnector needs. Gradescope has no calendar feed
/// and no public interface at all, so a session is always required, one
/// way or another.
class GradescopeConfig {
  /// A Gradescope only email address, paired with [password]. Ignored
  /// when [useSso] is true.
  final String? email;

  /// A Gradescope only password, paired with [email].
  final String? password;

  /// True when Gradescope should be reached through the shared single
  /// sign on session ("log in with school credentials" on Gradescope's
  /// own sign in page) instead of an email and password.
  final bool useSso;

  const GradescopeConfig({this.email, this.password, this.useSso = false});

  bool get isConfigured {
    final hasCredentials = email != null && password != null;
    return hasCredentials || useSso;
  }
}

/// The identity provider key shared by every source configured to use
/// single sign on, so one login through SharedSessionManager can cover
/// Canvas, Blackboard, and Gradescope at once, exactly like the desktop
/// tool's own shared session file.
const String schoolSsoSessionKey = 'school sso';

/// Bundles every source's configuration together, the mobile
/// equivalent of the desktop tool's dotenv file, read and written by
/// the settings and onboarding screens instead of hand edited text.
class SourceConfig {
  final CanvasConfig canvas;
  final BlackboardConfig blackboard;
  final GradescopeConfig gradescope;

  const SourceConfig({
    this.canvas = const CanvasConfig(),
    this.blackboard = const BlackboardConfig(),
    this.gradescope = const GradescopeConfig(),
  });

  SourceConfig copyWith({
    CanvasConfig? canvas,
    BlackboardConfig? blackboard,
    GradescopeConfig? gradescope,
  }) {
    return SourceConfig(
      canvas: canvas ?? this.canvas,
      blackboard: blackboard ?? this.blackboard,
      gradescope: gradescope ?? this.gradescope,
    );
  }
}
