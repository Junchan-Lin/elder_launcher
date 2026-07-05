# LINE 長按編輯／拍照頭像／無照片顏色標記 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** LINE tab 最愛項目可長按（解鎖時）編輯名稱／LINE ID／頭像（新增拍照選項），且 LINE 與 Contacts 項目在沒有照片時可以指定一個顏色當作圓形頭像底色（顯示姓名首字），取代千篇一律的灰底人形 icon。

**Architecture:** 沿用現有 `DataRepository`（`LineRepository`/`ContactRepository`）→ `ChangeNotifier` Provider（`LineProvider`/`ContactProvider`）→ UI（`LineTab`/`ContactsTab`/`FavGridView`）三層架構。`Item` 模型新增 `avatarColor` 欄位；顏色與頭像互斥（設定其中一個會清除另一個），皆透過既有的 `SharedPrefs` key-value 儲存。新增一個共用的 `ColorPickerGrid` widget 給 LINE 編輯對話框與 Contacts 顏色小對話框共用。

**Tech Stack:** Flutter / Dart 3、`image_picker`（新增 `ImageSource.camera`）、`shared_preferences`（透過既有 `SharedPrefs` wrapper）、`provider`、`flutter_test`（repository 層 unit test，本專案目前沒有 widget test 慣例，UI 變更以 `flutter analyze` + 手動實機驗證確認，不新增 widget test 基礎設施）。

**規格文件：** `docs/superpowers/specs/2026-07-03-line-edit-and-avatar-color-design.md`

**與規格的兩個簡化（執行時發現規格可以再精簡，符合 YAGNI）：**
1. 規格原本提到 `updateLineContact` 要有 `clearAvatar` flag 處理「明確清除頭像」的情境，但實際 UI 沒有「移除頭像」按鈕（只有 拍照／相簿／選色／取消），對話框的頭像/顏色欄位一律預先帶入現有值，使用者只能覆蓋、不能清空。因此 repository 方法直接把「目前選定的頭像 bytes 或顏色」當作最終狀態寫入即可，不需要額外的 carry-over／clear 邏輯與 flag。
2. 規格原本列的 `dlgChooseAvatarSource`／`btnConfirm` 兩個字串用不到：頭像來源選單用三個自解釋的 `ListTile`（拍照／從相簿選擇／選擇顏色）不需要額外標題；選色改成「點色塊即選定並關閉」，不需要額外的確定按鈕。

---

### Task 1: 基礎資料結構 — 色票、SharedPrefs key、Item 模型、Camera 權限

**Files:**
- Modify: `lib/ui/colors.dart`
- Modify: `lib/constants/keys.dart`
- Modify: `lib/models/item.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: 在 `lib/ui/colors.dart` 尾端新增 8 色調色盤常數**

```dart
/* Avatar fallback palette (used when no photo is set) */
const avatarColorPalette = <Color>[
  Color(0xFFE53935), // 紅
  Color(0xFFFB8C00), // 橙
  Color(0xFFFDD835), // 黃
  Color(0xFF43A047), // 綠
  elderTeal, // 品牌色（取代單純的藍）
  Color(0xFF3949AB), // 靛
  Color(0xFF8E24AA), // 紫
  Color(0xFF757575), // 灰
];
```

- [ ] **Step 2: 在 `lib/constants/keys.dart` 新增兩個 key（緊接在 `keyLineAvatarPrefix` 之後）**

```dart
const keyLineAvatarPrefix = 'line_avatar_';
const keyLineColorPrefix = 'line_color_';
const keyContactColorPrefix = 'contact_color_';
```

- [ ] **Step 3: 修改 `lib/models/item.dart`，新增 `avatarColor` 欄位**

```dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

/// Data class used for storing app or contact info.
@immutable
class Item {
  /// App package name or Phone number
  final String id;

  final String name;
  final Uint8List? icon;

  /// Fallback circle-avatar background colour, used when [icon] is null.
  final Color? avatarColor;

  const Item(this.id, this.name, this.icon, {this.avatarColor});

