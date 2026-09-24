import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'aggregation/assignment_aggregator.dart';
import 'connectors/canvas_connector.dart';
import 'models/app_settings.dart';
import 'models/assignment.dart';
import 'models/assignment_kind.dart';
import 'models/source_config.dart';

/// Entry point. Loads the time zone database (needed before any calendar
/// feed with a named time zone can be parsed, see ics_parser.dart) and
/// starts the app.
void main() {
  tz_data.initializeTimeZones();
  runApp(const CanBlackHomeScraperMobileApp());
}

/// The root widget. This build phase shows a single bare screen that
/// proves the real pipeline, a network fetch, calendar feed parsing,
/// classification, and aggregation, works end to end against a real
/// personal calendar feed url the student pastes in by hand. The
/// settings screen that replaces this text field with a proper,
/// securely stored configuration is built in a later phase, see the
/// project plan's phased build order.
class CanBlackHomeScraperMobileApp extends StatelessWidget {
  const CanBlackHomeScraperMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CanBlackHomeScraperMobile',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const BareFeedTestScreen(),
    );
  }
}

/// A bare, unstyled screen used only to prove the pipeline during early
/// development: paste a Canvas personal calendar feed url, fetch it,
/// and see the resulting assignments listed, sorted, classified, and
/// deduplicated exactly the way the real app will show them once the
/// full calendar and agenda screens exist.
class BareFeedTestScreen extends StatefulWidget {
  const BareFeedTestScreen({super.key});

  @override
  State<BareFeedTestScreen> createState() => _BareFeedTestScreenState();
}

class _BareFeedTestScreenState extends State<BareFeedTestScreen> {
  final TextEditingController _urlController = TextEditingController();
  List<Assignment>? _assignments;
  String? _error;
  bool _loading = false;

  Future<void> _fetch() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final connector = CanvasConnector(
        config: CanvasConfig(icalUrl: url),
      );
      final fetched = await connector.fetchAssignments();
      final merged = aggregateAssignments([fetched]);
      final trimmed = trimToLookahead(
        merged,
        now: DateTime.now().toUtc(),
        lookaheadDays: const AppSettings().lookaheadDays,
      );
      setState(() {
        _assignments = trimmed;
        _loading = false;
      });
    } catch (err) {
      setState(() {
        _error = '$err';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CanBlackHomeScraperMobile, pipeline test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paste a Canvas personal calendar feed url (Canvas, then '
              'Calendar, then Calendar Feed) to prove the pipeline. '
              'Nothing here is saved yet; a real settings screen is '
              'built in a later phase.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Canvas calendar feed url',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _fetch,
              child: Text(_loading ? 'Fetching...' : 'Fetch assignments'),
            ),
            const SizedBox(height: 12),
            if (_error != null) Text('Error: $_error'),
            if (_assignments != null)
              Expanded(
                child: ListView.builder(
                  itemCount: _assignments!.length,
                  itemBuilder: (context, index) {
                    final a = _assignments![index];
                    return ListTile(
                      title: Text(a.title),
                      subtitle: Text('${a.course} · ${a.kind.label}'),
                      trailing: Text(a.dueAt?.toLocal().toString() ?? 'no date'),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
