import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:url_launcher/url_launcher.dart';
import '../data_sources/line_repository.dart';
import '../models/item.dart';
import '../utils/item_utils.dart';

class LineProvider extends ChangeNotifier {
  bool _isFavListLoaded = false;
  List<Item> _favLineContacts = [];
  final LineRepository _repository;

  LineProvider(this._repository) {
    _loadFavItems();
  }

  bool get isFavListLoaded => _isFavListLoaded;
  UnmodifiableListView<Item> get favLineContacts =>
      UnmodifiableListView(_favLineContacts);

  Future<void> _loadFavItems() async {
    _favLineContacts = await _repository.getFavItems();
    _isFavListLoaded = true;
    notifyListeners();
  }

  Future<void> callLine(String combinedId) async {
    final url =
        Uri.parse('https://line.me/R/ti/p/~${formatItemId(combinedId)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('無法開啟 LINE 連結');
      }
    } catch (e) {
      debugPrint('呼叫 LINE 時發生錯誤: $e');
    }
  }

  void reloadLists() {
    _loadFavItems();
  }

  Future<void> saveFavLineContacts(List<String> newFavContacts) async {
    _repository.setFavItems(newFavContacts);
    _loadFavItems();
  }

  Future<void> addLineContact(String id, String name) async {
    await _repository.addLineContact(id, name);
    _loadFavItems();
  }

  Future<void> addLineContactWithAvatar(
    String id,
    String name,
    Uint8List? avatarBytes, {
    Color? color,
  }) async {
    await _repository.addLineContact(id, name);
    if (avatarBytes != null) {
      _repository.setLineAvatar('$id|$name', avatarBytes);
    } else if (color != null) {
      _repository.setLineColor('$id|$name', color);
    }
    _loadFavItems();
  }

  Future<void> editLineContact(
    Item existingItem,
    String newId,
    String newName, {
    Uint8List? avatarBytes,
    Color? avatarColor,
  }) async {
    await _repository.updateLineContact(
      existingItem.id,
      newId,
      newName,
      avatarBytes: avatarBytes,
      avatarColor: avatarColor,
    );
    _loadFavItems();
  }
}
