// A smoke test for the current build phase's bare pipeline test screen.
// This is replaced by real calendar and agenda screen tests once those
// exist, see test/ui and the project plan's phased build order.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:canblackhomescraper_mobile/main.dart';

void main() {
  testWidgets('the app launches and shows the bare pipeline test screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CanBlackHomeScraperMobileApp());

    expect(find.text('Fetch assignments'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
