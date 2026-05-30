# Icons & Avatars Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 替換 TabBar 為 font_awesome_flutter 圖示，並為聯絡人與 LINE 聯絡人加入圓框頭像（LINE 右下角有 LINE badge）。

**Architecture:** 五個任務依序完成：TabBar 圖示 → SharedPrefs 擴充 → LINE 頭像儲存層 → FavGridView 圓框顯示 + ContactsTab → LineProvider + LINE Dialog。必須依序執行，Task 5 的 line_tab.dart 依賴 Task 4 更新後的 FavGridView 參數。

**Tech Stack:** Flutter, `font_awesome_flutter ^10.7.0`, `image_picker ^1.1.2`, `dart:convert` (base64), SharedPreferences

---

## 修改檔案清單

| 動作 | 路徑 |
|------|------|
| Modify | `pubspec.yaml` |
| Modify | `lib/utils/shared_prefs.dart` |
| Modify | `lib/constants/keys.dart` |
| Modify | `lib/data_sources/line_repository.dart` |
| Modify | `lib/providers/line_provider.dart` |
| Modify | `lib/ui/pages/home_page/home_page.dart` |
| Modify | `lib/ui/pages/home_page/fav_grid_view.dart` |
| Modify | `lib/ui/pages/home_page/contacts_tab.dart` |
| Modify | `lib/ui/pages/home_page/line_tab.dart` |
| Modify | `test/utils/shared_prefs_test.dart` |
| Create | `test/data_sources/line_repository_test.dart` |

---

## Task 1: font_awesome_flutter 套件 + TabBar 圖示

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/ui/pages/home_page/home_page.dart`

- [ ] **Step 1: 在 pubspec.yaml 加入 font_awesome_flutter**

將 `dependencies:` 區塊替換為（字母排序，加入 `font_awesome_flutter`）：

```yaml
dependencies:
  auto_size_text: ^3.0.0  
  contacts_service: ^0.6.3
  device_apps: ^2.2.0
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  font_awesome_flutter: ^10.7.0
  intl: ^0.20.2
  permission_handler: ^11.3.1
  provider: ^6.1.2
  shared_preferences: 2.2.2
  url_launcher: ^6.1.14
