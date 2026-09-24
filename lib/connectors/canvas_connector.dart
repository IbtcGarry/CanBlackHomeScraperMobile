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
class CanvasConnector implements Connector {
  /// The student's Canvas settings, entered on the settings screen.
  final CanvasConfig config;

  /// The network client used for every request this connector makes.
  /// Accepting one rather than creating it internally lets a test
  /// substitute a fake client instead of making a real network call.
  final Dio client;

  /// The raw Cookie header value for the shared single sign on
  /// session, when the single sign on strategy applies. Passed in
  /// rather than looked up internally, since only the ui layer can
  /// show the WebView login screen a missing or expired session needs;
  /// see SsoSessionRequiredException.
  final String? ssoCookieHeader;

  CanvasConnector({required this.config, Dio? client, this.ssoCookieHeader})
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

    if (baseUrl != null && config.useSso) {
      final cookieHeader = ssoCookieHeader;
      if (cookieHeader == null) {
        throw const SsoSessionRequiredException(schoolSsoSessionKey);
      }
      return _fetchViaSsoSession(baseUrl, cookieHeader);
    }

    final icalUrl = config.icalUrl;
    if (icalUrl != null) {
      return fetchIcsFeedAssignments(Source.canvas, icalUrl, client: client);
    }

    throw StateError(
      'Canvas needs a base url paired with either a personal access '
      'token or single sign on turned on, or a calendar feed url.',
    );
  }

  /// Calls the official Canvas REST API directly with a bearer token:
  /// every active course, then every assignment in each course,
  /// including submission state. This is the richest of the three
  /// strategies, points and submission state included, since it talks
  /// to the same API Canvas's own web app uses.
  Future<List<Assignment>> _fetchViaToken(String baseUrl, String token) {
    return _collectAssignments(_normalizeBase(baseUrl), {
      'Authorization': 'Bearer $token',
    });
  }

  /// Calls the same Canvas REST API as the token strategy, but
  /// authenticated by the logged in session cookie captured through
  /// SsoWebviewLoginScreen instead of a token. The Accept and
  /// X-Requested-With headers match what Canvas's own React frontend
  /// sends from the logged in page, so Canvas answers with JSON rather
  /// than an HTML login page.
  Future<List<Assignment>> _fetchViaSsoSession(
    String baseUrl,
    String cookieHeader,
  ) async {
    try {
      return await _collectAssignments(_normalizeBase(baseUrl), {
        'Cookie': cookieHeader,
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
      });
    } catch (_) {
      // Almost any failure on this path plausibly means the saved
      // session cookie no longer works, since a genuinely live session
      // should always succeed here. Ask the caller to run the login
      // flow again rather than surface a raw, unhelpful network error.
      throw const SsoSessionRequiredException(schoolSsoSessionKey);
    }
  }

  /// The shared course then assignment traversal both the token and
  /// single sign on strategies use, differing only in which headers
  /// authenticate each request.
  Future<List<Assignment>> _collectAssignments(
    String base,
    Map<String, String> headers,
  ) async {
    final courses = await _paginated(base, '/api/v1/courses', {
      'enrollment_state': 'active',
      'per_page': '100',
    }, headers);

    final results = <Assignment>[];
    for (final course in courses) {
      final courseId = course['id'];
      final courseName = (course['name'] as String?) ?? 'Course $courseId';

      final assignments = await _paginated(
        base,
        '/api/v1/courses/$courseId/assignments',
        {'per_page': '100', 'include[]': 'submission', 'order_by': 'due_at'},
        headers,
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

  String _normalizeBase(String baseUrl) =>
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  /// Follows Canvas's RFC 5988 Link response header until there is no
  /// more "rel next" page, collecting every item along the way. Every
  /// Canvas list endpoint (courses, assignments, and others this app
  /// does not use yet) pages results this same way.
  Future<List<Map<String, dynamic>>> _paginated(
    String base,
    String path,
    Map<String, String> query,
    Map<String, String> headers,
  ) async {
    String? url = Uri.parse(
      '$base$path',
    ).replace(queryParameters: query).toString();
    final out = <Map<String, dynamic>>[];

    while (url != null) {
      final response = await client.get<List<dynamic>>(
        url,
        options: Options(headers: headers),
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
      final match = RegExp(r'<([^>]+)>\s*;\s*rel="next"').firstMatch(part);
      if (match != null) return match.group(1);
    }
    return null;
  }
}

/// Where Canvas's WebView login should start: the general redirector
/// path, not a Canvas specific local login page, so a school that has
/// turned on single sign on sends the student straight to their
/// identity provider rather than to a local password form with no way
/// out, the same reasoning the desktop tool's own login flow follows.
Uri canvasSsoEntryUrl(String baseUrl) => Uri.parse(baseUrl).resolve('/login');

/// True once a WebView showing Canvas has navigated back to Canvas's
/// own origin on a path that is not itself a login page, meaning the
/// identity provider handed control back and Canvas accepted the
/// login.
bool canvasIsSignedIn(Uri url, String canvasOrigin) {
  return url.origin == canvasOrigin && !url.path.contains('/login');
}
