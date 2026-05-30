import 'package:elder_launcher/main.dart';
import 'package:elder_launcher/utils/shared_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App smoke test: builds without crash', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefs.init();
    await tester.pumpWidget(const MyApp());
    // App renders without throwing
    expect(tester.takeException(), isNull);
  });
}
