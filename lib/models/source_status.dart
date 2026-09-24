import 'source.dart';

/// The result of running one [Source]'s connector a single time: how
/// many assignments it returned, or why it failed.
///
/// Shown in the status bar so the student can see at a glance which
/// sources are working and which one needs attention, the same
/// information the desktop tool's own status line shows.
class SourceStatus {
  final Source source;

  /// How many assignments this source returned. Zero both when the
  /// source genuinely has nothing due and when it failed outright, so
  /// always check [error] to tell those two cases apart.
  final int count;

  /// A short, human readable explanation of why this source failed, or
  /// null when it succeeded.
  final String? error;

  const SourceStatus({required this.source, required this.count, this.error});

  /// True when this source's connector ran without error.
  bool get succeeded => error == null;
}
