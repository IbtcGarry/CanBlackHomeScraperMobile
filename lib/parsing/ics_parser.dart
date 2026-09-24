import 'package:timezone/timezone.dart' as tz;

/// One event parsed out of an iCalendar feed, holding only the fields
/// this app actually uses.
class VEvent {
  final String? uid;
  final String? summary;
  final String? description;
  final String? url;

  /// Always in Coordinated Universal Time, or null when the feed's
  /// value could not be parsed or was absent.
  final DateTime? start;

  /// Always in Coordinated Universal Time, or null when the feed's
  /// value could not be parsed or was absent.
  final DateTime? end;

  /// True when the feed's start value was a bare date with no time of
  /// day at all, meaning an all day due date.
  final bool allDay;

  const VEvent({
    this.uid,
    this.summary,
    this.description,
    this.url,
    this.start,
    this.end,
    required this.allDay,
  });
}

/// A minimal RFC 5545 reader, enough to pull VEVENT blocks out of a
/// learning management system calendar feed. This is not a general
/// purpose calendar parser: it only understands line unfolding and the
/// handful of fields this app cares about, and only the DTSTART and
/// DTEND forms Canvas and Blackboard actually emit.
///
/// Requires the timezone package's database to already be loaded before
/// this is called, see initializeTimeZones from package timezone, which
/// this app calls once from main before anything else runs, since a
/// feed's DTSTART can name an arbitrary time zone through a TZID
/// parameter.
List<VEvent> parseIcs(String text) {
  final lines = _unfold(text);
  final events = <VEvent>[];
  Map<String, String>? current;

  for (final line in lines) {
    if (line == 'BEGIN:VEVENT') {
      current = {};
      continue;
    }
    if (line == 'END:VEVENT') {
      if (current != null) events.add(_toEvent(current));
      current = null;
      continue;
    }
    if (current == null) continue;

    final idx = line.indexOf(':');
    if (idx == -1) continue;
    final rawKey = line.substring(0, idx);
    final value = line.substring(idx + 1);
    final key = rawKey.split(';').first.toUpperCase();
    current[key] = value;
    // Keep the raw key, parameters included, alongside DTSTART and
    // DTEND so a later step can spot VALUE=DATE or a TZID parameter.
    if (key == 'DTSTART' || key == 'DTEND') {
      current['${key}__params'] = rawKey;
    }
  }

  return events;
}

/// Joins RFC 5545's folded continuation lines, any line starting with a
/// space or a tab, back onto the line that came before it.
List<String> _unfold(String text) {
  final raw = text.replaceAll('\r\n', '\n').split('\n');
  final out = <String>[];
  for (final line in raw) {
    if ((line.startsWith(' ') || line.startsWith('\t')) && out.isNotEmpty) {
      out[out.length - 1] += line.substring(1);
    } else {
      out.add(line);
    }
  }
  return out;
}

VEvent _toEvent(Map<String, String> f) {
  final rawSummary = f['SUMMARY'];
  final rawDescription = f['DESCRIPTION'];
  return VEvent(
    uid: f['UID'],
    summary: rawSummary != null ? _unescape(rawSummary) : null,
    description: rawDescription != null ? _unescape(rawDescription) : null,
    url: f['URL'],
    start: _parseDate(f['DTSTART'], f['DTSTART__params']),
    end: _parseDate(f['DTEND'], f['DTEND__params']),
    allDay: _isDateOnly(f['DTSTART'], f['DTSTART__params']),
  );
}

bool _isDateOnly(String? value, String? params) {
  if (value == null) return false;
  if (RegExp(r'^\d{8}$').hasMatch(value.trim())) return true;
  return RegExp(
    r'VALUE=DATE(?!-TIME)',
    caseSensitive: false,
  ).hasMatch(params ?? '');
}

String _unescape(String v) {
  return v
      .replaceAll(RegExp(r'\\n', caseSensitive: false), '\n')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\\', '\\');
}

/// Handles the DTSTART and DTEND forms real learning management system
/// feeds actually emit:
///
///   20260115T133000Z                          a plain instant in
///                                              Coordinated Universal
///                                              Time
///   DTSTART;TZID=America/Chicago:...T133000    a wall clock time in a
///                                               named zone
///   20260115T133000                            a floating time with no
///                                               zone at all, treated as
///                                               Coordinated Universal
///                                               Time for determinism
///   20260115, or VALUE=DATE                    a bare date, meaning an
///                                               all day due date
///
/// Always returns a value already converted to Coordinated Universal
/// Time, or null when the text could not be parsed at all.
DateTime? _parseDate(String? value, String? params) {
  if (value == null) return null;
  final v = value.trim();

  final dateOnlyMatch = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(v);
  final isDateOnlyParam = RegExp(
    r'VALUE=DATE(?!-TIME)',
    caseSensitive: false,
  ).hasMatch(params ?? '');

  if (dateOnlyMatch != null || isDateOnlyParam) {
    final m = dateOnlyMatch ?? RegExp(r'^(\d{4})(\d{2})(\d{2})').firstMatch(v);
    if (m == null) return null;
    final year = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final day = int.parse(m.group(3)!);
    // An all day due date is pinned to the end of that day, so it sorts
    // and buckets after any timed item on the same date and never
    // appears to fall on the day before once converted for display.
    return DateTime.utc(year, month, day, 23, 59, 59);
  }

  final full = RegExp(
    r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z)?$',
  ).firstMatch(v);
  if (full == null) return null;

  final year = int.parse(full.group(1)!);
  final month = int.parse(full.group(2)!);
  final day = int.parse(full.group(3)!);
  final hour = int.parse(full.group(4)!);
  final minute = int.parse(full.group(5)!);
  final second = int.parse(full.group(6)!);
  final hasZ = full.group(7) != null;

  if (hasZ) {
    return DateTime.utc(year, month, day, hour, minute, second);
  }

  final tzidMatch = RegExp(
    r'TZID=([^;:]+)',
    caseSensitive: false,
  ).firstMatch(params ?? '');
  if (tzidMatch != null) {
    final converted = _wallClockToUtc(
      year,
      month,
      day,
      hour,
      minute,
      second,
      tzidMatch.group(1)!.trim(),
    );
    if (converted != null) return converted;
  }

  // Floating time, no usable zone at all: treat the wall clock as
  // Coordinated Universal Time for determinism, matching the desktop
  // tool's own fallback for this rare case.
  return DateTime.utc(year, month, day, hour, minute, second);
}

/// Converts a wall clock time in a named IANA time zone into a
/// Coordinated Universal Time instant, daylight saving included.
///
/// Unlike the desktop tool's own version of this function, which has to
/// approximate the answer through a guess and correct technique since
/// the browser has no direct wall clock to zoned instant conversion,
/// package timezone's TZDateTime constructor does this exactly and
/// directly, so this function is a thin, more precise equivalent of the
/// same idea.
DateTime? _wallClockToUtc(
  int year,
  int month,
  int day,
  int hour,
  int minute,
  int second,
  String timeZoneName,
) {
  try {
    final location = tz.getLocation(timeZoneName);
    final wallClock = tz.TZDateTime(
      location,
      year,
      month,
      day,
      hour,
      minute,
      second,
    );
    return wallClock.toUtc();
  } catch (_) {
    return null; // an unknown or unrecognized time zone name
  }
}
