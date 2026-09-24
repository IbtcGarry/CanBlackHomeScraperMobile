import 'package:dio/dio.dart';

import '../models/assignment.dart';
import '../models/source.dart';
import '../models/source_config.dart';
import 'connector.dart';
import 'ics_feed_reader.dart';

/// Reads Canvas assignments. Three strategies exist, tried in order of
/// richness, matching the desktop tool: a personal access token, a
/// shared single sign on session, and a personal calendar feed url.
///
/// This class currently implements only the calendar feed strategy.
/// The token and single sign on strategies are added in later build
/// phases, once the settings screen and the shared session manager
/// exist to support them, see the project plan's phased build order.
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
    final icalUrl = config.icalUrl;
    if (icalUrl != null) {
      return fetchIcsFeedAssignments(Source.canvas, icalUrl, client: client);
    }
    throw StateError(
      'Canvas is only configured with a calendar feed url in this build '
      'phase. The personal access token and single sign on strategies '
      'are added in a later phase.',
    );
  }
}
