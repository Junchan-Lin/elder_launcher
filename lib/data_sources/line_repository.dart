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
        favItems.add(Item(data, parts[1], null));
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
}
