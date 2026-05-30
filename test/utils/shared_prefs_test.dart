import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elder_launcher/utils/shared_prefs.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefs.init();
  });

  test('getList 對不存在的 key 回傳空列表', () {
    expect(SharedPrefs.getList('missing'), isEmpty);
  });

  test('setList 後 getList 回傳已存值', () {
    SharedPrefs.setList('k', ['a', 'b']);
    expect(SharedPrefs.getList('k'), equals(['a', 'b']));
  });

  test('getBool 對不存在的 key 回傳 defaultValue', () {
    expect(SharedPrefs.getBool('missing', true), isTrue);
    expect(SharedPrefs.getBool('missing2', false), isFalse);
  });

  test('setBool 後 getBool 回傳已存值', () {
    SharedPrefs.setBool('b', false);
    expect(SharedPrefs.getBool('b', true), isFalse);
  });
}
