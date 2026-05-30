# Elder Launcher 全面優化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修復記憶體洩漏與非同步 Bug、透過靜態 SharedPrefs 提升效能、實作鎖定功能防止誤觸，以及完成 Package 更名。

**Architecture:** 變更由底層往上：SharedPrefs（靜態同步快取）→ Repositories（移除不必要 await）→ Providers（修 Bug）→ UI（Lock 功能）。Package 更名為 Android 層獨立作業。

**Tech Stack:** Flutter 3.x, Dart 3, Provider 6, SharedPreferences 2.2.2, DeviceApps 2.2, Android Gradle, Kotlin

---

## 檔案變更總覽

| 檔案 | 類型 |
|------|------|
| `lib/utils/shared_prefs.dart` | 重構 |
| `lib/main.dart` | 修改 |
| `lib/constants/keys.dart` | 修改 |
| `lib/constants/channels.dart` | 修改（Package 更名） |
| `lib/models/interfaces/data_repository.dart` | 不變（setFavItems 維持 void） |
| `lib/data_sources/app_repository.dart` | 重構 + 效能 |
| `lib/data_sources/contact_repository.dart` | 重構 |
| `lib/data_sources/line_repository.dart` | 重構 |
| `lib/providers/app_provider.dart` | Bug 修復 |
| `lib/providers/contact_provider.dart` | 架構改善 |
| `lib/providers/line_provider.dart` | 重構 |
| `lib/providers/lock_provider.dart` | 新增 |
| `lib/ui/pages/home_page/edit_dialog.dart` | Bug 修復 |
| `lib/ui/pages/home_page/home_page.dart` | Lock UI |
| `lib/ui/pages/home_page/apps_tab.dart` | Lock 整合 |
| `lib/ui/pages/home_page/contacts_tab.dart` | Lock 整合 |
| `lib/ui/pages/home_page/line_tab.dart` | Lock 整合 |
| `lib/ui/pages/settings_page/settings_page.dart` | 清理 |
| `lib/l10n/intl_*.arb`（14 個） | 新增 `dlgLineReload` |
| `lib/generated/intl/messages_*.dart` | 自動重新生成 |
| `android/app/build.gradle` | Package 更名 |
| `android/app/src/main/kotlin/` | 目錄搬移 + 更名 |
| `test/utils/shared_prefs_test.dart` | 新增 |
| `test/providers/lock_provider_test.dart` | 新增 |

---

### Task 1：SharedPrefs 重構為靜態同步快取

**說明：** SharedPrefs 改為靜態類別，init() 在 main() 呼叫一次，之後所有方法同步完成，不再每次呼叫 `getInstance()`。這是其他所有 Task 的基礎。

**Files:**
- Modify: `lib/utils/shared_prefs.dart`
- Modify: `lib/main.dart`
- Create: `test/utils/shared_prefs_test.dart`

- [ ] **Step 1: 建立測試檔案**

建立 `test/utils/shared_prefs_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elder_launcher/utils/shared_prefs.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefs.init();
  });

  test('getList 對不存在的 key 回傳空列表', () {
    expect(SharedPrefs.getList('missing'), isEmpty);
  });

  test('setList 後 getList 回傳已存值', () {
    SharedPrefs.setList('k', ['a', 'b']);
    expect(SharedPrefs.getList('k'), equals(['a', 'b']));
  });

  test('getBool 對不存在的 key 回傳 defaultValue', () {
    expect(SharedPrefs.getBool('missing', true), isTrue);
    expect(SharedPrefs.getBool('missing2', false), isFalse);
  });

  test('setBool 後 getBool 回傳已存值', () {
    SharedPrefs.setBool('b', false);
    expect(SharedPrefs.getBool('b', true), isFalse);
  });
}
```

- [ ] **Step 2: 確認測試失敗**

```bash
flutter test test/utils/shared_prefs_test.dart
```
Expected: FAIL（`SharedPrefs.init` undefined）

- [ ] **Step 3: 重寫 `lib/utils/shared_prefs.dart`**

```dart
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static List<String> getList(String key) =>
      _prefs!.getStringList(key) ?? [];

  static void setList(String key, List<String> stringList) =>
      _prefs!.setStringList(key, stringList);

  // ignore: avoid_positional_boolean_parameters
  static bool getBool(String key, bool defaultValue) =>
      _prefs!.getBool(key) ?? defaultValue;

  // ignore: avoid_positional_boolean_parameters
  static void setBool(String key, bool value) =>
      _prefs!.setBool(key, value);

  static int getInt(String key, int defaultValue) =>
      _prefs!.getInt(key) ?? defaultValue;

  static void setInt(String key, int value) =>
      _prefs!.setInt(key, value);
}
```

