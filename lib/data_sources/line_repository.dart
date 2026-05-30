import 'dart:convert';
import 'dart:typed_data';
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
        favItems.add(Item(data, parts[1], avatarBytes));
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

  void setLineAvatar(String lineId, Uint8List bytes) {
    SharedPrefs.setString(keyLineAvatarPrefix + lineId, base64Encode(bytes));
  }

  void removeLineAvatar(String lineId) {
    SharedPrefs.removeKey(keyLineAvatarPrefix + lineId);
  }
}