  @override
  // ignore: type_annotate_public_apis, avoid_renaming_method_parameters
  bool operator ==(Object o) => o is Item && o.id.compareTo(id) == 0;

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 4: 在 `android/app/src/main/AndroidManifest.xml` 新增 CAMERA 權限**（`image_picker` 的 `ImageSource.camera` 在 Android 需要此權限；沿用檔案裡既有 `android:required="false"` 的寫法，因為不是每支長者手機都有相機）

在 `<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />` 那一行之後插入：

```xml
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
```

- [ ] **Step 5: 靜態檢查確認沒有語法錯誤**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings`
Expected: 沒有新增的 error（`item.dart`/`colors.dart`/`keys.dart` 目前沒有任何程式碼引用新欄位/常數，不會有 unused 警告以外的問題）

- [ ] **Step 6: Commit**

```bash
git add lib/ui/colors.dart lib/constants/keys.dart lib/models/item.dart android/app/src/main/AndroidManifest.xml
git commit -m "feat: 新增頭像顏色調色盤、SharedPrefs key、Item.avatarColor 與 CAMERA 權限"
```

---

### Task 2: 新增 l10n 字串（拍照／編輯／選色）

**Files:**
- Modify: `lib/l10n/intl_en.arb`
- Modify: `lib/l10n/intl_zh_TW.arb`
- Modify (generated): `lib/generated/l10n.dart`, `lib/generated/intl/messages_*.dart`

- [ ] **Step 1: 在 `lib/l10n/intl_en.arb` 結尾（`"btnAdd": "Add"` 之後）新增**

```json
    "dlgAddLineTitle": "Add Line Contact",
    "hintLineId": "Line ID",
    "hintLineName": "Name",
    "btnCancel": "Cancel",
    "btnAdd": "Add",
    "dlgEditLineTitle": "Edit Line Contact",
    "btnSave": "Save",
    "btnTakePhoto": "Take Photo",
    "btnChooseFromGallery": "Choose from Gallery",
    "btnChooseColor": "Choose Colour",
    "dlgChooseColorTitle": "Choose a Colour"
}
```

- [ ] **Step 2: 在 `lib/l10n/intl_zh_TW.arb` 結尾（`"btnAdd": "新增"` 之後）新增**

```json
    "hintLineId": "Line ID",
    "hintLineName": "名稱",
    "btnCancel": "取消",
    "btnAdd": "新增",
    "dlgEditLineTitle": "編輯 Line 聯絡人",
    "btnSave": "儲存",
    "btnTakePhoto": "拍照",
    "btnChooseFromGallery": "從相簿選擇",
    "btnChooseColor": "選擇顏色",
    "dlgChooseColorTitle": "選擇顏色"
}
```

- [ ] **Step 3: 重新產生 l10n 程式碼**

Run: `flutter pub run intl_utils:generate`
Expected: 指令成功結束，`lib/generated/l10n.dart` 與 `lib/generated/intl/messages_en.dart`、`messages_zh_TW.dart` 有更新

- [ ] **Step 4: 確認新的 getter 有被產生**

Run: `grep -n "btnSave\|dlgEditLineTitle\|btnTakePhoto\|btnChooseFromGallery\|btnChooseColor\|dlgChooseColorTitle" lib/generated/l10n.dart`
Expected: 六個新字串的 getter 都出現在輸出中

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/intl_en.arb lib/l10n/intl_zh_TW.arb lib/generated
git commit -m "feat: 新增編輯 LINE 聯絡人與選色相關的 l10n 字串"
```

---

### Task 3: `LineRepository` — 顏色儲存與 `updateLineContact`

**Files:**
- Modify: `lib/data_sources/line_repository.dart`
- Test: `test/data_sources/line_repository_test.dart`

- [ ] **Step 1: 在 `test/data_sources/line_repository_test.dart` 新增測試（寫在檔案最後、`main()` 的 `}` 之前）**

先在檔案最上方的 import 區塊加入 `import 'package:flutter/material.dart';`（測試要用到 `Color`）：

> **注意（實作時發現並修正）：** 測試裡的顏色請用 `avatarColorPalette` 裡的實際色值（`const Color(0xFFE53935)`／`const Color(0xFF3949AB)`），**不要**用 `Colors.red`/`Colors.blue` 這類 `MaterialColor` 具名色。現在的 Flutter SDK（`Color.operator==`）會比較 `runtimeType`，`MaterialColor`（`Colors.red`）跟從 `int` 重建出來的 `Color`（`getFavItems()`/`getContactColor()` 內部就是這樣重建的）就算色值相同也不會 `==`，會讓斷言失敗。production code 一律只用 plain `Color` 常數（`lib/ui/colors.dart` 裡沒有任何 `MaterialColor`），測試也要跟著用 plain `Color`，這樣才符合實際使用情境。

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:elder_launcher/constants/keys.dart';
import 'package:elder_launcher/data_sources/line_repository.dart';
import 'package:elder_launcher/utils/shared_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

在既有的 4 個 test 之後、`main()` 的收尾 `}` 之前，新增：