- [ ] **Step 4: 更新 `lib/main.dart` — 加入 init() + import**

將 `main()` 改為：

```dart
import 'utils/shared_prefs.dart';
// （其餘 import 不變）

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefs.init();
  runApp(const MyApp());
}
```

- [ ] **Step 5: 確認測試通過**

```bash
flutter test test/utils/shared_prefs_test.dart
```
Expected: 4 tests PASS

- [ ] **Step 6: Commit**

```bash
git add lib/utils/shared_prefs.dart lib/main.dart test/utils/shared_prefs_test.dart
git commit -m "refactor: SharedPrefs 改為靜態同步快取，main() 初始化一次"
```

---

### Task 2：Repository 呼叫更新

**說明：** 三個 repository 改用靜態 `SharedPrefs.xxx()` 呼叫，移除不必要的 `await`。`AppRepository.getFavItems()` 改用 `Future.wait` 並行載入，`_sortItems` 移除多餘的 `async`。

**Files:**
- Modify: `lib/data_sources/app_repository.dart`
- Modify: `lib/data_sources/contact_repository.dart`
- Modify: `lib/data_sources/line_repository.dart`

- [ ] **Step 1: 取代 `lib/data_sources/app_repository.dart`**

```dart
import 'dart:typed_data';
import 'package:device_apps/device_apps.dart';
import '../constants/keys.dart';
import '../models/interfaces/data_repository.dart';
import '../models/item.dart';
import '../utils/shared_prefs.dart';

class AppRepository implements DataRepository {
  @override
  Future<List<Item>> getAllItems() async {
    var allApps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: true,
        onlyAppsWithLaunchIntent: true);
    return _sortItems(await _toItems(allApps));
  }

  @override
  Future<List<Item>> getFavItems() async {
    var favPackages = SharedPrefs.getList(keyFavApps);
    final results = await Future.wait(
      favPackages.map((p) => DeviceApps.getApp(p, true)),
    );
    final favApps = results.whereType<ApplicationWithIcon>().toList();
    return _toItems(favApps);
  }

  @override
  void setFavItems(List<String> favPackages) {
    SharedPrefs.setList(keyFavApps, favPackages);
  }

  Future<List<Item>> _toItems(List<Application> apps) async {
    return apps
        .map((app) => Item(
              app.packageName,
              app.appName,
              app is ApplicationWithIcon
                  ? app.icon as Uint8List // ignore: unnecessary_cast
                  : null,
            ))
        .toList();
  }

  // TODO: Sort Apps as per locale and pronounciation
  List<Item> _sortItems(List<Item> apps) {
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return apps;
  }
}
```

- [ ] **Step 2: 更新 `lib/data_sources/contact_repository.dart` 中的 SharedPrefs 呼叫**

找到 `getFavItems` 和 `setFavItems`，改為靜態呼叫（移除 `await` 和 `()`）：

```dart
@override
Future<List<item.Item>> getFavItems() async {
  var favContactNumbers = SharedPrefs.getList(keyFavContacts); // 移除 await
  var favContacts = <item.Item>[];
  for (var number in favContactNumbers) {
    favContacts.add(
        _toItem(number, await ContactsService.getContactsForPhone(number)));
  }
  return favContacts;
}

@override
void setFavItems(List<String> favNumbers) {
  SharedPrefs.setList(keyFavContacts, favNumbers); // 靜態呼叫
}
```

- [ ] **Step 3: 取代 `lib/data_sources/line_repository.dart`**

```dart
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
```

- [ ] **Step 4: 確認編譯**

