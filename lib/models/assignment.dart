import 'assignment_kind.dart';
import 'source.dart';

/// One assignment, quiz, exam, or reading item pulled from a [Source]
/// and normalized into a single shape every part of this app works
/// with, regardless of which service it came from.
///
/// This mirrors the desktop tool's own normalized assignment shape, so
/// anyone already familiar with that tool will recognize every field
/// here.
class Assignment {
  /// A stable identifier, prefixed by its source, for example
  /// "canvas:12345". Stable across refreshes so the completion store and
  /// the deduplication logic in the aggregator can key off of it safely.
  final String id;

  /// Which service this assignment came from.
  final Source source;

  /// The course or class this assignment belongs to, as given by the
  /// source, for example "Math 218 Applied Linear Algebra".
  final String course;

  /// The assignment's title, as given by the source.
  final String title;

  /// What kind of item this is, decided by classifying [title], see
  /// classifyAssignment in the classification library.
  final AssignmentKind kind;

  /// When this assignment is due, always in Coordinated Universal Time.
  /// Null when the source did not give a due date at all.
  final DateTime? dueAt;

  /// True when [dueAt] has no meaningful time of day and should be shown
  /// as a plain date rather than a date and time.
  final bool allDay;

  /// A link to view this assignment on the source's own site, when the
  /// source provided one.
  final String? url;

  /// How many points this assignment is worth, when known. Only
  /// Canvas's richer strategies, its personal access token and its
  /// single sign on session, provide this.
  final double? points;

  /// Best effort submission state. False whenever the source does not
  /// say one way or the other, so this field should be read as "known
  /// submitted" rather than "known not submitted".
  final bool submitted;

  const Assignment({
    required this.id,
    required this.source,
    required this.course,
    required this.title,
    required this.kind,
    required this.dueAt,
    required this.allDay,
    required this.url,
    required this.points,
    required this.submitted,
  });

  /// Returns a copy of this assignment with the given fields replaced.
  /// Used by the aggregator when it needs to build a merged record from
  /// two duplicate entries reported by different sources.
  Assignment copyWith({
    String? id,
    Source? source,
    String? course,
    String? title,
    AssignmentKind? kind,
    DateTime? dueAt,
    bool? allDay,
    String? url,
    double? points,
    bool? submitted,
  }) {
    return Assignment(
      id: id ?? this.id,
      source: source ?? this.source,
      course: course ?? this.course,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      dueAt: dueAt ?? this.dueAt,
      allDay: allDay ?? this.allDay,
      url: url ?? this.url,
      points: points ?? this.points,
      submitted: submitted ?? this.submitted,
    );
  }
}

/// Builds the stable, source prefixed id used by [Assignment.id]. For
/// example, makeAssignmentId(Source.canvas, 12345) returns
/// "canvas:12345".
String makeAssignmentId(Source source, Object localId) {
  return '${source.name}:$localId';
}