```dart
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
      SharedPrefs.setString(
          keyLineColorPrefix + 'user123|Alice', const Color(0xFFE53935).value.toString());
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
```

- [ ] **Step 2: 執行測試，確認因為方法還不存在而失敗**

Run: `flutter test test/data_sources/line_repository_test.dart`
Expected: FAIL，錯誤訊息包含 `The method 'setLineColor' isn't defined` / `updateLineContact` 之類的編譯錯誤

- [ ] **Step 3: 修改 `lib/data_sources/line_repository.dart`，實作顏色相關方法與 `updateLineContact`**

完整檔案內容：

```dart
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
```

- [ ] **Step 4: 執行測試，確認全部通過**

Run: `flutter test test/data_sources/line_repository_test.dart`
Expected: PASS（全部 test，包含原本已存在的 4 個與新增的 7 個）

- [ ] **Step 5: Commit**

```bash
git add lib/data_sources/line_repository.dart test/data_sources/line_repository_test.dart
git commit -m "feat: LineRepository 新增顏色儲存與 updateLineContact"
```

---

### Task 4: `LineProvider` — `editLineContact` 與 `addLineContactWithAvatar` 支援顏色

**Files:**
- Modify: `lib/providers/line_provider.dart`

- [ ] **Step 1: 修改 `lib/providers/line_provider.dart`**

完整檔案內容：

```dart
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
```

- [ ] **Step 2: 靜態檢查**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings lib/providers/line_provider.dart`
Expected: 沒有 error（`line_tab.dart` 這時還沒改用新參數，維持相容）

- [ ] **Step 3: Commit**

```bash
git add lib/providers/line_provider.dart
git commit -m "feat: LineProvider 新增 editLineContact，addLineContactWithAvatar 支援顏色"
```

---

### Task 5: `ContactRepository` — 顏色儲存

**Files:**
- Modify: `lib/data_sources/contact_repository.dart`
- Test: `test/data_sources/contact_repository_color_test.dart`（新檔案）

現有 `test/data_sources/contact_repository_test.dart` 整份被註解掉（既有的 `contacts_service` mock 流程目前是停用狀態），顏色功能只依賴 `SharedPrefs`、跟 `ContactsService` 無關，所以另外開一個獨立、可以直接跑的測試檔，不去動原本停用的檔案。

> **注意（Task 3 實作時發現並修正的同一個問題）：** 測試裡的顏色一律用 plain `Color` 常數（如 `const Color(0xFF3949AB)`），**不要**用 `Colors.blue` 這類 `MaterialColor` 具名色 —— 目前 Flutter SDK 的 `Color.operator==` 會比較 `runtimeType`，`getContactColor()` 用 `Color(int.parse(...))` 重建出來的一定是 plain `Color`，跟 `MaterialColor` 就算色值相同也不會 `==`，斷言會失敗。

- [ ] **Step 1: 新增 `test/data_sources/contact_repository_color_test.dart`**

```dart
import 'package:elder_launcher/data_sources/contact_repository.dart';
import 'package:elder_launcher/utils/shared_prefs.dart';
import 'package:flutter/material.dart';
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

  test('未設定顏色時 getContactColor 回傳 null', () {
    expect(ContactRepository().getContactColor('1234'), isNull);
  });

  test('setContactColor 後 getContactColor 讀取到相同顏色', () {
    ContactRepository().setContactColor('1234', const Color(0xFF3949AB));
    expect(ContactRepository().getContactColor('1234'),
        equals(const Color(0xFF3949AB)));
  });

  test('removeContactColor 清除後 getContactColor 回傳 null', () {
    ContactRepository().setContactColor('1234', const Color(0xFF3949AB));
    ContactRepository().removeContactColor('1234');
    expect(ContactRepository().getContactColor('1234'), isNull);
  });
}
```

- [ ] **Step 2: 執行測試，確認因方法不存在而失敗**

Run: `flutter test test/data_sources/contact_repository_color_test.dart`
Expected: FAIL，編譯錯誤 `The method 'setContactColor' isn't defined for the type 'ContactRepository'`

- [ ] **Step 3: 修改 `lib/data_sources/contact_repository.dart`**

完整檔案內容：