```

- [ ] **Step 2: 取得套件**

```bash
flutter pub get
```

Expected: 最後一行出現 `Got dependencies!`

- [ ] **Step 3: 在 home_page.dart 加入 import**

在 `lib/ui/pages/home_page/home_page.dart` 最上方現有 import 列之後加入：

```dart
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
```

- [ ] **Step 4: 替換 TabBar 三個圖示**

找到 `lib/ui/pages/home_page/home_page.dart` 中 `TabBar(tabs: [` 裡的三個 `Icon(...)` Padding child，逐一替換：

**Apps tab**（把 `Icon(Icons.apps)` 換成 `FaIcon`）：
```dart
const Padding(
  padding: EdgeInsets.fromLTRB(0, 0, 4.0, 0),
  child: FaIcon(FontAwesomeIcons.grip),
),
```

**Contacts tab**（把 `Icon(Icons.contacts)` 換成 `FaIcon`）：
```dart
const Padding(
  padding: EdgeInsets.fromLTRB(0, 0, 4.0, 0),
  child: FaIcon(FontAwesomeIcons.addressBook),
),
```

**LINE tab**（把 `Icon(Icons.message)` 換成 `FaIcon`）：
```dart
const Padding(
  padding: EdgeInsets.fromLTRB(0, 0, 4.0, 0),
  child: FaIcon(FontAwesomeIcons.line),
),
```

- [ ] **Step 5: 確認編譯正常**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/ui/pages/home_page/home_page.dart
git commit -m "feat: TabBar 圖示換用 font_awesome_flutter (grip/addressBook/line)"
```

---

## Task 2: SharedPrefs 擴充 getString / setString / removeKey

**Files:**
- Modify: `lib/utils/shared_prefs.dart`
- Modify: `test/utils/shared_prefs_test.dart`

- [ ] **Step 1: 寫失敗測試**

在 `test/utils/shared_prefs_test.dart` 的 `main()` 結尾（最後一個 `test(...)` 之後、最後的 `}` 之前）加入：

```dart
  test('getString 對不存在的 key 回傳 null', () {
    expect(SharedPrefs.getString('nonexistent_str'), isNull);
  });

  test('setString 後 getString 回傳已存值', () {
    SharedPrefs.setString('str_key', 'hello');
    expect(SharedPrefs.getString('str_key'), equals('hello'));
  });

  test('removeKey 後 getString 回傳 null', () {
    SharedPrefs.setString('remove_me', 'value');
    SharedPrefs.removeKey('remove_me');
    expect(SharedPrefs.getString('remove_me'), isNull);
  });
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
flutter test test/utils/shared_prefs_test.dart
```

Expected: FAIL — `The method 'getString' isn't defined for the class 'SharedPrefs'`

- [ ] **Step 3: 在 shared_prefs.dart 加入三個方法**

在 `lib/utils/shared_prefs.dart` 最後一個方法（`setInt`）之後、最後的 `}` 之前加入：

```dart
  static String? getString(String key) => _prefs!.getString(key);

  static void setString(String key, String value) =>
      _prefs!.setString(key, value);

  static void removeKey(String key) => _prefs!.remove(key);
```

- [ ] **Step 4: 執行測試確認通過**

```bash
flutter test test/utils/shared_prefs_test.dart
```

Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add lib/utils/shared_prefs.dart test/utils/shared_prefs_test.dart
git commit -m "feat: SharedPrefs 新增 getString / setString / removeKey"
```

---

## Task 3: LINE 頭像儲存層 (keys + LineRepository)

**Files:**
- Modify: `lib/constants/keys.dart`
- Modify: `lib/data_sources/line_repository.dart`
- Create: `test/data_sources/line_repository_test.dart`

- [ ] **Step 1: 建立測試檔**

建立 `test/data_sources/line_repository_test.dart`：

```dart
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
```

- [ ] **Step 2: 執行測試確認失敗**

```bash
flutter test test/data_sources/line_repository_test.dart
```

Expected: FAIL — `The getter 'keyLineAvatarPrefix' isn't defined`

- [ ] **Step 3: 在 keys.dart 加入 keyLineAvatarPrefix**

在 `lib/constants/keys.dart` 最後一行（`keyIsLocked`）之後加入：

```dart
const keyLineAvatarPrefix = 'line_avatar_';
```

- [ ] **Step 4: 更新 line_repository.dart**

將 `lib/data_sources/line_repository.dart` 全部內容替換為：

```dart
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
```

- [ ] **Step 5: 執行測試確認通過**

```bash
flutter test test/data_sources/line_repository_test.dart
```

Expected: `All tests passed!` (4 tests)

- [ ] **Step 6: 執行所有測試確認未破壞原有功能**

```bash
flutter test
```

Expected: All tests passed!

- [ ] **Step 7: Commit**

```bash
git add lib/constants/keys.dart lib/data_sources/line_repository.dart test/data_sources/line_repository_test.dart
git commit -m "feat: LINE 頭像儲存層 — LineRepository setLineAvatar/removeLineAvatar"
```

---

## Task 4: image_picker 套件 + FavGridView 圓框顯示 + ContactsTab

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/ui/pages/home_page/fav_grid_view.dart`
- Modify: `lib/ui/pages/home_page/contacts_tab.dart`

此任務必須在 Task 5 之前完成，因為 Task 5 的 line_tab.dart 使用 `circular` 和 `showLineBadge` 參數，這些參數由本任務加入 FavGridView。

- [ ] **Step 1: 在 pubspec.yaml 加入 image_picker**

在 `font_awesome_flutter` 之後加入（Task 1 已加入 font_awesome_flutter，此處補 image_picker）：

```yaml
  font_awesome_flutter: ^10.7.0
  image_picker: ^1.1.2
  intl: ^0.20.2
```

- [ ] **Step 2: 取得套件**

```bash
flutter pub get
```

Expected: `Got dependencies!`

- [ ] **Step 3: 更新 fav_grid_view.dart**

將 `lib/ui/pages/home_page/fav_grid_view.dart` 全部內容替換為：

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
  final bool circular;
  final bool showLineBadge;

  const FavGridView(
    this.favItems,
    this.itemOnClickAction, {
    super.key,
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
    this.circular = false,
    this.showLineBadge = false,
  });

  final Item item;
  final VoidItemFunction itemOnClickAction;
  final AutoSizeGroup itemName;
  final bool circular;
  final bool showLineBadge;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget;

    if (circular) {
      final hasPhoto = item.icon?.isNotEmpty ?? false;
      iconWidget = Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 35,
            backgroundImage: hasPhoto ? MemoryImage(item.icon!) : null,
            child: hasPhoto ? null : const Icon(Icons.person, size: 35),
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

- [ ] **Step 4: 更新 contacts_tab.dart 傳入 circular: true**

在 `lib/ui/pages/home_page/contacts_tab.dart` 找到兩處 `FavGridView(contactProvider.favContacts, openContactDialog)` 並分別改為：

```dart
FavGridView(
  contactProvider.favContacts,
  openContactDialog,
  circular: true,
)
```

兩處都要改：一處在「正常顯示」分支，一處在「有 phone permission 提示」分支下方。

- [ ] **Step 5: 確認編譯正常**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 6: 執行所有測試**

```bash
flutter test
```

Expected: All tests passed!

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/ui/pages/home_page/fav_grid_view.dart lib/ui/pages/home_page/contacts_tab.dart
git commit -m "feat: FavGridView 圓框頭像 + LINE badge，ContactsTab 啟用圓框顯示"
```

---

## Task 5: LineProvider.addLineContactWithAvatar + LINE Dialog 頭像選擇

**Files:**
- Modify: `lib/providers/line_provider.dart`
- Modify: `lib/ui/pages/home_page/line_tab.dart`

- [ ] **Step 1: 更新 line_provider.dart**

將 `lib/providers/line_provider.dart` 全部內容替換為：

```dart
import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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
      String id, String name, Uint8List? avatarBytes) async {
    await _repository.addLineContact(id, name);
    if (avatarBytes != null) {
      _repository.setLineAvatar('$id|$name', avatarBytes);
    }
    _loadFavItems();
  }
}
```

- [ ] **Step 2: 更新 line_tab.dart**

將 `lib/ui/pages/home_page/line_tab.dart` 全部內容替換為：

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
import '../../../ui/common/info_action_widget.dart';
import '../../../ui/common/loading_widget.dart';
import '../../../ui/pages/home_page/fav_grid_view.dart';

class LineTab extends StatelessWidget {
  const LineTab({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    void openAddLineDialog() {
      final lineProvider = context.read<LineProvider>();
      showDialog(
        context: context,
        builder: (dialogContext) {
          final idController = TextEditingController();
          final nameController = TextEditingController();
          Uint8List? selectedImageBytes;

          return StatefulBuilder(
            builder: (sbContext, setState) {
              return AlertDialog(
                title: Text(S.of(sbContext).dlgAddLineTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picked = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 200,
                          maxHeight: 200,
                          imageQuality: 80,
                        );
                        if (picked != null) {
                          final bytes = await picked.readAsBytes();
                          setState(() => selectedImageBytes = bytes);
                        }
                      },
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: selectedImageBytes != null
                            ? MemoryImage(selectedImageBytes!)
                            : null,
                        child: selectedImageBytes == null
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
                      if (idController.text.isNotEmpty &&
                          nameController.text.isNotEmpty) {
                        lineProvider.addLineContactWithAvatar(
                          idController.text,
                          nameController.text,
                          selectedImageBytes,
                        );
                        Navigator.pop(dialogContext);
                      }
                    },
                    child: Text(S.of(sbContext).btnAdd),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    void callLine(Item contact) {
      context.read<LineProvider>().callLine(contact.id);
    }

    return Column(
      children: <Widget>[
        Flexible(
          child: Consumer<LineProvider>(
            builder: (_, lineProvider, __) => Column(
              children: <Widget>[
                if (lineProvider.isFavListLoaded &&
                    lineProvider.favLineContacts.isNotEmpty) ...[
                  FavGridView(
                    lineProvider.favLineContacts,
                    callLine,
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
            ),
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

- [ ] **Step 3: 確認編譯正常**

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: 執行所有測試**

```bash
flutter test
```

Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add lib/providers/line_provider.dart lib/ui/pages/home_page/line_tab.dart
git commit -m "feat: LINE Dialog 加入頭像選擇，LineProvider.addLineContactWithAvatar"
```

---

## 手動驗證清單

完成所有任務後，在實機或模擬器上確認：

- [ ] TabBar 三個標籤顯示 grip / addressBook / LINE 品牌圖示
- [ ] 聯絡人 tab：有系統頭像的聯絡人顯示圓框照片；無頭像者顯示灰色圓框 + person icon
- [ ] LINE tab：點擊下方按鈕開啟 Dialog，上方有可點擊的圓形頭像區（顯示相機圖示）
- [ ] LINE Dialog：點擊頭像區可從相簿選圖，選完在 Dialog 內預覽
- [ ] 新增 LINE 聯絡人（含頭像）後，主畫面卡片顯示圓框頭像，右下角有綠色 LINE logo
- [ ] 新增 LINE 聯絡人（不選頭像）後，主畫面卡片顯示預設 person icon，右下角有 LINE logo
- [ ] Apps tab 卡片顯示不受影響（仍為方形 app icon）
