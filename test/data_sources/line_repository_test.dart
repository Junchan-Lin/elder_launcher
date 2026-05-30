import 'dart:convert';
import 'dart:typed_data';
import 'package:elder_launcher/constants/keys.dart';
import 'package:elder_launcher/data_sources/line_repository.dart';
import 'package:elder_launcher/utils/shared_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'flutter.$keyFavLine': ['user123|Alice', 'user456|Bob'],
    });
    await SharedPrefs.init();
  });

  test('getFavItems 沒有頭像時 icon 為 null', () async {
    final items = await LineRepository().getFavItems();
    expect(items.length, 2);
    expect(items[0].id, 'user123|Alice');
    expect(items[0].name, 'Alice');
    expect(items[0].icon, isNull);
  });

  test('getFavItems 有頭像時載入 icon bytes', () async {
    final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);
    SharedPrefs.setString(
        keyLineAvatarPrefix + 'user123|Alice', base64Encode(fakeBytes));

    final items = await LineRepository().getFavItems();
    expect(items[0].icon, equals(fakeBytes));
    expect(items[1].icon, isNull);
  });

  test('setLineAvatar 儲存後 getFavItems 讀取到 icon bytes', () async {
    final fakeBytes = Uint8List.fromList([10, 20, 30]);
    LineRepository().setLineAvatar('user456|Bob', fakeBytes);

    final items = await LineRepository().getFavItems();
    expect(items[1].icon, equals(fakeBytes));
  });

  test('removeLineAvatar 清除後 getFavItems icon 為 null', () async {
    final fakeBytes = Uint8List.fromList([1, 2, 3]);
    SharedPrefs.setString(
        keyLineAvatarPrefix + 'user123|Alice', base64Encode(fakeBytes));

    LineRepository().removeLineAvatar('user123|Alice');
    final items = await LineRepository().getFavItems();
    expect(items[0].icon, isNull);
  });
}
