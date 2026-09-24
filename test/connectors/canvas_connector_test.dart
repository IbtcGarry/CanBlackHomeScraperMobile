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

  group('CanvasConnector, personal access token strategy', () {
    test('fetches every course and every assignment, following pagination', () async {
      final client = MockDio();

      // Page one of courses points to page two through the Link header,
      // the same RFC 5988 pagination Canvas's real API uses.
      when(
        () => client.get<List<dynamic>>(
          'https://canvas.example.edu/api/v1/courses?enrollment_state=active&per_page=100',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: [
            {'id': 1, 'name': 'Math 218'},
          ],
          headers: Headers.fromMap({
            'link': [
              '<https://canvas.example.edu/api/v1/courses?page=2>; rel="next"',
            ],
          }),
          requestOptions: RequestOptions(path: 'courses page one'),
          statusCode: 200,
        ),
      );
      when(
        () => client.get<List<dynamic>>(
          'https://canvas.example.edu/api/v1/courses?page=2',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: [
            {'id': 2, 'name': 'CS 301'},
          ],
          requestOptions: RequestOptions(path: 'courses page two'),
          statusCode: 200,
        ),
      );

      when(
        () => client.get<List<dynamic>>(
          'https://canvas.example.edu/api/v1/courses/1/assignments'
          '?per_page=100&include%5B%5D=submission&order_by=due_at',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: [
            {
              'id': 10,
              'name': 'Homework 1',
              'due_at': '2026-09-25T04:59:00Z',
              'html_url': 'https://canvas.example.edu/courses/1/assignments/10',
              'points_possible': 10,
              'submission': {'workflow_state': 'graded'},
            },
          ],
          requestOptions: RequestOptions(path: 'math assignments'),
          statusCode: 200,
        ),
      );
      when(
        () => client.get<List<dynamic>>(
          'https://canvas.example.edu/api/v1/courses/2/assignments'
          '?per_page=100&include%5B%5D=submission&order_by=due_at',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: [
            {
              'id': 20,
              'name': 'Quiz 1',
              'due_at': null,
              'html_url': null,
              'points_possible': null,
              'submission': null,
            },
          ],
          requestOptions: RequestOptions(path: 'cs assignments'),
          statusCode: 200,
        ),
      );

      final connector = CanvasConnector(
        config: const CanvasConfig(
          baseUrl: 'https://canvas.example.edu',
          token: 'a real token',
        ),
        client: client,
      );

      final assignments = await connector.fetchAssignments();

      expect(assignments, hasLength(2));

      final homework = assignments.firstWhere((a) => a.id == 'canvas:10');
      expect(homework.course, 'Math 218');
      expect(homework.points, 10);
      expect(homework.submitted, isTrue);
      expect(homework.dueAt, DateTime.utc(2026, 9, 25, 4, 59));

      final quiz = assignments.firstWhere((a) => a.id == 'canvas:20');
      expect(quiz.course, 'CS 301');
      expect(quiz.points, isNull);
      expect(quiz.submitted, isFalse);
      expect(quiz.dueAt, isNull);
      // "Quiz 1" is classified as an exam by the shared classifier, the
      // same logic already covered by its own dedicated test suite.
      expect(quiz.kind, AssignmentKind.exam);
    });

    test('throws when Canvas answers with an error status', () async {
      final client = MockDio();
      when(
        () => client.get<List<dynamic>>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response(
          data: null,
          requestOptions: RequestOptions(path: 'courses'),
          statusCode: 401,
        ),
      );

      final connector = CanvasConnector(
        config: const CanvasConfig(
          baseUrl: 'https://canvas.example.edu',
          token: 'an expired token',
        ),
        client: client,
      );

      expect(connector.fetchAssignments(), throwsStateError);
    });

    test('the token strategy is preferred over the calendar feed strategy', () async {
      final client = MockDio();
      when(
        () => client.get<List<dynamic>>(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response(
          data: <dynamic>[],
          requestOptions: RequestOptions(path: 'courses'),
          statusCode: 200,
        ),
      );

      final connector = CanvasConnector(
        config: const CanvasConfig(
          baseUrl: 'https://canvas.example.edu',
          token: 'a real token',
          icalUrl: 'https://canvas.example.edu/feed.ics',
        ),
        client: client,
      );

      await connector.fetchAssignments();

      // The calendar feed endpoint, a plain GET<String>, is never
      // called when a token is available.
      verifyNever(
        () => client.get<String>(any(), options: any(named: 'options')),
      );
    });
  });
}
