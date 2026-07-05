import 'dart:convert';
import 'dart:typed_data';
import 'package:elder_launcher/constants/keys.dart';
import 'package:elder_launcher/data_sources/line_repository.dart';
import 'package:elder_launcher/utils/shared_prefs.dart';
import 'package:flutter/material.dart';
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

  group('顏色設定', () {
    test('setLineColor 儲存後 getFavItems 讀取到顏色', () async {
      LineRepository().setLineColor('user123|Alice', const Color(0xFFE53935));

      final items = await LineRepository().getFavItems();
      expect(items[0].avatarColor, equals(const Color(0xFFE53935)));
    });

    test('removeLineColor 清除後 getFavItems 顏色為 null', () async {
      LineRepository().setLineColor('user123|Alice', const Color(0xFFE53935));
      LineRepository().removeLineColor('user123|Alice');

      final items = await LineRepository().getFavItems();
      expect(items[0].avatarColor, isNull);
    });

    test('setLineAvatar 會清除同一筆資料原本設定的顏色', () async {
      LineRepository().setLineColor('user123|Alice', const Color(0xFFE53935));
      LineRepository().setLineAvatar(
          'user123|Alice', Uint8List.fromList([1, 2, 3]));

      final items = await LineRepository().getFavItems();
      expect(items[0].avatarColor, isNull);
      expect(items[0].icon, isNotNull);
    });
  });

  group('updateLineContact', () {
    test('更新後改變 id/name，並保留在清單中原本的位置', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.$keyFavLine': [
          'user123|Alice',
          'user456|Bob',
          'user789|Carol'
        ],
      });
      await SharedPrefs.init();

      await LineRepository()
          .updateLineContact('user456|Bob', 'user456', 'Bobby');

      expect(SharedPrefs.getList(keyFavLine),
          ['user123|Alice', 'user456|Bobby', 'user789|Carol']);
    });

    test('帶入新頭像時覆蓋資料並清除舊顏色', () async {
      SharedPrefs.setString(keyLineColorPrefix + 'user123|Alice',
          const Color(0xFFE53935).value.toString());
      final fakeBytes = Uint8List.fromList([9, 9, 9]);

      await LineRepository().updateLineContact(
        'user123|Alice',
        'user123',
        'Alice',
        avatarBytes: fakeBytes,
      );

      final items = await LineRepository().getFavItems();
      expect(items[0].icon, equals(fakeBytes));
      expect(items[0].avatarColor, isNull);
    });

    test('帶入新顏色時覆蓋資料並清除舊頭像', () async {
      final fakeBytes = Uint8List.fromList([1, 1, 1]);
      SharedPrefs.setString(
          keyLineAvatarPrefix + 'user123|Alice', base64Encode(fakeBytes));

      await LineRepository().updateLineContact(
        'user123|Alice',
        'user123',
        'Alice',
        avatarColor: const Color(0xFF3949AB),
      );

      final items = await LineRepository().getFavItems();
      expect(items[0].icon, isNull);
      expect(items[0].avatarColor, equals(const Color(0xFF3949AB)));
    });

    test('未帶入頭像或顏色時，兩者皆為 null', () async {
      await LineRepository()
          .updateLineContact('user456|Bob', 'user456', 'Bob2');

      final items = await LineRepository().getFavItems();
      expect(items[1].icon, isNull);
      expect(items[1].avatarColor, isNull);
    });
  });
}
