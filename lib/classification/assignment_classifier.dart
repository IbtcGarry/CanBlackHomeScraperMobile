import '../models/assignment_kind.dart';

/// Decides which [AssignmentKind] a title belongs to, purely from the
/// title text. None of the three services this app reads from give
/// structured type information, so this is a best effort guess built
/// from keyword and pattern matching, the same approach the desktop
/// tool uses. Adjust the pattern lists below if a real title keeps
/// landing in the wrong group.
///
/// Priority order matters here: an exam flavored title always wins even
/// when it also matches an assignment or prep keyword, for example
/// "Exam review reading" is still something to study for, not something
/// to read casually. A numbered item like "9) Bayes Rule" or a title
/// ending in the "_lp" suffix is always treated as prep, even if it
/// happens to also contain an assignment keyword, since numbering and
/// that suffix specifically mark lecture and reading items in the
/// sources this app reads from.
AssignmentKind classifyAssignment(String? title) {
  final t = (title ?? '').trim();
  if (t.isEmpty) return AssignmentKind.assignment;

  if (_examPattern.hasMatch(t)) return AssignmentKind.exam;
  if (_numberedItemPattern.hasMatch(t) ||
      _lecturePrepSuffixPattern.hasMatch(t)) {
    return AssignmentKind.prep;
  }
  if (_assignmentPattern.hasMatch(t)) return AssignmentKind.assignment;
  if (_prepPattern.hasMatch(t)) return AssignmentKind.prep;
  return AssignmentKind.assignment;
}

/// Matches something a student studies for: an exam, a midterm, a
/// final, a test, a quiz, a prelim, or a comprehensive.
final RegExp _examPattern = RegExp(
  r'\b(exam|midterm|final|test|quiz|prelim|comprehensive)\b',
  caseSensitive: false,
);

/// Matches something a student hands in: homework, an assignment, a
/// problem set, a project, a lab, an essay, a paper, a report, a
/// portfolio, a worksheet, a discussion post, a response, a submission,
/// a milestone, a deliverable, a draft, a presentation, or a proposal.
/// Also matches a bare item number such as "#3" or the word
/// "assignment" immediately followed by a digit.
final RegExp _assignmentPattern = RegExp(
  r'\b(hw|homework|assignment|problem\s?set|pset|project|lab|essay|paper|'
  r'report|portfolio|worksheet|discussion|response|submission|milestone|'
  r'deliverable|draft|presentation|proposal)\b|#\d|assignment\d',
  caseSensitive: false,
);

/// Matches something a student works through but never submits: a
/// reading, a lecture, a module, a video, slides, notes, prep, a class
/// that meets before the main lecture, a chapter or section reference,
/// a textbook or online workbook reference, participation, or
/// attendance. Also matches the "_lp" suffix on its own, so this
/// pattern alone is enough to catch it even outside the dedicated
/// numbered and suffix check above.
///
/// Note this pattern intentionally contains a real hyphen character
/// inside the regular expression itself, since a real title can write
/// the phrase that comes before class either as one plain word or as
/// two words joined by that character. That character is part of the
/// data being matched, not part of this project's documentation, so it
/// is not affected by the project wide rule against using a hyphen or
/// dash in written prose and file names.
final RegExp _prepPattern = RegExp(
  r'\b(reading|read|lecture|module|watch|video|slides?|notes|prep|'
  r'pre-?class|chapter|section|textbook|zybook|zylab|participation|'
  r'attendance)\b|_lp\b',
  caseSensitive: false,
);

/// Matches a title that starts with a number followed by a closing
/// parenthesis or a period and a space, the numbering convention
/// lecture and module items commonly use, for example "9) Bayes Rule"
/// or "3. Read chapter two".
final RegExp _numberedItemPattern = RegExp(r'^\s*\d+[).]\s');

/// Matches a title ending in the "_lp" suffix, a convention this app's
/// sources use to mark a lecture or prep item regardless of what else
/// the title says.
final RegExp _lecturePrepSuffixPattern = RegExp(
  r'_lp\b',
  caseSensitive: false,
);
