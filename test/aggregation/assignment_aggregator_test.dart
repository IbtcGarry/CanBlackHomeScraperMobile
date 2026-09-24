import 'package:flutter_test/flutter_test.dart';
import 'package:canblackhomescraper_mobile/aggregation/assignment_aggregator.dart';
import 'package:canblackhomescraper_mobile/models/assignment.dart';
import 'package:canblackhomescraper_mobile/models/assignment_kind.dart';
import 'package:canblackhomescraper_mobile/models/source.dart';

Assignment _make({
  required String id,
  required Source source,
  String course = 'Math 218',
  String title = 'Homework 1',
  DateTime? dueAt,
  double? points,
}) {
  return Assignment(
    id: id,
    source: source,
    course: course,
    title: title,
    kind: AssignmentKind.assignment,
    dueAt: dueAt,
    allDay: false,
    url: null,
    points: points,
    submitted: false,
  );
}

void main() {
  group('aggregateAssignments', () {
    test('keeps every assignment when nothing duplicates', () {
      final due = DateTime.utc(2026, 9, 25);
      final a = _make(
        id: 'canvas:1',
        source: Source.canvas,
        title: 'Homework 1',
        dueAt: due,
      );
      final b = _make(
        id: 'canvas:2',
        source: Source.canvas,
        title: 'Homework 2',
        dueAt: due,
      );

      final result = aggregateAssignments([
        [a],
        [b],
      ]);

      expect(result, hasLength(2));
    });

    test('collapses the same work reported by two sources, preferring canvas', () {
      final due = DateTime.utc(2026, 9, 25);
      final fromGradescope = _make(
        id: 'gradescope:1',
        source: Source.gradescope,
        course: 'Math 218',
        title: 'Homework 1',
        dueAt: due,
      );
      final fromCanvas = _make(
        id: 'canvas:1',
        source: Source.canvas,
        course: 'Math 218',
        title: 'Homework 1',
        dueAt: due,
        points: 10,
      );

      final result = aggregateAssignments([
        [fromGradescope],
        [fromCanvas],
      ]);

      expect(result, hasLength(1));
      expect(result.single.source, Source.canvas);
      expect(result.single.points, 10);
    });

    test(
      'prefers a record with a known points value when sources are equally ranked',
      () {
        final due = DateTime.utc(2026, 9, 25);
        final withoutPoints = _make(
          id: 'blackboard:1',
          source: Source.blackboard,
          title: 'Quiz 1',
          dueAt: due,
        );
        final withPoints = _make(
          id: 'gradescope:1',
          source: Source.gradescope,
          title: 'Quiz 1',
          dueAt: due,
          points: 20,
        );

        final result = aggregateAssignments([
          [withoutPoints],
          [withPoints],
        ]);

        expect(result, hasLength(1));
        expect(result.single.points, 20);
      },
    );

    test('treats course and title differences in punctuation and case as the same key', () {
      final due = DateTime.utc(2026, 9, 25);
      final fromCanvas = _make(
        id: 'canvas:1',
        source: Source.canvas,
        course: 'Math 218',
        title: 'Homework #1',
        dueAt: due,
      );
      final fromGradescope = _make(
        id: 'gradescope:1',
        source: Source.gradescope,
        course: 'math 218',
        title: 'homework 1',
        dueAt: due,
      );

      final result = aggregateAssignments([
        [fromCanvas],
        [fromGradescope],
      ]);

      expect(result, hasLength(1));
    });

    test('sorts by due date, undated items last, then by title', () {
      final earlier = _make(
        id: '1',
        source: Source.canvas,
        title: 'B',
        dueAt: DateTime.utc(2026, 9, 20),
      );
      final later = _make(
        id: '2',
        source: Source.canvas,
        title: 'A',
        dueAt: DateTime.utc(2026, 9, 25),
      );
      final undated = _make(id: '3', source: Source.canvas, title: 'C', dueAt: null);

      final result = aggregateAssignments([
        [later, undated, earlier],
      ]);

      expect(result.map((a) => a.id).toList(), ['1', '2', '3']);
    });
  });

  group('trimToLookahead', () {
    test('drops items due further out than the lookahead window', () {
      final now = DateTime.utc(2026, 9, 24);
      final soon = _make(
        id: '1',
        source: Source.canvas,
        dueAt: now.add(const Duration(days: 5)),
      );
      final far = _make(
        id: '2',
        source: Source.canvas,
        dueAt: now.add(const Duration(days: 40)),
      );
      final undated = _make(id: '3', source: Source.canvas, dueAt: null);

      final result = trimToLookahead(
        [soon, far, undated],
        now: now,
        lookaheadDays: 21,
      );

      final ids = result.map((a) => a.id).toSet();
      expect(ids, containsAll(['1', '3']));
      expect(ids, isNot(contains('2')));
    });

    test('keeps an item due exactly on the horizon', () {
      final now = DateTime.utc(2026, 9, 24);
      final onHorizon = _make(
        id: '1',
        source: Source.canvas,
        dueAt: now.add(const Duration(days: 21)),
      );

      final result = trimToLookahead(
        [onHorizon],
        now: now,
        lookaheadDays: 21,
      );

      expect(result, hasLength(1));
    });
  });
}
