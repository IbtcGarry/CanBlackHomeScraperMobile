import 'package:flutter_test/flutter_test.dart';
import 'package:canblackhomescraper_mobile/classification/assignment_classifier.dart';
import 'package:canblackhomescraper_mobile/models/assignment_kind.dart';

void main() {
  group('classifyAssignment', () {
    test('an empty or missing title defaults to assignment', () {
      expect(classifyAssignment(''), AssignmentKind.assignment);
      expect(classifyAssignment(null), AssignmentKind.assignment);
      expect(classifyAssignment('   '), AssignmentKind.assignment);
    });

    test('exam keywords win even when an assignment keyword also appears', () {
      expect(classifyAssignment('Exam review reading'), AssignmentKind.exam);
      expect(classifyAssignment('Midterm 1'), AssignmentKind.exam);
      expect(classifyAssignment('Final project quiz'), AssignmentKind.exam);
      expect(classifyAssignment('Comprehensive test'), AssignmentKind.exam);
    });

    test('a numbered lecture item is always prep', () {
      expect(classifyAssignment('9) Bayes Rule'), AssignmentKind.prep);
      expect(classifyAssignment('3. Read chapter two'), AssignmentKind.prep);
      expect(classifyAssignment('10) Homework tips'), AssignmentKind.prep);
    });

    test('a title ending in the lp suffix is always prep', () {
      expect(classifyAssignment('Reading 3_lp'), AssignmentKind.prep);
      expect(classifyAssignment('Module 1 Assignment_lp'), AssignmentKind.prep);
    });

    test('common assignment keywords are recognized', () {
      expect(classifyAssignment('Homework 2'), AssignmentKind.assignment);
      expect(classifyAssignment('Problem Set 4'), AssignmentKind.assignment);
      expect(classifyAssignment('Lab Report 1'), AssignmentKind.assignment);
      expect(classifyAssignment('Assignment #3'), AssignmentKind.assignment);
      expect(classifyAssignment('assignment2'), AssignmentKind.assignment);
    });

    test('common prep keywords are recognized', () {
      expect(classifyAssignment('Chapter 5 reading'), AssignmentKind.prep);
      expect(classifyAssignment('Lecture notes'), AssignmentKind.prep);
      expect(
        classifyAssignment('Watch video on recursion'),
        AssignmentKind.prep,
      );
      expect(classifyAssignment('preclass notes'), AssignmentKind.prep);
      expect(classifyAssignment('Attendance week 3'), AssignmentKind.prep);
    });

    test('an unrecognized title defaults to assignment', () {
      expect(
        classifyAssignment('Something entirely unexpected'),
        AssignmentKind.assignment,
      );
    });

    test('classification does not depend on letter case', () {
      expect(classifyAssignment('MIDTERM EXAM'), AssignmentKind.exam);
      expect(classifyAssignment('homework 1'), AssignmentKind.assignment);
      expect(classifyAssignment('READING chapter 2'), AssignmentKind.prep);
    });
  });
}
