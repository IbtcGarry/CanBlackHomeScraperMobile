/// The three kinds of assignment this app recognizes, and the priority
/// order used when a title could match more than one kind at once.
///
/// An [exam] is something the student studies for. An [assignment] is
/// something the student hands in. A [prep] item is a reading, a
/// lecture, or a module the student works through but never submits for
/// a grade.
enum AssignmentKind {
  /// Something to study for: an exam, a midterm, a final, a quiz, a
  /// test, a prelim, or a comprehensive.
  exam,

  /// Something to hand in: homework, a project, a lab, an essay, a
  /// paper, a report, or similar graded work.
  assignment,

  /// Something to work through but not submit: a reading, a lecture, a
  /// module, a video, or a set of slides.
  prep,
}

/// Student facing labels for each [AssignmentKind], used as section
/// headings and on the small calendar chips.
extension AssignmentKindLabel on AssignmentKind {
  /// A short label used as a heading above a group of items in the
  /// agenda list, for example above every exam item.
  String get label {
    switch (this) {
      case AssignmentKind.exam:
        return 'Must study';
      case AssignmentKind.assignment:
        return 'Assignments';
      case AssignmentKind.prep:
        return 'Prep and reading';
    }
  }

  /// A very short label used on a calendar chip, where there is only
  /// room for a word or two.
  String get shortLabel {
    switch (this) {
      case AssignmentKind.exam:
        return 'STUDY';
      case AssignmentKind.assignment:
        return 'DO';
      case AssignmentKind.prep:
        return 'PREP';
    }
  }
}
