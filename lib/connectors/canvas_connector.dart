import 'package:dio/dio.dart';

import '../classification/assignment_classifier.dart';
import '../models/assignment.dart';
import '../models/source.dart';
import '../models/source_config.dart';
import 'connector.dart';
import 'ics_feed_reader.dart';

/// Reads Canvas assignments. Three strategies exist, tried in order of
/// richness, matching the desktop tool: a personal access token first,
/// then a shared single sign on session, then a personal calendar feed
/// url last.
///
/// This class currently implements the token and calendar feed
/// strategies. The single sign on strategy is added in a later build
/// phase, once the shared session manager exists to support it, see
/// the project plan's phased build order.
class CanvasConnector implements Connector {
  /// The student's Canvas settings, entered on the settings screen.
  final CanvasConfig config;

  /// The network client used for every request this connector makes.
  /// Accepting one rather than creating it internally lets a test
  /// substitute a fake client instead of making a real network call.
  final Dio client;

  CanvasConnector({required this.config, Dio? client})
    : client = client ?? Dio();

  @override
  Source get source => Source.canvas;

  @override
  Future<List<Assignment>> fetchAssignments() async {
    final baseUrl = config.baseUrl;
    final token = config.token;
    if (baseUrl != null && token != null) {
      return _fetchViaToken(baseUrl, token);
    }

    final icalUrl = config.icalUrl;
    if (icalUrl != null) {
      return fetchIcsFeedAssignments(Source.canvas, icalUrl, client: client);
    }

    throw StateError(
      'Canvas needs either a base url and a personal access token, or a '
      'calendar feed url. The single sign on strategy is added in a '
      'later build phase.',
    );
  }

  /// Calls the official Canvas REST API directly with a bearer token:
  /// every active course, then every assignment in each course,
  /// including submission state. This is the richest of the three
  /// strategies, points and submission state included, since it talks
  /// to the same API Canvas's own web app uses.
  Future<List<Assignment>> _fetchViaToken(String baseUrl, String token) async {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final courses = await _paginated(base, '/api/v1/courses', {
      'enrollment_state': 'active',
      'per_page': '100',
    }, token);

    final results = <Assignment>[];
    for (final course in courses) {
      final courseId = course['id'];
      final courseName = (course['name'] as String?) ?? 'Course $courseId';

      final assignments = await _paginated(
        base,
        '/api/v1/courses/$courseId/assignments',
        {'per_page': '100', 'include[]': 'submission', 'order_by': 'due_at'},
        token,
      );

      for (final a in assignments) {
        final title = (a['name'] as String?) ?? '(untitled)';
        final dueAtRaw = a['due_at'] as String?;
        final submission = a['submission'] as Map<String, dynamic>?;
        final workflowState = submission?['workflow_state'] as String?;

        results.add(
          Assignment(
            id: makeAssignmentId(Source.canvas, a['id']),
            source: Source.canvas,
            course: courseName,
            title: title,
            kind: classifyAssignment(title),
            dueAt: dueAtRaw != null ? DateTime.parse(dueAtRaw).toUtc() : null,
            allDay: false,
            url: a['html_url'] as String?,
            points: (a['points_possible'] as num?)?.toDouble(),
            submitted: workflowState != null && workflowState != 'unsubmitted',
          ),
        );
      }
    }
    return results;
  }

  /// Follows Canvas's RFC 5988 Link response header until there is no
  /// more "rel next" page, collecting every item along the way. Every
  /// Canvas list endpoint (courses, assignments, and others this app
  /// does not use yet) pages results this same way.
  Future<List<Map<String, dynamic>>> _paginated(
    String base,
    String path,
    Map<String, String> query,
    String token,
  ) async {
    String? url = Uri.parse(
      '$base$path',
    ).replace(queryParameters: query).toString();
    final out = <Map<String, dynamic>>[];

    while (url != null) {
      final response = await client.get<List<dynamic>>(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final status = response.statusCode;
      if (status == null || status >= 400) {
        throw StateError('Canvas returned status $status for $url');
      }
      out.addAll((response.data ?? const []).cast<Map<String, dynamic>>());
      url = _nextLinkFrom(response.headers.value('link'));
    }
    return out;
  }

  /// Parses the "next" link out of an RFC 5988 Link header, for
  /// example one entry inside
  /// "&lt;https://canvas.example.edu/api/v1/courses?page=2&gt;; rel=\"next\"".
  String? _nextLinkFrom(String? header) {
    if (header == null) return null;
    for (final part in header.split(',')) {
      final match = RegExp(
        r'<([^>]+)>\s*;\s*rel="next"',
      ).firstMatch(part);
      if (match != null) return match.group(1);
    }
    return null;
  }
}
