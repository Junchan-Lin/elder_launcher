import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../constants/keys.dart';
import '../models/interfaces/data_repository.dart';
import '../models/item.dart';
import '../utils/shared_prefs.dart';

class LineRepository implements DataRepository {
  @override
  Future<List<Item>> getAllItems() async => getFavItems();

  @override
  Future<List<Item>> getFavItems() async {
    var favLineData = SharedPrefs.getList(keyFavLine);
    var favItems = <Item>[];
    for (var data in favLineData) {
      var parts = data.split('|');
      if (parts.length >= 2) {
        final avatarBase64 = SharedPrefs.getString(keyLineAvatarPrefix + data);
        final avatarBytes =
            avatarBase64 != null ? base64Decode(avatarBase64) : null;
        final colorString = SharedPrefs.getString(keyLineColorPrefix + data);
        final avatarColor =
            colorString != null ? Color(int.parse(colorString)) : null;
        favItems.add(
            Item(data, parts[1], avatarBytes, avatarColor: avatarColor));
      }
    }
    return favItems;
  }

  @override
  void setFavItems(List<String> favData) {
    SharedPrefs.setList(keyFavLine, favData);
  }

  Future<void> addLineContact(String id, String name) async {
    var favLineData = SharedPrefs.getList(keyFavLine);
    favLineData.add('$id|$name');
    SharedPrefs.setList(keyFavLine, favLineData);
  }

  /// Replaces the entry for [oldData] in place (keeping its position in the
  /// favourites list) with the new id/name, and writes whichever of
  /// [avatarBytes] or [avatarColor] is provided (they're mutually exclusive;
  /// passing neither clears both, matching the entry having no avatar set).
  Future<void> updateLineContact(
    String oldData,
    String newId,
    String newName, {
    Uint8List? avatarBytes,
    Color? avatarColor,
  }) async {
    assert(avatarBytes == null || avatarColor == null,
        'avatarBytes and avatarColor are mutually exclusive');
    final newData = '$newId|$newName';

    SharedPrefs.removeKey(keyLineAvatarPrefix + oldData);
    SharedPrefs.removeKey(keyLineColorPrefix + oldData);

    if (avatarBytes != null) {
      SharedPrefs.setString(
          keyLineAvatarPrefix + newData, base64Encode(avatarBytes));
    } else if (avatarColor != null) {
      SharedPrefs.setString(
          keyLineColorPrefix + newData, avatarColor.value.toString());
    }

    var favLineData = SharedPrefs.getList(keyFavLine);
    final index = favLineData.indexOf(oldData);
    if (index != -1) {
      favLineData[index] = newData;
    } else {
      favLineData.add(newData);
    }
    SharedPrefs.setList(keyFavLine, favLineData);
  }

  void setLineAvatar(String lineId, Uint8List bytes) {
    SharedPrefs.setString(keyLineAvatarPrefix + lineId, base64Encode(bytes));
    SharedPrefs.removeKey(keyLineColorPrefix + lineId);
  }

  void removeLineAvatar(String lineId) {
    SharedPrefs.removeKey(keyLineAvatarPrefix + lineId);
  }

  void setLineColor(String lineId, Color color) {
    SharedPrefs.setString(keyLineColorPrefix + lineId, color.value.toString());
    SharedPrefs.removeKey(keyLineAvatarPrefix + lineId);
  }

  void removeLineColor(String lineId) {
    SharedPrefs.removeKey(keyLineColorPrefix + lineId);
  }
}
