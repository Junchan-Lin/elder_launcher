import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../data_sources/widget_repository.dart';
import '../models/item.dart';
import '../utils/native_methods.dart';

class WidgetProvider extends ChangeNotifier {
  bool _isFavListLoaded = false;
  List<Item> _favWidgets = [];
  final WidgetRepository _repository;

  WidgetProvider(this._repository) {
    _loadFavItems();
  }

  bool get isFavListLoaded => _isFavListLoaded;
  UnmodifiableListView<Item> get favWidgets =>
      UnmodifiableListView(_favWidgets);

  Future<void> _loadFavItems() async {
    final storedItems = await _repository.getFavItems();
    final ids = storedItems.map((item) => int.parse(item.id)).toList();
    final validIds = await NativeMethods().filterValidWidgetIds(ids);

    final staleIds = storedItems
        .map((item) => item.id)
        .where((id) => !validIds.contains(int.parse(id)))
        .toList();
    for (final id in staleIds) {
      NativeMethods().deleteWidget(int.parse(id));
      _repository.removeWidgetData(id);
    }

    _favWidgets = storedItems
        .where((item) => validIds.contains(int.parse(item.id)))
        .toList();
    if (staleIds.isNotEmpty) {
      _repository.setFavItems(_favWidgets.map((item) => item.id).toList());
    }

    _isFavListLoaded = true;
    notifyListeners();
  }

  void reloadLists() {
    _loadFavItems();
  }

  Future<void> addWidget() async {
    final result = await NativeMethods().pickAndBindWidget();
    if (result == null) return;
    final appWidgetId = result['appWidgetId'].toString();
    final label = result['label'] as String? ?? '';
    final iconBytes = result['icon'] as Uint8List?;
    final minHeight = result['minHeight'] as int? ?? 100;
    _repository.addWidget(appWidgetId, label, iconBytes, minHeight);
    await _loadFavItems();
  }

  Future<void> saveFavWidgets(List<String> newIds) async {
    final removedIds = _favWidgets
        .map((item) => item.id)
        .where((id) => !newIds.contains(id));
    for (final id in removedIds) {
      NativeMethods().deleteWidget(int.parse(id));
      _repository.removeWidgetData(id);
    }
    _repository.setFavItems(newIds);
    await _loadFavItems();
  }

  int getWidgetHeight(String appWidgetId) =>
      _repository.getWidgetHeight(appWidgetId);
}
