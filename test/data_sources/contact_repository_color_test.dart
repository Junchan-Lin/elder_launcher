import 'package:elder_launcher/data_sources/contact_repository.dart';
import 'package:elder_launcher/utils/shared_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefs.init();
  });

  test('未設定顏色時 getContactColor 回傳 null', () {
    expect(ContactRepository().getContactColor('1234'), isNull);
  });

  test('setContactColor 後 getContactColor 讀取到相同顏色', () {
    ContactRepository().setContactColor('1234', const Color(0xFF3949AB));
    expect(ContactRepository().getContactColor('1234'),
        equals(const Color(0xFF3949AB)));
  });

  test('removeContactColor 清除後 getContactColor 回傳 null', () {
    ContactRepository().setContactColor('1234', const Color(0xFF3949AB));
    ContactRepository().removeContactColor('1234');
    expect(ContactRepository().getContactColor('1234'), isNull);
  });
}
