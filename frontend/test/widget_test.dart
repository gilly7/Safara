import 'package:flutter_test/flutter_test.dart';

import 'package:safara/app.dart';

void main() {
  testWidgets('Safara home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const SafaraApp());
    await tester.pumpAndSettle();

    expect(find.text('Safara'), findsOneWidget);
    expect(find.text('Your Smart Kenya Travel Companion'), findsOneWidget);
    expect(find.text('Start Chat'), findsOneWidget);
  });
}
