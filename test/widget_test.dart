// A smoke test for the current build phase's entry screen, the
// settings screen. This is replaced by real calendar and agenda screen
// tests once those exist, see test/ui and the project plan's phased
// build order.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:canblackhomescraper_mobile/main.dart';
import 'package:canblackhomescraper_mobile/state/settings_providers.dart';
import 'package:canblackhomescraper_mobile/storage/secure_credential_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('the app launches and shows the settings screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          credentialStoreProvider.overrideWithValue(InMemoryCredentialStore()),
        ],
        child: const CanBlackHomeScraperMobileApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Canvas'), findsOneWidget);
    expect(find.text('Fetch now with saved settings'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
  });
}