```bash
flutter analyze lib/data_sources/
```
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/data_sources/
git commit -m "refactor: repositories 改用靜態 SharedPrefs，AppRepository 並行載入 favApps"
```

---

### Task 3：AppProvider StreamSubscription 記憶體洩漏修復

**說明：** 原本 `dispose()` 取消的是新建立的訂閱而非原本的，導致永久洩漏。同時更新 SharedPrefs 呼叫為靜態。

**Files:**
- Modify: `lib/providers/app_provider.dart`

- [ ] **Step 1: 修改 `lib/providers/app_provider.dart`**

在 class 欄位區加入（`_methodChannel` 下方）：
```dart
late final StreamSubscription<ApplicationEvent> _appSub;
```

並在 import 區確認有：
```dart
import 'dart:async';
import '../utils/shared_prefs.dart';
```

建構子改為（原本是 `_appEvent.listen(...)`，改為存入 `_appSub`）：

```dart
AppProvider(this._repository) {
  _loadApps();
  _appSub = _appEvent.listen((event) {
    _loadApps();
  });
  _refreshTimer =
      Timer.periodic(const Duration(minutes: 15), (timer) => _loadApps());
  _checkCanSetDefaultLauncher();
  _methodChannel.setMethodCallHandler(_failedSettingDefaultLauncher);
}
```

`dispose()` 改為：

```dart
@override
void dispose() {
  _appSub.cancel();
  _refreshTimer.cancel();
  super.dispose();
}
```

`_loadApps()` 更新 SharedPrefs 呼叫：

```dart
Future<void> _loadApps() async {
  _loadAllItems();
  _loadFavItems();
  var isFirstRun = SharedPrefs.getBool(keyIsFirstRun, true);
  if (isFirstRun) {
    _restoreFavAppsFromDeprecatedList();
  }
}
```

`_restoreFavAppsFromDeprecatedList()` 更新：

```dart
Future<void> _restoreFavAppsFromDeprecatedList() async {
  var deprecatedFavAppIds = await NativeMethods().getDeprecatedPrefsList();
  if (deprecatedFavAppIds.isNotEmpty) {
    saveFavApps(deprecatedFavAppIds);
  }
  SharedPrefs.setBool(keyIsFirstRun, false);
}
```

- [ ] **Step 2: 確認編譯**

```bash
flutter analyze lib/providers/app_provider.dart
```
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/providers/app_provider.dart
git commit -m "fix: AppProvider 正確保存並取消 StreamSubscription，防止記憶體洩漏"
```

---

### Task 4：ContactProvider nullable bool 修復

**說明：** 三個 `late bool` 欄位改為 `bool?`，getter 加上 `?? false`，避免初始化前存取導致的 `LateInitializationError`。

**Files:**
- Modify: `lib/providers/contact_provider.dart`

- [ ] **Step 1: 修改欄位宣告**

將以下三個 `late bool` 改為 `bool?`：

```dart
// 改前
late bool _hasTelephoneFeature;
late bool _isContactsPermissionGranted;
late bool _isPhonePermissionGranted;

// 改後
bool? _hasTelephoneFeature;
bool? _isContactsPermissionGranted;
bool? _isPhonePermissionGranted;
```

- [ ] **Step 2: 修改 getter**

```dart
bool get isContactsPermissionGranted => _isContactsPermissionGranted ?? false;
bool get isPhonePermissionGranted => _isPhonePermissionGranted ?? false;
bool get hasTelephoneFeature => _hasTelephoneFeature ?? false;
```

- [ ] **Step 3: 修改 `callPhoneNumber()` 內的判斷**

將方法內直接存取私有欄位的判斷式改用 getter：

```dart
Future<void> callPhoneNumber(String number) async {
  if (_isTelephoneFeatureChecked) {
    if (isPhonePermissionGranted && hasTelephoneFeature) {
      NativeMethods().startPhoneCall(number);
    } else {
      NativeMethods().launchDialerApp(number);
    }
  }
}
```

- [ ] **Step 4: 確認編譯**

```bash
flutter analyze lib/providers/contact_provider.dart
```
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/providers/contact_provider.dart
git commit -m "fix: ContactProvider late bool 改為 nullable，callPhoneNumber 使用 getter"
```

---

### Task 5：LineProvider 重構

**說明：** 使用 `formatItemId()` 統一 LINE ID 解析邏輯，移除重複的 split 程式碼。

**Files:**
- Modify: `lib/providers/line_provider.dart`

- [ ] **Step 1: 取代 `lib/providers/line_provider.dart`**

```dart
import 'dart:async';
import 'dart:collection';
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
    final url = Uri.parse(
        'https://line.me/R/ti/p/~${formatItemId(combinedId)}');
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
}
```

- [ ] **Step 2: 確認編譯**

```bash
flutter analyze lib/providers/line_provider.dart
```
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/providers/line_provider.dart
git commit -m "refactor: LineProvider 使用 formatItemId 統一解析 LINE ID"
```

---

### Task 6：L10n 新增 dlgLineReload + 修正 edit_dialog