```dart
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart' show Color;
import '../constants/keys.dart';
import '../models/interfaces/data_repository.dart';
import '../models/item.dart' as item;
import '../utils/shared_prefs.dart';

class ContactRepository implements DataRepository {
  @override
  Future<List<item.Item>> getAllItems() async {
    var allContacts = await ContactsService.getContacts(
        orderByGivenName: true, photoHighResolution: false);
    return _toDistinctItems(allContacts);
  }

  @override
  Future<List<item.Item>> getFavItems() async {
    var favContactNumbers = SharedPrefs.getList(keyFavContacts);
    var favContacts = <item.Item>[];
    for (var number in favContactNumbers) {
      favContacts.add(
          _toItem(number, await ContactsService.getContactsForPhone(number)));
    }
    return favContacts;
  }

  @override
  void setFavItems(List<String> favNumbers) {
    SharedPrefs.setList(keyFavContacts, favNumbers);
  }

  void setContactColor(String contactId, Color color) {
    SharedPrefs.setString(
        keyContactColorPrefix + contactId, color.value.toString());
  }

  Color? getContactColor(String contactId) {
    final colorString =
        SharedPrefs.getString(keyContactColorPrefix + contactId);
    return colorString != null ? Color(int.parse(colorString)) : null;
  }

  void removeContactColor(String contactId) {
    SharedPrefs.removeKey(keyContactColorPrefix + contactId);
  }

  // TODO: Performance optimization
  List<item.Item> _toDistinctItems(Iterable<Contact> contacts) {
    var contacts0 = <item.Item>{};

    for (var contact in contacts) {
      var numbers = <String>{};

      if (contact.phones != null) {
        for (var number in contact.phones!) {
          if (number.value != null) {
            numbers.add(
              number.value!.replaceAll(
                RegExp('[^a-zA-Z0-9+]+'),
                '',
              ),
            );
          }
        }
      }

      for (var number in numbers) {
        if (contact.displayName != null) {
          contacts0.add(
            item.Item(number, contact.displayName!, contact.avatar),
          );
        } else {
          contacts0.add(
            item.Item(number, number, contact.avatar),
          );
        }
      }
    }
    return contacts0.toList();
  }

  item.Item _toItem(String number, Iterable<Contact> contacts) {
    final avatarColor = getContactColor(number);
    if (contacts.first.displayName != null) {
      return item.Item(
        number,
        contacts.first.displayName!,
        contacts.first.avatar,
        avatarColor: avatarColor,
      );
    } else {
      return item.Item(number, number, contacts.first.avatar,
          avatarColor: avatarColor);
    }
  }
}
```

> 註：`getAllItems()`／`_toDistinctItems` 刻意不帶 `avatarColor` — 那個清單只用在 Edit Page 的「新增/移除最愛」勾選畫面（`MultiSelectWidget`），還不是最愛，使用者也還沒有機會對它長按設色，維持現況即可，避免不必要的範圍擴大。

- [ ] **Step 4: 執行測試，確認全部通過**

Run: `flutter test test/data_sources/contact_repository_color_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data_sources/contact_repository.dart test/data_sources/contact_repository_color_test.dart
git commit -m "feat: ContactRepository 新增聯絡人顏色儲存"
```

---

### Task 6: `ContactProvider` — 顏色設定/清除

**Files:**
- Modify: `lib/providers/contact_provider.dart:1-11`（imports 與新增方法）

- [ ] **Step 1: 在 `lib/providers/contact_provider.dart` 頂部加入 import，並在檔案最後（`saveFavContacts` 方法之後、class 結尾 `}` 之前）新增兩個方法**

Import 區塊（現有的 `import 'package:flutter/foundation.dart';` 之後新增一行）：

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:permission_handler/permission_handler.dart';
```

在 `saveFavContacts` 之後新增：

```dart
  Future<void> setContactColor(String contactId, Color color) async {
    _repository.setContactColor(contactId, color);
    _loadFavItems();
  }

  Future<void> removeContactColor(String contactId) async {
    _repository.removeContactColor(contactId);
    _loadFavItems();
  }
```

- [ ] **Step 2: 靜態檢查**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings lib/providers/contact_provider.dart`
Expected: 沒有 error

- [ ] **Step 3: Commit**

```bash
git add lib/providers/contact_provider.dart
git commit -m "feat: ContactProvider 新增 setContactColor/removeContactColor"
```

---

### Task 7: 共用元件 `ColorPickerGrid`

**Files:**
- Create: `lib/ui/common/color_picker_grid.dart`

- [ ] **Step 1: 建立 `lib/ui/common/color_picker_grid.dart`**

