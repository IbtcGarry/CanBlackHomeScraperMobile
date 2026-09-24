import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../aggregation/assignment_aggregator.dart';
import '../../connectors/canvas_connector.dart';
import '../../models/assignment.dart';
import '../../models/assignment_kind.dart';
import '../../state/settings_providers.dart';
import 'canvas_settings_section.dart';

/// The settings screen: lets the student enter Canvas's configuration,
/// persists it (the non secret fields in plain preferences, the token
/// and calendar feed url in encrypted secure storage), and offers a
/// fetch action that proves the saved configuration actually works.
///
/// This still stands in for the app's real calendar and agenda screens,
/// which are built in a later phase, see the project plan's phased
/// build order. Once those exist, this screen becomes reachable from
/// them instead of being the entire app.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  List<Assignment>? _assignments;
  String? _error;
  bool _fetching = false;

  Future<void> _fetchWithSavedConfig() async {
    setState(() {
      _fetching = true;
      _error = null;
    });

    try {
      final config = await ref.read(canvasConfigProvider.future);
      final connector = CanvasConnector(config: config);
      final fetched = await connector.fetchAssignments();
      final merged = aggregateAssignments([fetched]);

      setState(() {
        _assignments = merged;
        _fetching = false;
      });
    } catch (err) {
      setState(() {
        _error = '$err';
        _fetching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canvasConfigAsync = ref.watch(canvasConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('CanBlackHomeScraperMobile settings')),
      body: canvasConfigAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Could not load settings: $err')),
        data: (canvasConfig) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CanvasSettingsSection(
              initialConfig: canvasConfig,
              onSave: (updated) async {
                await ref.read(canvasConfigProvider.notifier).save(updated);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Canvas settings saved')),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetching ? null : _fetchWithSavedConfig,
              child: Text(
                _fetching
                    ? 'Fetching with saved settings...'
                    : 'Fetch now with saved settings',
              ),
            ),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Error: $_error'),
            ),
            if (_assignments != null) ...[
              const SizedBox(height: 12),
              Text('${_assignments!.length} assignments'),
              for (final a in _assignments!)
                ListTile(
                  title: Text(a.title),
                  subtitle: Text(
                    '${a.course} · ${a.kind.label}'
                    '${a.points != null ? " · ${a.points} points" : ""}',
                  ),
                  trailing: Text(a.dueAt?.toLocal().toString() ?? 'no date'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
