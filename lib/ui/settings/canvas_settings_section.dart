import 'package:flutter/material.dart';

import '../../models/source_config.dart';

/// A form for Canvas's settings: a base url and a personal access
/// token (the richest, most testable strategy so far), or a calendar
/// feed url as a simpler alternative. Single sign on is not offered
/// here yet, since that strategy is added in a later build phase, see
/// the project plan's phased build order.
class CanvasSettingsSection extends StatefulWidget {
  final CanvasConfig initialConfig;
  final ValueChanged<CanvasConfig> onSave;

  const CanvasSettingsSection({
    super.key,
    required this.initialConfig,
    required this.onSave,
  });

  @override
  State<CanvasSettingsSection> createState() => _CanvasSettingsSectionState();
}

class _CanvasSettingsSectionState extends State<CanvasSettingsSection> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _tokenController;
  late final TextEditingController _icalUrlController;
  late bool _useSso;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: widget.initialConfig.baseUrl ?? '',
    );
    _tokenController = TextEditingController(
      text: widget.initialConfig.token ?? '',
    );
    _icalUrlController = TextEditingController(
      text: widget.initialConfig.icalUrl ?? '',
    );
    _useSso = widget.initialConfig.useSso;
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    _icalUrlController.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(
      CanvasConfig(
        baseUrl: _emptyToNull(_baseUrlController.text),
        token: _emptyToNull(_tokenController.text),
        icalUrl: _emptyToNull(_icalUrlController.text),
        useSso: _useSso,
      ),
    );
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Canvas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Richest option: your school address plus a personal '
              'access token, from Canvas, then Account, then Settings, '
              'then New Access Token.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Canvas address',
                hintText: 'https://yourschool.instructure.com',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Personal access token',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _useSso,
              onChanged: (value) => setState(() => _useSso = value ?? false),
              title: const Text('Use single sign on instead of a token'),
              subtitle: const Text(
                'No token needed, but the first fetch opens a one time '
                'sign in screen.',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Simpler option, no token needed but less detail: your '
              'personal calendar feed url, from Canvas, then Calendar, '
              'then Calendar Feed.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _icalUrlController,
              decoration: const InputDecoration(
                labelText: 'Calendar feed url',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Save Canvas settings')),
          ],
        ),
      ),
    );
  }
}
