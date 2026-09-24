import '../models/assignment.dart';
import '../models/source.dart';

/// Merges assignment lists from every configured source into one list,
/// removing duplicates and sorting by due date.
///
/// The same underlying piece of work sometimes appears in more than one
/// source, for example a Gradescope assignment a school also pushes
/// into Canvas. Records that share a [_dedupeKey] collapse into a
/// single entry, preferring the source that knows more about it, see
/// [_preferRicherRecord].
List<Assignment> aggregateAssignments(List<List<Assignment>> lists) {
  final byKey = <String, Assignment>{};

  for (final list in lists) {
    for (final assignment in list) {
      final key = _dedupeKey(assignment);
      final existing = byKey[key];
      if (existing == null || _preferRicherRecord(assignment, existing)) {
        byKey[key] = assignment;
      }
    }
  }

  final merged = byKey.values.toList();
  merged.sort(_byDueThenTitle);
  return merged;
}

/// Removes every assignment due further out than [lookaheadDays] days
/// from [now]. An assignment with no due date at all is always kept,
/// since there is no date to compare against, matching the desktop
/// tool's own lookahead trimming.
List<Assignment> trimToLookahead(
  List<Assignment> items, {
  required DateTime now,
  required int lookaheadDays,
}) {
  final horizon = now.add(Duration(days: lookaheadDays));
  return items
      .where((a) => a.dueAt == null || !a.dueAt!.isAfter(horizon))
      .toList();
}

/// Same underlying work reported by two sources collapses onto one key
/// built from a normalized course name, a normalized title, and the due
/// date's calendar day, or the literal text "no date" when there is
/// none, matching the desktop tool's own deduplication key exactly.
String _dedupeKey(Assignment a) {
  final title = _normalize(a.title);
  final course = _normalize(a.course);
  final day = a.dueAt == null
      ? 'no date'
      : a.dueAt!.toUtc().toIso8601String().substring(0, 10);
  return '$course|$title|$day';
}

/// Lower cases a piece of text and collapses every run of characters
/// that are not a letter or a digit into a single space, so small
/// punctuation differences between two sources never prevent a
/// duplicate from being recognized as the same assignment.
String _normalize(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// True when [candidate] should replace [current] as the record kept
/// for a deduplicated key. Canvas outranks the other two sources, since
/// its token and single sign on strategies return the richest data, and
/// a record with a known points value outranks one without, all else
/// equal.
bool _preferRicherRecord(Assignment candidate, Assignment current) {
  final candidateRank = _sourceRank(candidate.source);
  final currentRank = _sourceRank(current.source);
  if (candidateRank != currentRank) return candidateRank > currentRank;
  if (candidate.points != null && current.points == null) return true;
  return false;
}

int _sourceRank(Source source) => source == Source.canvas ? 2 : 1;

/// Orders two assignments by due date, earliest first, with any
/// assignment that has no due date at all sorted to the very end, then
/// alphabetically by title as a final tie breaker.
int _byDueThenTitle(Assignment a, Assignment b) {
  if (a.dueAt != null && b.dueAt != null) {
    return a.dueAt!.compareTo(b.dueAt!);
  }
  if (a.dueAt != null) return -1;
  if (b.dueAt != null) return 1;
  return a.title.compareTo(b.title);
}
