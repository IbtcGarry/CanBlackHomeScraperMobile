/// The three services this app can pull assignments from.
enum Source {
  /// Instructure Canvas. Reachable by a personal access token, a shared
  /// single sign on session, or a personal calendar feed, tried in that
  /// order of richness by [CanvasConnector].
  canvas,

  /// Blackboard Learn. Reachable by a personal calendar feed or a shared
  /// single sign on session, tried in that order by
  /// [BlackboardConnector].
  blackboard,

  /// Gradescope. Has no public interface at all, so it always needs a
  /// logged in session, either its own email and password or a shared
  /// single sign on session.
  gradescope,
}

/// A short, student facing name for each [Source], shown in the status
/// bar and throughout settings.
extension SourceLabel on Source {
  String get label {
    switch (this) {
      case Source.canvas:
        return 'Canvas';
      case Source.blackboard:
        return 'Blackboard';
      case Source.gradescope:
        return 'Gradescope';
    }
  }
}