```dart
import 'package:flutter/material.dart';
import '../colors.dart';

/// A grid of large, tappable colour swatches used as the fallback avatar
/// colour picker for LINE contacts and phone contacts. Tapping a swatch
/// immediately reports the selection via [onColorSelected].
class ColorPickerGrid extends StatelessWidget {
  final Color? selectedColor;
  final ValueChanged<Color> onColorSelected;

  const ColorPickerGrid({
    super.key,
    required this.onColorSelected,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      padding: const EdgeInsets.all(8),
      children: avatarColorPalette.map((color) {
        final isSelected = color == selectedColor;
        return Padding(
          padding: const EdgeInsets.all(6),
          child: GestureDetector(
            onTap: () => onColorSelected(color),
            child: CircleAvatar(
              backgroundColor: color,
              radius: 28,
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 28)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 2: 靜態檢查**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings lib/ui/common/color_picker_grid.dart`
Expected: 沒有 error

- [ ] **Step 3: Commit**

```bash
git add lib/ui/common/color_picker_grid.dart
git commit -m "feat: 新增共用的 ColorPickerGrid 元件"
```

---

### Task 8: `FavGridView`/`FavItemCard` — 三態頭像與長按

**Files:**
- Modify: `lib/ui/pages/home_page/fav_grid_view.dart`

- [ ] **Step 1: 修改 `lib/ui/pages/home_page/fav_grid_view.dart`**

完整檔案內容：

```dart
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../constants/custom_functions.dart';
import '../../../models/item.dart';
import '../../../ui/theme.dart';

class FavGridView extends StatelessWidget {
  final List<Item> favItems;
  final VoidItemFunction itemOnClickAction;
  final VoidItemFunction? itemOnLongPressAction;
  final bool circular;
  final bool showLineBadge;

  const FavGridView(
    this.favItems,
    this.itemOnClickAction, {
    super.key,
    this.itemOnLongPressAction,
    this.circular = false,
    this.showLineBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    var itemName = AutoSizeGroup();

    return Expanded(
      child: GridView.count(
        childAspectRatio: 1.25,
        crossAxisCount: 2,
        padding: const EdgeInsets.all(6),
        children: favItems.map((item) {
          return FavItemCard(
            item: item,
            itemOnClickAction: itemOnClickAction,
            itemOnLongPressAction: itemOnLongPressAction,
            itemName: itemName,
            circular: circular,
            showLineBadge: showLineBadge,
          );
        }).toList(),
      ),
    );
  }
}

class FavItemCard extends StatelessWidget {
  const FavItemCard({
    super.key,
    required this.item,
    required this.itemOnClickAction,
    required this.itemName,
    this.itemOnLongPressAction,
    this.circular = false,
    this.showLineBadge = false,
  });

  final Item item;
  final VoidItemFunction itemOnClickAction;
  final VoidItemFunction? itemOnLongPressAction;
  final AutoSizeGroup itemName;
  final bool circular;
  final bool showLineBadge;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget;

    if (circular) {
      final hasPhoto = item.icon?.isNotEmpty ?? false;
      final hasColor = !hasPhoto && item.avatarColor != null;
      iconWidget = Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: hasColor ? item.avatarColor : null,
            backgroundImage: hasPhoto ? MemoryImage(item.icon!) : null,
            child: hasPhoto
                ? null
                : hasColor
                    ? Text(
                        item.name.isNotEmpty
                            ? item.name[0].toUpperCase()
                            : '?',
                        style:
                            TextStyles.cardTitle.copyWith(color: Colors.white),
                      )
                    : const Icon(Icons.person, size: 35),
          ),
          if (showLineBadge)
            const FaIcon(
              FontAwesomeIcons.line,
              size: 18,
              color: Color(0xFF06C755),
            ),
        ],
      );
    } else if (item.icon?.isNotEmpty ?? false) {
      iconWidget = Image(
        height: 70,
        image: MemoryImage(item.icon!),
      );
    } else {
      iconWidget = const SizedBox.shrink();
    }

    return Card(
      color: Theme.of(context).cardColor,
      elevation: 4,
      child: InkWell(
        splashColor: Colors.blue.withAlpha(50),
        onTap: () => itemOnClickAction(item),
        onLongPress: itemOnLongPressAction != null
            ? () => itemOnLongPressAction!(item)
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            iconWidget,
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 2, 0, 0),
                child: AutoSizeText(
                  item.name,
                  group: itemName,
                  maxLines: 2,
                  style: TextStyles.cardTitle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 靜態檢查**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings lib/ui/pages/home_page/fav_grid_view.dart`
Expected: 沒有 error（此時 `apps_tab.dart`/`contacts_tab.dart`/`line_tab.dart` 呼叫 `FavGridView(...)` 都沒有帶 `itemOnLongPressAction`，因為是 optional 具預設值 `null`，維持相容）

- [ ] **Step 3: Commit**

```bash
git add lib/ui/pages/home_page/fav_grid_view.dart
git commit -m "feat: FavItemCard 支援長按與顏色+首字的頭像 fallback"
```