**說明：** 新增 `dlgLineReload` 翻譯字串至全部 14 個 arb 檔，重新生成 l10n，並修正 `edit_dialog.dart` 使用錯誤 key 的問題。

**Files:**
- Modify: 14 個 `lib/l10n/intl_*.arb`
- Modify: `lib/ui/pages/home_page/edit_dialog.dart`
- Auto-generated: `lib/generated/intl/messages_*.dart`、`lib/generated/l10n.dart`

- [ ] **Step 1: 在各 arb 檔的 `dlgContactsReload` 之後插入 `dlgLineReload`**

每個 arb 檔找到 `"dlgContactsReload": "..."` 這行，在其後一行插入對應翻譯：

`lib/l10n/intl_en.arb` 和 `lib/l10n/intl_en_US.arb`：
```json
"dlgLineReload": "Reload Line Contacts",
```

`lib/l10n/intl_zh_Hant.arb` 和 `lib/l10n/intl_zh_TW.arb`：
```json
"dlgLineReload": "重新載入 Line 聯絡人",
```

`lib/l10n/intl_cs.arb`：
```json
"dlgLineReload": "Znovu načíst kontakty Line",
```

`lib/l10n/intl_de.arb`：
```json
"dlgLineReload": "Line-Kontakte neu laden",
```

`lib/l10n/intl_es.arb`：
```json
"dlgLineReload": "Recargar contactos de Line",
```

`lib/l10n/intl_fr.arb`：
```json
"dlgLineReload": "Recharger les contacts Line",
```

`lib/l10n/intl_hi.arb`：
```json
"dlgLineReload": "Line संपर्क पुनः लोड करें",
```

`lib/l10n/intl_it.arb`：
```json
"dlgLineReload": "Ricarica contatti Line",
```

`lib/l10n/intl_nl.arb`：
```json
"dlgLineReload": "Line-contacten opnieuw laden",
```

`lib/l10n/intl_pl.arb`：
```json
"dlgLineReload": "Odśwież kontakty Line",
```

`lib/l10n/intl_pt.arb`：
```json
"dlgLineReload": "Recarregar contatos do Line",
```

`lib/l10n/intl_ru.arb`：
```json
"dlgLineReload": "Обновить контакты Line",
```

- [ ] **Step 2: 重新生成 l10n 程式碼**

```bash
flutter pub run intl_utils:generate
```
Expected: `lib/generated/intl/messages_*.dart` 更新，`lib/generated/l10n.dart` 新增 `String get dlgLineReload`

- [ ] **Step 3: 確認 l10n 生成成功**

```bash
grep -n "dlgLineReload" lib/generated/l10n.dart
```
Expected: 出現 `String get dlgLineReload` 定義

- [ ] **Step 4: 修正 `edit_dialog.dart` 第 81 行**

找到（在 `CupertinoActionSheetAction` 的 reload 選項中）：

```dart
              ? S.of(context).dlgContactsReload
              : S.of(context).dlgContactsReload, // Reuse string
```

改為：

```dart
              ? S.of(context).dlgContactsReload
              : S.of(context).dlgLineReload,
```

- [ ] **Step 5: 確認編譯**

```bash
flutter analyze lib/
```
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/ lib/generated/ lib/ui/pages/home_page/edit_dialog.dart
git commit -m "fix: 新增 dlgLineReload 多語系字串，修正 edit_dialog 使用錯誤的 reload key"
```

---

### Task 7：SettingsPage 清理

**說明：** 移除硬編碼的假 UI（`value: true`、`onChanged: null` 的 checkbox），改為空白頁面，不再誤導使用者。

**Files:**
- Modify: `lib/ui/pages/settings_page/settings_page.dart`

- [ ] **Step 1: 取代 `lib/ui/pages/settings_page/settings_page.dart`**

```dart
import 'package:flutter/material.dart';
import '../../common/elder_page_scaffold.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ElderPageScaffold(
      title: 'Settings',
      body: const SizedBox.shrink(),
    );
  }
}
```

- [ ] **Step 2: 確認編譯**

```bash
flutter analyze lib/ui/pages/settings_page/
```
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/ui/pages/settings_page/settings_page.dart
git commit -m "chore: 移除 SettingsPage 假 UI（硬編碼 checkbox）"
```

---

### Task 8：Lock 功能實作

