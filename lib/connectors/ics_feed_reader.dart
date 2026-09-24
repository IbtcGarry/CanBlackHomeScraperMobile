import 'package:dio/dio.dart';

import '../classification/assignment_classifier.dart';
import '../models/assignment.dart';
import '../models/source.dart';
import '../parsing/ics_parser.dart';

/// A generic reader for any learning management system that exposes a
/// personal calendar feed url. Used by both CanvasConnector and
/// BlackboardConnector when they fall back to their calendar feed
/// strategy, so the fetch, parse, filter, and normalize logic below is
/// written once and shared rather than duplicated in each connector.
///
/// Every event with a start date becomes an Assignment. Submission
/// state is never knowable from a feed alone, so it is always reported
/// as false.
Future<List<Assignment>> fetchIcsFeedAssignments(
  Source source,
  String url, {
  required Dio client,
}) async {
  final response = await client.get<String>(
    url,
    options: Options(
      headers: {'Accept': 'text/calendar'},
      responseType: ResponseType.plain,
    ),
  );
  final body = response.data ?? '';
  final events = parseIcs(body);

  final results = <Assignment>[];
  var floatingIndex = 0;
  for (final event in events) {
    if (event.start == null) continue;
    if (!_isActionable(source, event.uid, event.summary)) continue;

    final title = _cleanTitle(event.summary);
    final localId = event.uid ?? 'feed item ${floatingIndex++}';
    results.add(
      Assignment(
        id: makeAssignmentId(source, localId),
        source: source,
        course:
            _extractCourse(event.summary, event.description) ??
            _capitalize(source.name),
        title: title,
        kind: classifyAssignment(title),
        dueAt: event.start,
        allDay: event.allDay,
        url: event.url,
        points: null,
        submitted: false,
      ),
    );
  }
  return results;
}

/// A calendar feed mixes real graded work with things a student cannot
/// turn in: office hours, holidays, lectures, labs. This drops those.
///
/// Both Canvas and Blackboard encode the distinction inside the event
/// id itself, using a fixed separator character that is part of each
/// service's own id format, not this project's own documentation, the
/// same reasoning covered in the note on assignment_classifier's prep
/// pattern.
///
/// Canvas: an id containing the words event, assignment, and a number
/// joined by that separator means a real due date, keep it; an id
/// containing event, calendar, and event again joined the same way
/// means a plain calendar entry, drop it.
///
/// Blackboard: an id containing the text GradableItem means a graded
/// column, keep it; an id containing the text CalendarEntry means a
/// plain entry, drop it.
///
/// When the id does not clearly match either service's pattern, this
/// falls back to a small list of title phrases that usually mean the
/// item is not gradable work.
bool _isActionable(Source source, String? uid, String? summary) {
  if (uid != null) {
    if (source == Source.canvas) {
      if (RegExp(r'event-assignment-', caseSensitive: false).hasMatch(uid)) {
        return true;
      }
      if (RegExp(
        r'event-calendar-event-',
        caseSensitive: false,
      ).hasMatch(uid)) {
        return false;
      }
    }
    if (source == Source.blackboard) {
      if (RegExp('GradableItem', caseSensitive: false).hasMatch(uid)) {
        return true;
      }
      if (RegExp('CalendarEntry', caseSensitive: false).hasMatch(uid)) {
        return false;
      }
    }
  }

  final s = (summary ?? '').toLowerCase();
  for (final pattern in _noiseTitlePatterns) {
    if (pattern.hasMatch(s)) return false;
  }
  return true;
}

/// Title phrases that usually mean an event is not gradable work, even
/// when its id did not clearly say so. The office hours pattern's
/// trailing separator character, matching a name that follows a short
/// label such as an instructor's initials, is a literal character found
/// in real external titles, the same reasoning as elsewhere in this
/// file.
final List<RegExp> _noiseTitlePatterns = [
  RegExp(r'office hour'),
  RegExp(r'\boh\b.*-'),
  RegExp(r'\bno class\b'),
  RegExp(r'\bholiday\b'),
  RegExp(r'\bbreak\b.*\b(week|day)\b'),
  RegExp(r'^lecture\b'),
  RegExp(r'^lab(s)?\b'),
  RegExp(r'lecture\s*\d*\s*$'),
];

/// Tidies a feed's raw title: drops a trailing "[COURSE]" tag, since
/// that is pulled separately into the course field by
/// [_extractCourse], and drops a redundant trailing due date phrase,
/// since the date is already shown separately by the calendar and
/// agenda screens.
///
/// The separator characters inside the due date pattern below, a plain
/// hyphen plus the two longer dash characters some feeds use instead,
/// match how that trailing phrase is literally punctuated in real
/// external titles. They are literal characters found in that external
/// data, not part of this project's own documentation.
String _cleanTitle(String? summary) {
  if (summary == null) return '(untitled)';
  final withoutCourseTag = summary.replaceAll(
    RegExp(r'\s*\[[^\]]+\]\s*$'),
    '',
  );
  final withoutDueSuffix = withoutCourseTag.replaceAll(
    RegExp(
      r'\s*[\-–—]\s*due\s+\d{1,2}/\d{1,2}(/\d{2,4})?\s*(\([^)]*\))?\s*$',
      caseSensitive: false,
    ),
    '',
  );
  final cleaned = withoutDueSuffix.trim();
  return cleaned.isNotEmpty ? cleaned : summary.trim();
}

/// Feeds often bake the course into the title or the description, for
/// example a trailing bracketed course tag, a leading course code, or a
/// trailing course code after the same separator character covered in
/// the note on [_cleanTitle]. Best effort only.
String? _extractCourse(String? summary, String? description) {
  final s = summary ?? '';

  final bracket = RegExp(r'\[([^\]]+)\]\s*$').firstMatch(s);
  if (bracket != null) return bracket.group(1)!.trim();

  final prefix = RegExp(
    r'^([A-Z]{2,}[\s\-]?\d{2,}[A-Z]?)\s*[:\-]',
  ).firstMatch(s);
  if (prefix != null) return prefix.group(1)!.trim();

  final suffix = RegExp(
    r'[\-–—]\s*([A-Z]{2,4}\s?\d{2,3}[A-Z]?)\s*$',
  ).firstMatch(s);
  if (suffix != null) {
    return suffix.group(1)!.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  final fromDescription = RegExp(
    r'Course:\s*(.+)',
    caseSensitive: false,
  ).firstMatch(description ?? '');
  if (fromDescription != null) return fromDescription.group(1)!.trim();

  return null;
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
