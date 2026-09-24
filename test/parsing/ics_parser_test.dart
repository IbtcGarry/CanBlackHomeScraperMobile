import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:canblackhomescraper_mobile/parsing/ics_parser.dart';

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  group('parseIcs', () {
    test('reads a plain event with a Coordinated Universal Time instant', () {
      const feed = 'BEGIN:VCALENDAR\r\n'
          'BEGIN:VEVENT\r\n'
          'UID:canvas_event_assignment_1\r\n'
          'SUMMARY:Homework 1 [MATH 218]\r\n'
          'DTSTART:20260925T045900Z\r\n'
          'DTEND:20260925T045900Z\r\n'
          'URL:https://canvas.example.edu/assignments/1\r\n'
          'END:VEVENT\r\n'
          'END:VCALENDAR\r\n';

      final events = parseIcs(feed);

      expect(events, hasLength(1));
      final event = events.single;
      expect(event.uid, 'canvas_event_assignment_1');
      expect(event.summary, 'Homework 1 [MATH 218]');
      expect(event.allDay, isFalse);
      expect(event.start, DateTime.utc(2026, 9, 25, 4, 59));
      expect(
        event.url,
        'https://canvas.example.edu/assignments/1',
      );
    });

    test('converts a named time zone wall clock time to Coordinated Universal Time', () {
      const feed = 'BEGIN:VCALENDAR\r\n'
          'BEGIN:VEVENT\r\n'
          'UID:blackboard_1\r\n'
          'SUMMARY:Quiz 1\r\n'
          'DTSTART;TZID=America/Chicago:20260924T235900\r\n'
          'END:VEVENT\r\n'
          'END:VCALENDAR\r\n';

      final events = parseIcs(feed);

      expect(events, hasLength(1));
      // 11:59 PM Central on September 24 is 4:59 AM Coordinated
      // Universal Time on September 25, since Chicago is five hours
      // behind during daylight saving time in September.
      expect(events.single.start, DateTime.utc(2026, 9, 25, 4, 59));
    });

    test('treats a floating time with no zone as Coordinated Universal Time', () {
      const feed = 'BEGIN:VCALENDAR\r\n'
          'BEGIN:VEVENT\r\n'
          'UID:floating_1\r\n'
          'SUMMARY:Office hours\r\n'
          'DTSTART:20260924T140000\r\n'
          'END:VEVENT\r\n'
          'END:VCALENDAR\r\n';

      final events = parseIcs(feed);

      expect(events.single.start, DateTime.utc(2026, 9, 24, 14));
    });

    test('pins an all day, bare date due date to the end of that day', () {
      const feed = 'BEGIN:VCALENDAR\r\n'
          'BEGIN:VEVENT\r\n'
          'UID:allday_1\r\n'
          'SUMMARY:Project due\r\n'
          'DTSTART;VALUE=DATE:20260930\r\n'
          'END:VEVENT\r\n'
          'END:VCALENDAR\r\n';

      final events = parseIcs(feed);

      expect(events.single.allDay, isTrue);
      expect(events.single.start, DateTime.utc(2026, 9, 30, 23, 59, 59));
    });

    test('unfolds a summary continued on an indented line', () {
      const feed = 'BEGIN:VCALENDAR\r\n'
          'BEGIN:VEVENT\r\n'
          'UID:folded_1\r\n'
          'SUMMARY:A very long assignment title that keeps going and \r\n'
          ' going past the line length a feed would normally fold at\r\n'
          'DTSTART:20260924T140000Z\r\n'
          'END:VEVENT\r\n'
          'END:VCALENDAR\r\n';

      final events = parseIcs(feed);

      expect(
        events.single.summary,
        'A very long assignment title that keeps going and going past the '
        'line length a feed would normally fold at',
      );
    });

    test('unescapes backslash escaped commas, semicolons, and newlines', () {
      const feed = 'BEGIN:VCALENDAR\r\n'
          'BEGIN:VEVENT\r\n'
          'UID:escaped_1\r\n'
          r'DESCRIPTION:Course\, Section 1\; ten points\nSee syllabus' '\r\n'
          'DTSTART:20260924T140000Z\r\n'
          'END:VEVENT\r\n'
          'END:VCALENDAR\r\n';

      final events = parseIcs(feed);

      expect(
        events.single.description,
        'Course, Section 1; ten points\nSee syllabus',
      );
    });

    test('returns an empty list for a feed with no events', () {
      const feed = 'BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n';
      expect(parseIcs(feed), isEmpty);
    });
  });
}
