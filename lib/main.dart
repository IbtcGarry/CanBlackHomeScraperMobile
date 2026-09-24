import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'ui/settings/settings_screen.dart';

/// Entry point. Loads the time zone database (needed before any
/// calendar feed with a named time zone can be parsed, see
/// ics_parser.dart), wraps the app in a Riverpod ProviderScope so every
/// screen can reach the settings and storage providers, and starts the
/// app.
void main() {
  tz_data.initializeTimeZones();
  runApp(const ProviderScope(child: CanBlackHomeScraperMobileApp()));
}

/// The root widget. The settings screen currently stands in for the
/// whole app, letting a student enter and persist their Canvas
/// configuration and fetch with it. The real calendar and agenda
/// screens, reachable from a proper home shell, are built in a later
/// phase, see the project plan's phased build order.
class CanBlackHomeScraperMobileApp extends StatelessWidget {
  const CanBlackHomeScraperMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CanBlackHomeScraperMobile',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const SettingsScreen(),
    );
  }
}