**說明：** 新增 `LockProvider`，雙擊右上角 Lock 圖示切換鎖定狀態。鎖定時隱藏編輯鈕與各 Tab 底部操作按鈕，狀態持久化至 SharedPrefs。

**Files:**
- Modify: `lib/constants/keys.dart`
- Create: `lib/providers/lock_provider.dart`
- Modify: `lib/main.dart`
- Modify: `lib/ui/pages/home_page/home_page.dart`
- Modify: `lib/ui/pages/home_page/apps_tab.dart`
- Modify: `lib/ui/pages/home_page/contacts_tab.dart`
- Modify: `lib/ui/pages/home_page/line_tab.dart`
- Create: `test/providers/lock_provider_test.dart`

- [ ] **Step 1: 在 `lib/constants/keys.dart` 新增常數**

在檔案末尾加入：
```dart
const keyIsLocked = 'key_is_locked';
```

- [ ] **Step 2: 建立 Lock 測試**

建立 `test/providers/lock_provider_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elder_launcher/providers/lock_provider.dart';
import 'package:elder_launcher/utils/shared_prefs.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefs.init();
  });

  test('初始狀態預設為鎖定', () {
    final provider = LockProvider();
    expect(provider.isLocked, isTrue);
  });

  test('toggleLock 從鎖定切換到解鎖', () {
    final provider = LockProvider();
    provider.toggleLock();
    expect(provider.isLocked, isFalse);
  });

  test('toggleLock 從解鎖再切換回鎖定', () {
    final provider = LockProvider();
    provider.toggleLock(); // → 解鎖
    provider.toggleLock(); // → 鎖定
    expect(provider.isLocked, isTrue);
  });

  test('toggleLock 後狀態持久化，新建 provider 讀回相同狀態', () {
    final p1 = LockProvider();
    p1.toggleLock(); // → 解鎖並寫入 SharedPrefs
    final p2 = LockProvider(); // 讀取持久化狀態
    expect(p2.isLocked, isFalse);
  });
}
```

- [ ] **Step 3: 確認測試失敗**

```bash
flutter test test/providers/lock_provider_test.dart
```
Expected: FAIL（`LockProvider` undefined）

- [ ] **Step 4: 建立 `lib/providers/lock_provider.dart`**

```dart
import 'package:flutter/foundation.dart';
import '../constants/keys.dart';
import '../utils/shared_prefs.dart';

class LockProvider extends ChangeNotifier {
  bool _isLocked;

  LockProvider() : _isLocked = SharedPrefs.getBool(keyIsLocked, true);

  bool get isLocked => _isLocked;

  void toggleLock() {
    _isLocked = !_isLocked;
    SharedPrefs.setBool(keyIsLocked, _isLocked);
    notifyListeners();
  }
}
```

- [ ] **Step 5: 確認測試通過**

```bash
flutter test test/providers/lock_provider_test.dart
```
Expected: 4 tests PASS

- [ ] **Step 6: 更新 `lib/main.dart` — 加入 LockProvider**

在 import 區加入：
```dart
import 'providers/lock_provider.dart';
```

在 `MultiProvider` 的 `providers` 列表末尾加入：
```dart
ChangeNotifierProvider<LockProvider>(
    create: (_) => LockProvider()),
```

- [ ] **Step 7: 更新 `lib/ui/pages/home_page/home_page.dart`**

加入 import：
```dart
import '../../../providers/lock_provider.dart';
```

將 AppBar 的 `actions` 整段改為：

```dart
actions: <Widget>[
  Consumer<LockProvider>(
    builder: (context, lockProvider, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!lockProvider.isLocked)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => openEditDialog(
                  DefaultTabController.of(context).index),
            ),
          ),
        GestureDetector(
          onDoubleTap: () =>
              context.read<LockProvider>().toggleLock(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Icon(
              lockProvider.isLocked ? Icons.lock : Icons.lock_open,
            ),
          ),
        ),
      ],
    ),
  ),
],
```

- [ ] **Step 8: 更新 `lib/ui/pages/home_page/apps_tab.dart`**

加入 import：
```dart
import '../../../providers/lock_provider.dart';
```

將底部 `Align` 整段改為：

```dart
Consumer<LockProvider>(
  builder: (context, lockProvider, _) => lockProvider.isLocked
      ? const SizedBox.shrink()
      : Align(
          alignment: Alignment.bottomCenter,
          child: PrimaryButton(S.of(context).btnAllApps, openAllApps),
        ),
),
```

