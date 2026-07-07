import 'dart:typed_data';
import 'package:elder_launcher/constants/keys.dart';
import 'package:elder_launcher/data_sources/widget_repository.dart';
import 'package:elder_launcher/utils/shared_prefs.dart';
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

  test('getFavItems 沒有資料時回傳空清單', () async {
    final items = await WidgetRepository().getFavItems();
    expect(items, isEmpty);
  });

  test('addWidget 後 getFavItems 依序回傳新增的 widget', () async {
    final repository = WidgetRepository();
    repository.addWidget('1', 'Clock', Uint8List.fromList([1, 2, 3]), 120);
    repository.addWidget('2', 'Weather', null, 200);

    final items = await repository.getFavItems();

    expect(items.length, 2);
    expect(items[0].id, '1');
    expect(items[0].name, 'Clock');
    expect(items[0].icon, Uint8List.fromList([1, 2, 3]));
    expect(items[1].id, '2');
    expect(items[1].name, 'Weather');
    expect(items[1].icon, isNull);
  });

  test('getWidgetHeight 回傳新增時儲存的 minHeight', () async {
    final repository = WidgetRepository();
    repository.addWidget('1', 'Clock', null, 150);

    expect(repository.getWidgetHeight('1'), 150);
  });

  test('getWidgetHeight 沒有資料時回傳預設值 100', () async {
    expect(WidgetRepository().getWidgetHeight('999'), 100);
  });

  test('removeWidgetData 清除快取的 label/icon/height', () async {
    final repository = WidgetRepository();
    repository.addWidget('1', 'Clock', Uint8List.fromList([1, 2, 3]), 150);

    repository.removeWidgetData('1');

    expect(SharedPrefs.getString(keyWidgetLabelPrefix + '1'), isNull);
    expect(SharedPrefs.getString(keyWidgetIconPrefix + '1'), isNull);
    expect(repository.getWidgetHeight('1'), 100);
  });

  test('setFavItems 覆寫排序後的 id 清單', () async {
    final repository = WidgetRepository();
    repository.addWidget('1', 'Clock', null, 120);
    repository.addWidget('2', 'Weather', null, 200);

    repository.setFavItems(['2', '1']);

    final items = await repository.getFavItems();
    expect(items.map((e) => e.id).toList(), ['2', '1']);
  });
}