---

### Task 9: `LineTab` — 合併新增/編輯對話框、拍照/相簿/選色選單、長按觸發

**Files:**
- Modify: `lib/ui/pages/home_page/line_tab.dart`

- [ ] **Step 1: 用以下內容整份取代 `lib/ui/pages/home_page/line_tab.dart`**

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../generated/l10n.dart';
import '../../../providers/line_provider.dart';
import '../../../models/item.dart';
import '../../../providers/lock_provider.dart';
import '../../../ui/common/buttons.dart';
import '../../../ui/common/color_picker_grid.dart';
import '../../../ui/common/info_action_widget.dart';
import '../../../ui/common/loading_widget.dart';
import '../../../ui/pages/home_page/fav_grid_view.dart';
import '../../../utils/item_utils.dart';

typedef _AvatarPickResult = ({Uint8List? bytes, Color? color});

class LineTab extends StatelessWidget {
  const LineTab({super.key});

  Future<_AvatarPickResult?> _pickAvatarSource(BuildContext context) {
    return showModalBottomSheet<_AvatarPickResult>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, size: 32),
              title: Text(S.of(sheetContext).btnTakePhoto),
              onTap: () async {
                final picked = await ImagePicker().pickImage(
                  source: ImageSource.camera,
                  maxWidth: 200,
                  maxHeight: 200,
                  imageQuality: 80,
                );
                final bytes = picked != null ? await picked.readAsBytes() : null;
                final _AvatarPickResult? result =
                    bytes != null ? (bytes: bytes, color: null) : null;
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext, result);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, size: 32),
              title: Text(S.of(sheetContext).btnChooseFromGallery),
              onTap: () async {
                final picked = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 200,
                  maxHeight: 200,
                  imageQuality: 80,
                );
                final bytes = picked != null ? await picked.readAsBytes() : null;
                final _AvatarPickResult? result =
                    bytes != null ? (bytes: bytes, color: null) : null;
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext, result);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette, size: 32),
              title: Text(S.of(sheetContext).btnChooseColor),
              onTap: () async {
                final color = await showDialog<Color>(
                  context: sheetContext,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(S.of(dialogContext).dlgChooseColorTitle),
                    content: ColorPickerGrid(
                      onColorSelected: (color) =>
                          Navigator.pop(dialogContext, color),
                    ),
                  ),
                );
                final _AvatarPickResult? result =
                    color != null ? (bytes: null, color: color) : null;
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext, result);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLineContactDialog(BuildContext context, {Item? existingItem}) {
    final lineProvider = context.read<LineProvider>();
    final isEditing = existingItem != null;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final idController = TextEditingController(
            text: existingItem != null ? formatItemId(existingItem.id) : '');
        final nameController =
            TextEditingController(text: existingItem?.name ?? '');
        Uint8List? selectedImageBytes = existingItem?.icon;
        Color? selectedColor = existingItem?.avatarColor;

        return StatefulBuilder(
          builder: (sbContext, setState) {
            return AlertDialog(
              title: Text(isEditing
                  ? S.of(sbContext).dlgEditLineTitle
                  : S.of(sbContext).dlgAddLineTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final result = await _pickAvatarSource(sbContext);
                      if (result != null) {
                        setState(() {
                          selectedImageBytes = result.bytes;
                          selectedColor = result.color;
                        });
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor:
                          selectedImageBytes == null ? selectedColor : null,
                      backgroundImage: selectedImageBytes != null
                          ? MemoryImage(selectedImageBytes!)
                          : null,
                      child: selectedImageBytes == null && selectedColor == null
                          ? const Icon(Icons.add_a_photo, size: 30)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                        hintText: S.of(sbContext).hintLineName),
                  ),
                  TextField(
                    controller: idController,
                    decoration:
                        InputDecoration(hintText: S.of(sbContext).hintLineId),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(S.of(sbContext).btnCancel),
                ),
                TextButton(
                  onPressed: () {
                    if (idController.text.isEmpty ||
                        nameController.text.isEmpty) {
                      return;
                    }
                    if (existingItem != null) {
                      lineProvider.editLineContact(
                        existingItem,
                        idController.text,
                        nameController.text,
                        avatarBytes: selectedImageBytes,
                        avatarColor: selectedColor,
                      );
                    } else {
                      lineProvider.addLineContactWithAvatar(
                        idController.text,
                        nameController.text,
                        selectedImageBytes,
                        color: selectedColor,
                      );
                    }
                    Navigator.pop(dialogContext);
                  },
                  child: Text(isEditing
                      ? S.of(sbContext).btnSave
                      : S.of(sbContext).btnAdd),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    void openAddLineDialog() => _showLineContactDialog(context);

    void callLine(Item contact) {
      context.read<LineProvider>().callLine(contact.id);
    }

    return Column(
      children: <Widget>[
        Flexible(
          child: Consumer<LineProvider>(
            builder: (_, lineProvider, __) {
              final isLocked = context.watch<LockProvider>().isLocked;
              void editItem(Item item) =>
                  _showLineContactDialog(context, existingItem: item);

              return Column(
                children: <Widget>[
                  if (lineProvider.isFavListLoaded &&
                      lineProvider.favLineContacts.isNotEmpty) ...[
                    FavGridView(
                      lineProvider.favLineContacts,
                      callLine,
                      itemOnLongPressAction: isLocked ? null : editItem,
                      circular: true,
                      showLineBadge: true,
                    )
                  ] else if (lineProvider.isFavListLoaded &&
                      lineProvider.favLineContacts.isEmpty) ...[
                    Expanded(
                      child: InfoActionWidget.add(
                        message: S.of(context).msgNoFavourites,
                        buttonLabel: S.of(context).btnAddFavLine,
                        buttonOnClickAction: openAddLineDialog,
                      ),
                    ),
                  ] else ...[
                    const LoadingWidget(),
                  ],
                ],
              );
            },
          ),
        ),
        Consumer<LockProvider>(
          builder: (context, lockProvider, _) => lockProvider.isLocked
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.bottomCenter,
                  child: PrimaryButton(
                    S.of(context).btnAddFavLine,
                    openAddLineDialog,
                  ),
                ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 靜態檢查**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings lib/ui/pages/home_page/line_tab.dart`
Expected: 沒有 error

- [ ] **Step 3: Commit**

```bash
git add lib/ui/pages/home_page/line_tab.dart
git commit -m "feat: LINE tab 支援長按編輯、拍照頭像與選色"
```

---

### Task 10: `ContactsTab` — 長按選色小對話框

**Files:**
- Modify: `lib/ui/pages/home_page/contacts_tab.dart`

> **注意（實作時發現並修正）：** `openColorPickerDialog` 的 `.then((color) { ... })` callback 在 dialog 關閉後（跨過一個 async gap）才存取外層 `context`，`flutter analyze` 會標記 `use_build_context_synchronously`；下方程式碼已經補上 `context.mounted` 檢查，跟 Task 9 `LineTab` 的 `setState` mounted 檢查是同一類問題的修正。

- [ ] **Step 1: 用以下內容整份取代 `lib/ui/pages/home_page/contacts_tab.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/edit_mode.dart';
import '../../../constants/route_names.dart';
import '../../../generated/l10n.dart';
import '../../../providers/contact_provider.dart';
import '../../../models/item.dart';
import '../../../ui/common/buttons.dart';
import '../../../ui/common/color_picker_grid.dart';
import '../../../ui/common/info_action_widget.dart';
import '../../../ui/common/loading_widget.dart';
import '../../../ui/pages/home_page/call_dialog.dart';
import '../../../ui/pages/home_page/fav_grid_view.dart';
import '../../common/action_panel.dart';
import '../../../providers/lock_provider.dart';

class ContactsTab extends StatelessWidget {
  const ContactsTab({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    void openAllContacts() {
      context.read<ContactProvider>().launchContactsApp();
    }

    void openContactDialog(Item contact) {
      CallDialog(context, contact);
    }

    void openColorPickerDialog(Item contact) {
      showDialog<Color>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(S.of(dialogContext).dlgChooseColorTitle),
          content: ColorPickerGrid(
            selectedColor: contact.avatarColor,
            onColorSelected: (color) => Navigator.pop(dialogContext, color),
          ),
        ),
      ).then((color) {
        if (color != null && context.mounted) {
          context.read<ContactProvider>().setContactColor(contact.id, color);
        }
      });
    }

    void openEditScreen() {
      Navigator.pushNamed(context, editPageRoute, arguments: EditMode.contacts);
    }

    void requestContactsPermission() {
      context.read<ContactProvider>().requestContactsPermission();
    }

    void requestPhonePermission() {
      context.read<ContactProvider>().requestPhonePermission();
    }

    return Column(
      children: <Widget>[
        Flexible(
          child: Consumer<ContactProvider>(
            builder: (_, contactProvider, __) {
              final itemOnLongPressAction = context.watch<LockProvider>().isLocked
                  ? null
                  : openColorPickerDialog;

              return Column(
                children: <Widget>[
                  if (contactProvider.isFavListLoaded &&
                      contactProvider.favContacts.isNotEmpty &&
                      contactProvider.isPhonePermissionChecked &&
                      contactProvider.isPhonePermissionGranted) ...[
                    // Show Favourite Contacts
                    FavGridView(
                      contactProvider.favContacts,
                      openContactDialog,
                      itemOnLongPressAction: itemOnLongPressAction,
                      circular: true,
                    )
                  ] else if (contactProvider.isFavListLoaded &&
                      contactProvider.favContacts.isNotEmpty &&
                      contactProvider.isPhonePermissionChecked &&
                      !contactProvider.isPhonePermissionGranted &&
                      contactProvider.isTelephoneFeatureChecked &&
                      contactProvider.hasTelephoneFeature) ...[
                    // Show Favourite Contacts with Phone Permission Prompt
                    ActionPanel(
                      heading: S.of(context).btnGrantPermission,
                      body: InfoActionWidget(
                          S.of(context).msgNoPhonePermission,
                          S.of(context).btnGrantPermission,
                          Icons.phone,
                          requestPhonePermission),
                    ),
                    FavGridView(
                      contactProvider.favContacts,
                      openContactDialog,
                      itemOnLongPressAction: itemOnLongPressAction,
                      circular: true,
                    )
                  ] else if (contactProvider.isFavListLoaded &&
                      contactProvider.favContacts.isEmpty) ...[
                    // Show Add Favourites Prompt
                    Expanded(
                      child: InfoActionWidget.add(
                        message: S.of(context).msgNoFavourites,
                        buttonLabel: S.of(context).btnAddFavContacts,
                        buttonOnClickAction: openEditScreen,
                      ),
                    ),
                  ] else if (contactProvider.isContactsPermissionChecked &&
                      !contactProvider.isContactsPermissionGranted) ...[
                    // Show Contacts Permission Prompt
                    Expanded(
                      child: InfoActionWidget(
                          S.of(context).msgNoContactsPermission,
                          S.of(context).btnGrantPermission,
                          Icons.perm_contact_calendar,
                          requestContactsPermission),
                    )
                  ] else ...[
                    const LoadingWidget(),
                  ],
                ],
              );
            },
          ),
        ),
        Consumer<LockProvider>(
          builder: (context, lockProvider, _) => lockProvider.isLocked
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.bottomCenter,
                  child: PrimaryButton(
                    S.of(context).btnAllContacts,
                    openAllContacts,
                  ),
                ),
        ),
      ],
    );
  }
}
```

`itemOnLongPressAction` 的型別是 `VoidItemFunction?`（`void Function(Item)?`），`openColorPickerDialog` 本身簽名就是 `void Function(Item contact)`，型別對得上 `FavGridView` 的 `itemOnLongPressAction` 參數。

- [ ] **Step 2: 靜態檢查**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings lib/ui/pages/home_page/contacts_tab.dart`
Expected: 沒有 error

- [ ] **Step 3: Commit**

```bash
git add lib/ui/pages/home_page/contacts_tab.dart
git commit -m "feat: Contacts tab 支援長按選擇頭像顏色"
```

---

### Task 11: 全專案驗證

**Files:** 無新增變更，純驗證

- [ ] **Step 1: 全量靜態分析**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings`
Expected: 沒有 error（可能有既有的 info/warning，跟 CI 設定一致，不因新增程式碼而新增 error）

- [ ] **Step 2: 全量測試**

Run: `flutter test`
Expected: 全部 PASS

- [ ] **Step 3: 實機/模擬器手動驗證（自動化測試涵蓋不到的部分）**

Run: `flutter run`，在裝置上手動確認：
1. LINE tab：解鎖狀態下長按最愛項目 → 彈出「編輯 Line 聯絡人」，欄位與頭像/顏色皆正確預填；修改後儲存，項目在原本的 Grid 位置被更新（不會跳到最後）。
2. LINE tab：鎖定狀態下長按最愛項目 → 沒有反應。
3. 新增/編輯 LINE 聯絡人時點頭像 → 可選「拍照」（需授權相機權限）、「從相簿選擇」、「選擇顏色」。
4. 選了顏色但沒有照片的 LINE/Contacts 項目 → 圓形頭像顯示該顏色 + 姓名首字。
5. Contacts tab：解鎖時長按最愛聯絡人 → 彈出選色小對話框，選色後頭像底色即時更新。

- [ ] **Step 4: 若手動驗證發現問題，修正後重跑 Step 1-2 再 commit；若全部通過則不需要額外 commit（此 Task 純驗證）**
