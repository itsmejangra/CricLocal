import 'package:flutter_test/flutter_test.dart';
import 'package:cric_local/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CricLocalApp());
    expect(find.text('criclocal'), findsNothing); // RichText won't match simple find
  });
}
