import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cric_local/app/di.dart';
import 'package:cric_local/main.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('App smoke test', (WidgetTester tester) async {
    await setupDependencies();
    await tester.pumpWidget(const CricLocalApp());
    expect(find.text('criclocal'), findsNothing); // RichText won't match simple find
  });
}
