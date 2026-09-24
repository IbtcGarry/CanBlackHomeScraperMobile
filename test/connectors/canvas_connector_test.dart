import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:canblackhomescraper_mobile/connectors/canvas_connector.dart';
import 'package:canblackhomescraper_mobile/models/assignment_kind.dart';
import 'package:canblackhomescraper_mobile/models/source.dart';
import 'package:canblackhomescraper_mobile/models/source_config.dart';

class MockDio extends Mock implements Dio {}

class FakeRequestOptions extends Fake implements RequestOptions {}

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    registerFallbackValue(FakeRequestOptions());
  });

  group('CanvasConnector, calendar feed strategy', () {
    test('turns a real due assignment into an Assignment and drops noise', () async {
      const feedBody = 'BEGIN:VCALENDAR\r\n'
          'BEGIN:VEVENT\r\n'
          'UID:event-assignment-409662\r\n'
          'SUMMARY:Homework 2 [MATH 218]\r\n'
          'DTSTART:20260925T045900Z\r\n'
          'URL:https://canvas.example.edu/courses/1/assignments/2\r\n'
          'END:VEVENT\r\n'
          'BEGIN:VEVENT\r\n'
          'UID:event-calendar-event-1\r\n'
          'SUMMARY:Fall break\r\n'
          'DTSTART:20260924T000000Z\r\n'
          'END:VEVENT\r\n'
          'END:VCALENDAR\r\n';

      final client = MockDio();
      when(
        () => client.get<String>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: feedBody,
          requestOptions: RequestOptions(path: 'https://canvas.example.edu/feed.ics'),
          statusCode: 200,
        ),
      );

      final connector = CanvasConnector(
        config: const CanvasConfig(
          icalUrl: 'https://canvas.example.edu/feed.ics',
        ),
        client: client,
      );

      final assignments = await connector.fetchAssignments();

      expect(assignments, hasLength(1));
      final assignment = assignments.single;
      expect(assignment.id, 'canvas:event-assignment-409662');
      expect(assignment.source, Source.canvas);
      expect(assignment.title, 'Homework 2');
      expect(assignment.course, 'MATH 218');
      expect(assignment.kind, AssignmentKind.assignment);
      expect(assignment.dueAt, DateTime.utc(2026, 9, 25, 4, 59));
      expect(assignment.points, isNull);
      expect(assignment.submitted, isFalse);
    });

    test('throws when neither the token nor the calendar feed strategy is configured', () async {
      final connector = CanvasConnector(
        config: const CanvasConfig(),
        client: MockDio(),
      );

      expect(connector.fetchAssignments(), throwsStateError);
    });
  });
}
