// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For justinbruinsma, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:pawnder_app/main.dart';

void main() {
  testWidgets('Onboarding renders primary call to action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PawnderApp());

    expect(find.text('Welcome to Pawnder'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}
