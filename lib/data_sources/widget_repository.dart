import 'dart:convert';
import 'dart:typed_data';
import '../constants/keys.dart';
import '../models/interfaces/data_repository.dart';
import '../models/item.dart';
import '../utils/shared_prefs.dart';

class WidgetRepository implements DataRepository {
  @override
  Future<List<Item>> getAllItems() async => getFavItems();

  @override
  Future<List<Item>> getFavItems() async {
    final ids = SharedPrefs.getList(keyFavWidgets);
    var items = <Item>[];
    for (var id in ids) {
      final label = SharedPrefs.getString(keyWidgetLabelPrefix + id) ?? '';
      final iconBase64 = SharedPrefs.getString(keyWidgetIconPrefix + id);
      final iconBytes = iconBase64 != null ? base64Decode(iconBase64) : null;
      items.add(Item(id, label, iconBytes));
    }
    return items;
  }

  @override
  void setFavItems(List<String> itemIds) {
    SharedPrefs.setList(keyFavWidgets, itemIds);
  }

  void addWidget(
      String appWidgetId, String label, Uint8List? iconBytes, int minHeight) {
    final ids = SharedPrefs.getList(keyFavWidgets);
    ids.add(appWidgetId);
    SharedPrefs.setList(keyFavWidgets, ids);
    SharedPrefs.setString(keyWidgetLabelPrefix + appWidgetId, label);
    if (iconBytes != null) {
      SharedPrefs.setString(
          keyWidgetIconPrefix + appWidgetId, base64Encode(iconBytes));
    }
    SharedPrefs.setInt(keyWidgetHeightPrefix + appWidgetId, minHeight);
  }

  void removeWidgetData(String appWidgetId) {
    SharedPrefs.removeKey(keyWidgetLabelPrefix + appWidgetId);
    SharedPrefs.removeKey(keyWidgetIconPrefix + appWidgetId);
    SharedPrefs.removeKey(keyWidgetHeightPrefix + appWidgetId);
  }

  int getWidgetHeight(String appWidgetId) =>
      SharedPrefs.getInt(keyWidgetHeightPrefix + appWidgetId, 100);
}