- [ ] **Step 9: 更新 `lib/ui/pages/home_page/contacts_tab.dart`**

加入 import：
```dart
import '../../../providers/lock_provider.dart';
```

將底部 `Align` 整段改為：

```dart
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
```

- [ ] **Step 10: 更新 `lib/ui/pages/home_page/line_tab.dart`**

加入 import：
```dart
import '../../../providers/lock_provider.dart';
```

將底部 `Align` 整段改為：

```dart
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
```

- [ ] **Step 11: 確認整體編譯**

```bash
flutter analyze lib/
```
Expected: No errors

- [ ] **Step 12: Commit**

```bash
git add lib/constants/keys.dart lib/providers/lock_provider.dart lib/main.dart \
  lib/ui/pages/home_page/ test/providers/lock_provider_test.dart
git commit -m "feat: 新增 Lock 功能，雙擊解鎖，鎖定時隱藏編輯操作，狀態持久化"
```

---

### Task 9：Package 更名

**說明：** 將 `xyz.arjunsinh.elderlauncher` 改為 `com.code_sky.customlancher`，涵蓋 Gradle、Kotlin 原始碼及 Dart 端的 channel 字串。

**Files:**
- Modify: `android/app/build.gradle`
- Modify: `android/app/src/main/kotlin/xyz/arjunsinh/elderlauncher/MainActivity.kt`（搬移後）
- Modify: `android/app/src/main/kotlin/xyz/arjunsinh/elderlauncher/Constants.kt`（搬移後）
- Modify: `lib/constants/channels.dart`

- [ ] **Step 1: 更新 `android/app/build.gradle`**

找到並修改：
```groovy
namespace "xyz.arjunsinh.elderlauncher"
// ...
applicationId "xyz.arjunsinh.elderlauncher"
```
改為：
```groovy
namespace "com.code_sky.customlancher"
// ...
applicationId "com.code_sky.customlancher"
```

- [ ] **Step 2: 建立新目錄並搬移 Kotlin 檔案**

```bash
mkdir -p android/app/src/main/kotlin/com/code_sky/customlancher
mv android/app/src/main/kotlin/xyz/arjunsinh/elderlauncher/MainActivity.kt \
   android/app/src/main/kotlin/com/code_sky/customlancher/MainActivity.kt
mv android/app/src/main/kotlin/xyz/arjunsinh/elderlauncher/Constants.kt \
   android/app/src/main/kotlin/com/code_sky/customlancher/Constants.kt
rm -rf android/app/src/main/kotlin/xyz
```

- [ ] **Step 3: 更新 MainActivity.kt 的 package 宣告**

將第 1 行：
```kotlin
package xyz.arjunsinh.elderlauncher
```
改為：
```kotlin
package com.code_sky.customlancher
```

- [ ] **Step 4: 更新 Constants.kt**

將 `package` 宣告和 channel 字串全部更新：

```kotlin
package com.code_sky.customlancher

const val CHANNEL_CONTACTS = "com.code_sky.customlancher/contacts"
const val CHANNEL_CORE = "com.code_sky.customlancher/core"
const val DEFAULT_LAUNCHER_INTENT_REQUEST_CODE = 1103
```

- [ ] **Step 5: 更新 `lib/constants/channels.dart`**

```dart
const channelContacts = 'com.code_sky.customlancher/contacts';
const channelCore = 'com.code_sky.customlancher/core';
```

- [ ] **Step 6: 確認 Android 建構**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -30
```
Expected: `BUILD SUCCESSFUL`

若出現錯誤，確認是否有其他地方仍殘留舊 package 名稱：
```bash
grep -r "xyz.arjunsinh" android/ lib/ --include="*.kt" --include="*.dart" --include="*.gradle" --include="*.xml"
```
Expected: 無輸出（全部清除）

- [ ] **Step 7: Commit**

```bash
git add android/app/build.gradle \
  android/app/src/main/kotlin/com/ \
  lib/constants/channels.dart
git commit -m "chore: Package 更名 xyz.arjunsinh.elderlauncher → com.code_sky.customlancher"
```

---

## 執行完成後驗證

```bash
# 全部單元測試
flutter test

# 靜態分析
flutter analyze lib/

# 確認舊 package 名稱完全移除
grep -r "xyz.arjunsinh" . --include="*.dart" --include="*.kt" --include="*.gradle" --include="*.xml" --exclude-dir=".git"
```
Expected: 測試全 PASS，分析無 error，grep 無輸出。
