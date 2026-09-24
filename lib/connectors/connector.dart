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
  Future<List<Assignment>> fetchAssignments();
}
