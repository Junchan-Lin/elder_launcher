# App Widget Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增第四個 home tab「Widgets」，透過原生 `AppWidgetHost` + Flutter `PlatformView` 承載真正的 Android 系統 App Widget，複用既有的 `EditMode`/`DataRepository`/`EditPage`/`ReorderPage`/`LockGatedEmptyPrompt` 模式處理新增（原生挑選器+設定畫面）、移除、排序、鎖定時隱藏空清單提示。

**Architecture:** Kotlin 端在 `MainActivity` 建立單一 `AppWidgetHost`，新增 `channelWidgets` MethodChannel 處理「挑選→綁定→(可選)設定畫面」流程，並註冊一個 `widget_host_view` PlatformViewFactory 讓每個已存的 `appWidgetId` 能以原生 `AppWidgetHostView` 即時渲染在 Flutter tree 中。Flutter 端新增 `WidgetRepository`（實作 `DataRepository`，模式比照 `LineRepository`：`allItems`/`favItems` 都指向同一份已存清單）、`WidgetProvider`（比照 `LineProvider`）、`WidgetsTab`，並在既有的 `EditMode` 三分支處新增第四個分支。

**Tech Stack:** Flutter `AndroidView`/`PlatformView`（SDK 內建，不需新增套件）、Kotlin `android.appwidget.*`。

**Spec:** `docs/superpowers/specs/2026-07-07-app-widget-tab-design.md`

---

## 修改/新增檔案清單

| 動作 | 路徑 |
|------|------|
| Modify | `lib/constants/channels.dart` |
| Modify | `lib/constants/keys.dart` |
| Modify | `lib/constants/edit_mode.dart` |
| Add | `lib/data_sources/widget_repository.dart` |
| Add | `test/data_sources/widget_repository_test.dart` |
| Modify | `lib/utils/native_methods.dart` |
| Add | `lib/providers/widget_provider.dart` |
| Add | `test/providers/widget_provider_test.dart` |
| Modify | `android/app/src/main/kotlin/com/code_sky/customlancher/Constants.kt` |
| Modify | `android/app/src/main/kotlin/com/code_sky/customlancher/MainActivity.kt` |
| Add | `lib/ui/pages/home_page/widget_host_view.dart` |
| Add | `lib/ui/pages/home_page/widgets_tab.dart` |
| Modify | `lib/ui/pages/home_page/home_page.dart` |
| Modify | `lib/main.dart` |
| Modify | `lib/ui/pages/home_page/edit_dialog.dart` |
| Modify | `lib/ui/pages/edit_page/edit_page.dart` |
| Modify | `lib/ui/pages/reorder_page/reorder_page.dart` |
| Modify | `lib/l10n/intl_en.arb` |
| Modify | `lib/l10n/intl_zh_TW.arb` |

---

## Task 1: 常數擴充（channel、keys、EditMode）

**Files:**
- Modify: `lib/constants/channels.dart`
- Modify: `lib/constants/keys.dart`
- Modify: `lib/constants/edit_mode.dart`

無適合的單元測試（純常數新增），改以 `flutter analyze` 驗證。

- [ ] **Step 1: 在 `lib/constants/channels.dart` 新增 widgets channel**

完整檔案內容改為：

```dart
const channelContacts = 'com.code_sky.customlancher/contacts';
const channelCore = 'com.code_sky.customlancher/core';
const channelWidgets = 'com.code_sky.customlancher/widgets';
```

- [ ] **Step 2: 在 `lib/constants/keys.dart` 新增 widget 相關 key**

完整檔案內容改為：

```dart
const keyFavApps = 'key_favourites_apps';
const keyFavContacts = 'key_favourite_contacts';
const keyFavLine = 'key_favourite_line';
const keyFavWidgets = 'key_favourite_widgets';
const keyDeprecatedFavApps = 'key_favorites';
const keyIsFirstRun = 'key_is_first_run';
const keySelectedTheme = 'key_selected_theme';
const keyIsLocked = 'key_is_locked';
const keyLineAvatarPrefix = 'line_avatar_';
const keyLineColorPrefix = 'line_color_';
const keyContactColorPrefix = 'contact_color_';
const keyWidgetLabelPrefix = 'widget_label_';
const keyWidgetIconPrefix = 'widget_icon_';
const keyWidgetHeightPrefix = 'widget_height_';
```

- [ ] **Step 3: 在 `lib/constants/edit_mode.dart` 新增 `widgets` 分支**

完整檔案內容改為：

```dart
enum EditMode { apps, contacts, line, widgets }
```

- [ ] **Step 4: 確認編譯正常**

Run: `flutter analyze lib/constants/`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/constants/channels.dart lib/constants/keys.dart lib/constants/edit_mode.dart
git commit -m "feat: 新增 widgets channel/keys/EditMode 常數"
```

---

## Task 2: WidgetRepository（TDD）

**Files:**
- Create: `lib/data_sources/widget_repository.dart`
- Test: `test/data_sources/widget_repository_test.dart`

- [ ] **Step 1: 寫失敗測試**

建立 `test/data_sources/widget_repository_test.dart`：

```dart
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
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `flutter test test/data_sources/widget_repository_test.dart`
Expected: FAIL（找不到 `lib/data_sources/widget_repository.dart`）

- [ ] **Step 3: 實作 `WidgetRepository`**

建立 `lib/data_sources/widget_repository.dart`：

```dart
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
```

- [ ] **Step 4: 執行測試確認通過**

Run: `flutter test test/data_sources/widget_repository_test.dart`
Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add lib/data_sources/widget_repository.dart test/data_sources/widget_repository_test.dart
git commit -m "feat: 新增 WidgetRepository 管理已新增 widget 的持久化"
```

---

## Task 3: NativeMethods 新增 widget 相關方法

**Files:**
- Modify: `lib/utils/native_methods.dart`

無適合的單元測試（純 MethodChannel 包裝，行為由 Task 4 的 provider 測試間接覆蓋），改以 `flutter analyze` 驗證。

- [ ] **Step 1: 在 `NativeMethods` 加入 widgets channel 與方法**

完整檔案內容改為：

```dart
import 'package:flutter/services.dart';
import '../constants/channels.dart';

class NativeMethods {
  final platformCore = const MethodChannel(channelCore);
  final platformContacts = const MethodChannel(channelContacts);
  final platformWidgets = const MethodChannel(channelWidgets);

  /*
  ** Contacts & Call
  */

  Future<bool> hasTelephoneFeature() async {
    var hasTelephoneFeatureResult =
        await platformContacts.invokeMethod<bool>('hasTelephoneFeature');
    return hasTelephoneFeatureResult ?? false;
  }

  void launchContactsApp() {
    platformContacts.invokeMethod('launchContactsApp');
  }

  void launchDialerApp(String number) {
    platformContacts.invokeMethod('launchDialerWithNumber', {'number': number});
  }

  void startPhoneCall(String number) {
    platformContacts.invokeMethod('startPhoneCall', {'number': number});
  }

  /*
  ** Core
  */

  Future<bool> canSetDefaultLauncher() async {
    var canSetDefaultLauncherResult =
        await platformCore.invokeMethod<bool>('canSetDefaultLauncher');
    return canSetDefaultLauncherResult ?? false;
  }

  void setDefaultLauncher() {
    platformCore.invokeMethod('setDefaultLauncher');
  }

  Future<List<String>> getDeprecatedPrefsList() async {
    var favAppsInDeprecatedList =
        await platformCore.invokeListMethod<String>('getDeprecatedFavAppIds');
    return favAppsInDeprecatedList ?? <String>[];
  }

  /*
  ** Widgets
  */

  Future<Map<String, dynamic>?> pickAndBindWidget() async {
    final result =
        await platformWidgets.invokeMethod<Map>('pickAndBindWidget');
    return result?.cast<String, dynamic>();
  }

  void deleteWidget(int appWidgetId) {
    platformWidgets
        .invokeMethod('deleteWidget', {'appWidgetId': appWidgetId});
  }

  Future<List<int>> filterValidWidgetIds(List<int> appWidgetIds) async {
    final result = await platformWidgets.invokeListMethod<int>(
        'filterValidWidgetIds', {'appWidgetIds': appWidgetIds});
    return result ?? appWidgetIds;
  }
}
```

- [ ] **Step 2: 確認編譯正常**

Run: `flutter analyze lib/utils/native_methods.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/utils/native_methods.dart
git commit -m "feat: NativeMethods 新增 pickAndBindWidget/deleteWidget"
```

---

## Task 4: WidgetProvider（TDD）

**Files:**
- Create: `lib/providers/widget_provider.dart`
- Test: `test/providers/widget_provider_test.dart`

- [ ] **Step 1: 寫失敗測試**

建立 `test/providers/widget_provider_test.dart`：

```dart
import 'dart:typed_data';
import 'package:elder_launcher/constants/channels.dart';
import 'package:elder_launcher/constants/keys.dart';
import 'package:elder_launcher/data_sources/widget_repository.dart';
import 'package:elder_launcher/providers/widget_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elder_launcher/utils/shared_prefs.dart';

void main() {
  const widgetsChannel = MethodChannel(channelWidgets);

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefs.init();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetsChannel, null);
  });

  test('addWidget 新增成功時將 widget 加入 favWidgets', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetsChannel, (call) async {
      if (call.method == 'pickAndBindWidget') {
        return {
          'appWidgetId': 42,
          'label': 'Clock',
          'icon': Uint8List.fromList([1, 2, 3]),
          'minHeight': 120,
        };
      }
      return null;
    });

    final provider = WidgetProvider(WidgetRepository());
    await Future.delayed(Duration.zero);
    await provider.addWidget();

    expect(provider.favWidgets.length, 1);
    expect(provider.favWidgets[0].id, '42');
    expect(provider.favWidgets[0].name, 'Clock');
    expect(provider.getWidgetHeight('42'), 120);
  });

  test('addWidget 使用者取消時不新增任何項目', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetsChannel, (call) async => null);

    final provider = WidgetProvider(WidgetRepository());
    await Future.delayed(Duration.zero);
    await provider.addWidget();

    expect(provider.favWidgets, isEmpty);
  });

  test('saveFavWidgets 移除項目時呼叫原生 deleteWidget 並清除快取資料', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.$keyFavWidgets': ['1', '2'],
      'flutter.${keyWidgetLabelPrefix}1': 'Clock',
      'flutter.${keyWidgetLabelPrefix}2': 'Weather',
    });
    await SharedPrefs.init();

    final deletedIds = <int>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetsChannel, (call) async {
      if (call.method == 'deleteWidget') {
        deletedIds.add(call.arguments['appWidgetId'] as int);
      }
      return null;
    });

    final provider = WidgetProvider(WidgetRepository());
    await Future.delayed(Duration.zero);
    await provider.saveFavWidgets(['1']);

    expect(deletedIds, [2]);
    expect(provider.favWidgets.map((e) => e.id), ['1']);
    expect(SharedPrefs.getString('${keyWidgetLabelPrefix}2'), isNull);
  });

  test('載入時偵測到來源 App 已移除的 widget，自動清除該項目', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.$keyFavWidgets': ['1', '2'],
      'flutter.${keyWidgetLabelPrefix}1': 'Clock',
      'flutter.${keyWidgetLabelPrefix}2': 'Uninstalled Widget',
    });
    await SharedPrefs.init();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetsChannel, (call) async {
      if (call.method == 'filterValidWidgetIds') {
        return [1];
      }
      return null;
    });

    final provider = WidgetProvider(WidgetRepository());
    await Future.delayed(Duration.zero);

    expect(provider.favWidgets.map((e) => e.id), ['1']);
    expect(SharedPrefs.getList(keyFavWidgets), ['1']);
    expect(SharedPrefs.getString('${keyWidgetLabelPrefix}2'), isNull);
  });
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `flutter test test/providers/widget_provider_test.dart`
Expected: FAIL（找不到 `lib/providers/widget_provider.dart`）

- [ ] **Step 3: 實作 `WidgetProvider`**

建立 `lib/providers/widget_provider.dart`：

```dart
import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
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
```

- [ ] **Step 4: 執行測試確認通過**

Run: `flutter test test/providers/widget_provider_test.dart`
Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add lib/providers/widget_provider.dart test/providers/widget_provider_test.dart
git commit -m "feat: 新增 WidgetProvider 管理 widget 新增/移除/排序"
```

---

## Task 5: MainActivity 原生實作（AppWidgetHost + 挑選/綁定/設定流程）

**Files:**
- Modify: `android/app/src/main/kotlin/com/code_sky/customlancher/Constants.kt`
- Modify: `android/app/src/main/kotlin/com/code_sky/customlancher/MainActivity.kt`

原生 Activity 生命週期與系統 intent 跳轉無法用 `flutter test` 覆蓋，此 Task 用 `flutter analyze`（確保 Dart 側仍正常）+ Gradle 編譯 + Task 12 的手動驗證清單驗證。

- [ ] **Step 1: 在 `Constants.kt` 新增 widget 相關常數**

完整檔案內容改為：

```kotlin
package com.code_sky.customlancher

const val CHANNEL_CONTACTS = "com.code_sky.customlancher/contacts"
const val CHANNEL_CORE = "com.code_sky.customlancher/core"
const val CHANNEL_WIDGETS = "com.code_sky.customlancher/widgets"
const val DEFAULT_LAUNCHER_INTENT_REQUEST_CODE = 1103
const val APPWIDGET_HOST_ID = 1024
const val REQUEST_PICK_APPWIDGET = 2201
const val REQUEST_CONFIGURE_APPWIDGET = 2202
```

- [ ] **Step 2: 改寫 `MainActivity.kt`**

完整檔案內容改為：

```kotlin
package com.code_sky.customlancher

import android.app.role.RoleManager
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.ContactsContract
import android.view.View
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.ByteArrayOutputStream

class MainActivity: FlutterActivity() {

    private lateinit var appWidgetManager: AppWidgetManager
    private lateinit var appWidgetHost: AppWidgetHost
    private var pendingResult: MethodChannel.Result? = null
    private var pendingAppWidgetId: Int = -1

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        appWidgetManager = AppWidgetManager.getInstance(this)
        appWidgetHost = AppWidgetHost(this, APPWIDGET_HOST_ID)
    }

    override fun onStart() {
        super.onStart()
        appWidgetHost.startListening()
    }

    override fun onStop() {
        super.onStop()
        appWidgetHost.stopListening()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_CONTACTS).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasTelephoneFeature" -> result.success(hasTelephoneFeature())
                "launchContactsApp" -> openContactsApp()
                "launchDialerWithNumber" -> {
                    val number = call.argument<String>("number")
                    if (number != null) {
                        openDialerWithNumber(number)
                    } else {
                        result.error("ARGUMENT_ERROR", "Number is null", null)
                    }
                }
                "startPhoneCall" -> {
                    val number = call.argument<String>("number")
                    if (number != null) {
                        startPhoneCall(number)
                    } else {
                        result.error("ARGUMENT_ERROR", "Number is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_CORE).setMethodCallHandler { call, result ->
            when (call.method) {
                "canSetDefaultLauncher" -> result.success(canSetDefaultLauncher())
                "getDeprecatedFavAppIds" -> result.success(getDeprecatedFavAppIds())
                "setDefaultLauncher" -> setDefaultLauncher()
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_WIDGETS).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickAndBindWidget" -> pickAndBindWidget(result)
                "deleteWidget" -> {
                    val appWidgetId = call.argument<Int>("appWidgetId")
                    if (appWidgetId != null) {
                        appWidgetHost.deleteAppWidgetId(appWidgetId)
                        result.success(null)
                    } else {
                        result.error("ARGUMENT_ERROR", "appWidgetId is null", null)
                    }
                }
                "filterValidWidgetIds" -> {
                    val appWidgetIds = call.argument<List<Int>>("appWidgetIds") ?: emptyList()
                    val validIds = appWidgetIds.filter { appWidgetManager.getAppWidgetInfo(it) != null }
                    result.success(validIds)
                }
                else -> result.notImplemented()
            }
        }

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "widget_host_view",
            WidgetHostViewFactory(appWidgetHost, appWidgetManager)
        )
    }

    private fun hasTelephoneFeature(): Boolean {
        return packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)
    }

    private fun openContactsApp() {
        try {
            val intent = Intent(Intent.ACTION_VIEW, ContactsContract.Contacts.CONTENT_URI)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun openDialerWithNumber(number: String) {
        try {
            val intent = Intent(Intent.ACTION_DIAL)
            intent.data = Uri.parse("tel:$number")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startPhoneCall(number: String) {
        try {
            val intent = Intent(Intent.ACTION_CALL)
            intent.data = Uri.parse("tel:$number")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun canSetDefaultLauncher(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager?
            roleManager?.isRoleAvailable(RoleManager.ROLE_HOME) == true && !roleManager.isRoleHeld(RoleManager.ROLE_HOME)
        } else {
            false
        }
    }

    private fun getDeprecatedFavAppIds(): List<String> {
        val sharedPrefs = applicationContext.getSharedPreferences("key_apps", Context.MODE_PRIVATE)
        val deprecatedFavAppIds = sharedPrefs.getStringSet("key_favorites", emptySet<String>())
        return deprecatedFavAppIds?.toList() ?: emptyList()
    }

    private fun setDefaultLauncher() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager?
            if (roleManager != null && !roleManager.isRoleHeld(RoleManager.ROLE_HOME)) {
                val roleRequestIntent = roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME)
                startActivityForResult(roleRequestIntent, DEFAULT_LAUNCHER_INTENT_REQUEST_CODE)
            }
        }
    }

    private fun pickAndBindWidget(result: MethodChannel.Result) {
        pendingResult = result
        val appWidgetId = appWidgetHost.allocateAppWidgetId()
        pendingAppWidgetId = appWidgetId
        val pickIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_PICK)
        pickIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        startActivityForResult(pickIntent, REQUEST_PICK_APPWIDGET)
    }

    private fun finishAddWidget(appWidgetId: Int) {
        val info = appWidgetManager.getAppWidgetInfo(appWidgetId)
        if (info == null) {
            pendingResult?.success(null)
            pendingResult = null
            pendingAppWidgetId = -1
            return
        }
        val density = resources.displayMetrics.densityDpi
        val previewDrawable = info.loadPreviewImage(this, density) ?: info.loadIcon(this, density)
        val iconBytes = previewDrawable?.let { drawableToBytes(it) }
        pendingResult?.success(
            mapOf(
                "appWidgetId" to appWidgetId,
                "label" to info.loadLabel(packageManager),
                "icon" to iconBytes,
                "minHeight" to info.minHeight
            )
        )
        pendingResult = null
        pendingAppWidgetId = -1
    }

    private fun cancelPendingWidget() {
        if (pendingAppWidgetId != -1) {
            appWidgetHost.deleteAppWidgetId(pendingAppWidgetId)
        }
        pendingAppWidgetId = -1
        pendingResult?.success(null)
        pendingResult = null
    }

    private fun drawableToBytes(drawable: Drawable): ByteArray {
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            drawable.bitmap
        } else {
            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 1
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 1
            val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        }
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            DEFAULT_LAUNCHER_INTENT_REQUEST_CODE -> {
                if (resultCode != RESULT_OK) {
                    flutterEngine?.dartExecutor?.binaryMessenger?.let {
                        MethodChannel(it, CHANNEL_CORE).invokeMethod("setDefaultLauncherFailure", null)
                    }
                }
            }
            REQUEST_PICK_APPWIDGET -> {
                if (resultCode == RESULT_OK && data != null) {
                    val appWidgetId = data.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, pendingAppWidgetId)
                    val info = appWidgetManager.getAppWidgetInfo(appWidgetId)
                    if (info?.configure != null) {
                        pendingAppWidgetId = appWidgetId
                        val configIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_CONFIGURE)
                        configIntent.component = info.configure
                        configIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                        startActivityForResult(configIntent, REQUEST_CONFIGURE_APPWIDGET)
                    } else {
                        finishAddWidget(appWidgetId)
                    }
                } else {
                    cancelPendingWidget()
                }
            }
            REQUEST_CONFIGURE_APPWIDGET -> {
                if (resultCode == RESULT_OK) {
                    finishAddWidget(pendingAppWidgetId)
                } else {
                    cancelPendingWidget()
                }
            }
        }
    }
}

private class WidgetHostViewFactory(
    private val appWidgetHost: AppWidgetHost,
    private val appWidgetManager: AppWidgetManager
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<*, *>
        val appWidgetId = (creationParams?.get("appWidgetId") as? Int) ?: -1
        return WidgetHostPlatformView(context, appWidgetHost, appWidgetManager, appWidgetId)
    }
}

private class WidgetHostPlatformView(
    context: Context,
    appWidgetHost: AppWidgetHost,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) : PlatformView {
    private val hostView: AppWidgetHostView = appWidgetHost.createView(
        context,
        appWidgetId,
        appWidgetManager.getAppWidgetInfo(appWidgetId)
    )

    override fun getView(): View = hostView

    override fun dispose() {}
}
```

- [ ] **Step 3: 確認 Gradle 編譯正常**

Run: `flutter build apk --debug`
Expected: 編譯成功，無 Kotlin 編譯錯誤（若你的環境沒有 Android SDK/裝置，至少執行 `cd android && ./gradlew compileDebugKotlin` 確認 Kotlin 部分編譯通過）。

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/code_sky/customlancher/Constants.kt android/app/src/main/kotlin/com/code_sky/customlancher/MainActivity.kt
git commit -m "feat: MainActivity 新增 AppWidgetHost 挑選/綁定/設定/PlatformView 支援"
```

---

## Task 6: WidgetHostView（Flutter PlatformView 包裝）

**Files:**
- Create: `lib/ui/pages/home_page/widget_host_view.dart`

無適合的單元測試（`AndroidView` 需要真實 Android 環境渲染），改以 `flutter analyze` 驗證，實際渲染在 Task 12 手動驗證。

- [ ] **Step 1: 建立 `WidgetHostView`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _widgetHostViewType = 'widget_host_view';

class WidgetHostView extends StatelessWidget {
  final int appWidgetId;
  final double height;

  const WidgetHostView(
      {required this.appWidgetId, required this.height, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: AndroidView(
        viewType: _widgetHostViewType,
        creationParams: {'appWidgetId': appWidgetId},
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}
```

- [ ] **Step 2: 確認編譯正常**

Run: `flutter analyze lib/ui/pages/home_page/widget_host_view.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/ui/pages/home_page/widget_host_view.dart
git commit -m "feat: 新增 WidgetHostView 包裝 AndroidView 承載 AppWidgetHostView"
```

---

## Task 7: WidgetsTab UI

**Files:**
- Create: `lib/ui/pages/home_page/widgets_tab.dart`

- [ ] **Step 1: 建立 `WidgetsTab`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../generated/l10n.dart';
import '../../../providers/lock_provider.dart';
import '../../../providers/widget_provider.dart';
import '../../../ui/common/buttons.dart';
import '../../../ui/common/loading_widget.dart';
import '../../../ui/common/lock_gated_empty_prompt.dart';
import 'widget_host_view.dart';

class WidgetsTab extends StatelessWidget {
  const WidgetsTab({super.key});

  @override
  Widget build(BuildContext context) {
    void addWidget() => context.read<WidgetProvider>().addWidget();

    return Column(
      children: <Widget>[
        Flexible(
          child: Consumer<WidgetProvider>(
            builder: (_, widgetProvider, __) {
              return Column(
                children: <Widget>[
                  if (widgetProvider.isFavListLoaded &&
                      widgetProvider.favWidgets.isNotEmpty) ...[
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        children: widgetProvider.favWidgets
                            .map((item) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: WidgetHostView(
                                    appWidgetId: int.parse(item.id),
                                    height: widgetProvider
                                        .getWidgetHeight(item.id)
                                        .toDouble(),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ] else if (widgetProvider.isFavListLoaded &&
                      widgetProvider.favWidgets.isEmpty) ...[
                    LockGatedEmptyPrompt(
                      message: S.of(context).msgNoWidgets,
                      buttonLabel: S.of(context).btnAddWidget,
                      buttonOnClickAction: addWidget,
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
                    S.of(context).btnAddWidget,
                    addWidget,
                  ),
                ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 確認編譯正常（會因缺少 l10n 字串而失敗，屬預期，Task 10 補上後解決）**

Run: `flutter analyze lib/ui/pages/home_page/widgets_tab.dart`
Expected: 目前會出現 `msgNoWidgets`/`btnAddWidget` 未定義的錯誤（`S.of(context)` 沒有這兩個 getter），先繼續下一步，Task 10 加入 l10n 字串並重新產生後才會通過。

- [ ] **Step 3: Commit**

```bash
git add lib/ui/pages/home_page/widgets_tab.dart
git commit -m "feat: 新增 WidgetsTab 顯示已新增的 widget 清單"
```

---

## Task 8: home_page.dart + main.dart 串接第四個 tab

**Files:**
- Modify: `lib/ui/pages/home_page/home_page.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: `home_page.dart` 加入 import 與 `openEditDialog` 分支**

在檔案開頭的 import 區塊，`import '../../../ui/pages/home_page/edit_dialog.dart';` 之後加入：

```dart
import '../../../ui/pages/home_page/widgets_tab.dart';
```

將 `openEditDialog` 函式：

```dart
    void openEditDialog(int tabIndex) {
      EditMode editMode;

      if (tabIndex == 0) {
        editMode = EditMode.apps;
      } else if (tabIndex == 1) {
        editMode = EditMode.contacts;
      } else {
        editMode = EditMode.line;
      }

      EditDialog(context, editMode);
    }
```

改為：

```dart
    void openEditDialog(int tabIndex) {
      EditMode editMode;

      if (tabIndex == 0) {
        editMode = EditMode.apps;
      } else if (tabIndex == 1) {
        editMode = EditMode.contacts;
      } else if (tabIndex == 2) {
        editMode = EditMode.line;
      } else {
        editMode = EditMode.widgets;
      }

      EditDialog(context, editMode);
    }
```

- [ ] **Step 2: 在 `TabBar` 的 `tabs` 清單新增第四個 `Tab`**

找到 LINE 的 `Tab` 區塊（第三個 `Tab(...)`）結尾的 `),`，在其後、`]),`（`TabBar(tabs: [...])` 結尾）之前加入：

```dart
                    Tab(
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Padding(
                              padding: EdgeInsets.fromLTRB(0, 0, 4.0, 0),
                              child: Icon(Icons.widgets),
                            ),
                            Flexible(
                              child: AutoSizeText(
                                S.of(context).Widgets,
                                group: appBarTextSizeGroup,
                                maxLines: 1,
                                style: const TextStyle(fontSize: 50),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
```

- [ ] **Step 3: 在 `TabBarView` 加入 `WidgetsTab`**

將：

```dart
          body: const TabBarView(
              children: <Widget>[AppsTab(), ContactsTab(), LineTab()]),
```

改為：

```dart
          body: const TabBarView(children: <Widget>[
            AppsTab(),
            ContactsTab(),
            LineTab(),
            WidgetsTab()
          ]),
```

- [ ] **Step 4: 更新 `lib/main.dart`：`DefaultTabController.length` 改為 4，並註冊 `WidgetProvider`**

在 import 區塊，`import 'providers/lock_provider.dart';` 之前加入：

```dart
import 'data_sources/widget_repository.dart';
import 'providers/widget_provider.dart';
```

將 `MultiProvider` 的 `providers` 清單：

```dart
      providers: [
        ChangeNotifierProvider<AppProvider>(
            create: (_) => AppProvider(AppRepository())),
        ChangeNotifierProvider<ContactProvider>(
            create: (_) => ContactProvider(ContactRepository())),
        ChangeNotifierProvider<LineProvider>(
            create: (_) => LineProvider(LineRepository())),
        ChangeNotifierProvider<LockProvider>(
            create: (_) => LockProvider()),
      ],
```

改為：

```dart
      providers: [
        ChangeNotifierProvider<AppProvider>(
            create: (_) => AppProvider(AppRepository())),
        ChangeNotifierProvider<ContactProvider>(
            create: (_) => ContactProvider(ContactRepository())),
        ChangeNotifierProvider<LineProvider>(
            create: (_) => LineProvider(LineRepository())),
        ChangeNotifierProvider<WidgetProvider>(
            create: (_) => WidgetProvider(WidgetRepository())),
        ChangeNotifierProvider<LockProvider>(
            create: (_) => LockProvider()),
      ],
```

並將：

```dart
        home: const DefaultTabController(length: 3, child: HomePage()),
```

改為：

```dart
        home: const DefaultTabController(length: 4, child: HomePage()),
```

- [ ] **Step 5: 確認編譯（預期仍因缺少 l10n 字串而失敗，Task 10 解決）**

Run: `flutter analyze lib/ui/pages/home_page/home_page.dart lib/main.dart`
Expected: 出現 `Widgets` getter 未定義的錯誤，屬預期，先繼續。

- [ ] **Step 6: Commit**

```bash
git add lib/ui/pages/home_page/home_page.dart lib/main.dart
git commit -m "feat: home_page/main 加入第四個 Widgets tab"
```

---

## Task 9: EditMode.widgets 串接既有編輯流程

**Files:**
- Modify: `lib/ui/pages/home_page/edit_dialog.dart`
- Modify: `lib/ui/pages/edit_page/edit_page.dart`
- Modify: `lib/ui/pages/reorder_page/reorder_page.dart`

- [ ] **Step 1: `edit_dialog.dart` 加入 import 與文案/動作分支**

在 import 區塊，`import '../../../providers/line_provider.dart';` 之後加入：

```dart
import '../../../providers/widget_provider.dart';
```

將文案判斷：

```dart
  if (editMode == EditMode.apps) {
    addRemoveText = S.of(context).dlgAppsAddRemove;
    reorderText = S.of(context).dlgAppsReorder;
  } else if (editMode == EditMode.contacts) {
    addRemoveText = S.of(context).dlgContactsAddRemove;
    reorderText = S.of(context).dlgContactsReorder;
  } else {
    addRemoveText = S.of(context).dlgLineAddRemove;
    reorderText = S.of(context).dlgLineReorder;
  }
```

改為：

```dart
  if (editMode == EditMode.apps) {
    addRemoveText = S.of(context).dlgAppsAddRemove;
    reorderText = S.of(context).dlgAppsReorder;
  } else if (editMode == EditMode.contacts) {
    addRemoveText = S.of(context).dlgContactsAddRemove;
    reorderText = S.of(context).dlgContactsReorder;
  } else if (editMode == EditMode.line) {
    addRemoveText = S.of(context).dlgLineAddRemove;
    reorderText = S.of(context).dlgLineReorder;
  } else {
    addRemoveText = S.of(context).dlgWidgetsAddRemove;
    reorderText = S.of(context).dlgWidgetsReorder;
  }
```

將重新整理動作：

```dart
        CupertinoActionSheetAction(
          onPressed: () => {
            Navigator.pop(context),
            if (editMode == EditMode.apps)
              {context.read<AppProvider>().reloadLists()}
            else if (editMode == EditMode.contacts)
              {context.read<ContactProvider>().reloadLists()}
            else
              {context.read<LineProvider>().reloadLists()}
          },
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              editMode == EditMode.apps
                  ? S.of(context).dlgAppsReload
                  : editMode == EditMode.contacts
                      ? S.of(context).dlgContactsReload
                      : S.of(context).dlgLineReload,
              style: TextStyles.dialogAction,
            ),
          ),
        ),
```

改為：

```dart
        CupertinoActionSheetAction(
          onPressed: () => {
            Navigator.pop(context),
            if (editMode == EditMode.apps)
              {context.read<AppProvider>().reloadLists()}
            else if (editMode == EditMode.contacts)
              {context.read<ContactProvider>().reloadLists()}
            else if (editMode == EditMode.line)
              {context.read<LineProvider>().reloadLists()}
            else
              {context.read<WidgetProvider>().reloadLists()}
          },
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              editMode == EditMode.apps
                  ? S.of(context).dlgAppsReload
                  : editMode == EditMode.contacts
                      ? S.of(context).dlgContactsReload
                      : editMode == EditMode.line
                          ? S.of(context).dlgLineReload
                          : S.of(context).dlgWidgetsReload,
              style: TextStyles.dialogAction,
            ),
          ),
        ),
```

- [ ] **Step 2: `edit_page.dart` 加入 import 與 `allItems`/`favItems`/儲存/標題分支**

在 import 區塊，`import 'package:elder_launcher/providers/line_provider.dart';` 之後加入：

```dart
import 'package:elder_launcher/providers/widget_provider.dart';
```

將：

```dart
    if (editMode == EditMode.apps) {
      allItems = context.read<AppProvider>().allApps;
      favItems = context.read<AppProvider>().favApps;
    } else if (editMode == EditMode.contacts) {
      allItems = context.read<ContactProvider>().allContacts;
      favItems = context.read<ContactProvider>().favContacts;
    } else {
      allItems = context.read<LineProvider>().favLineContacts;
      favItems = context.read<LineProvider>().favLineContacts;
    }
```

改為：

```dart
    if (editMode == EditMode.apps) {
      allItems = context.read<AppProvider>().allApps;
      favItems = context.read<AppProvider>().favApps;
    } else if (editMode == EditMode.contacts) {
      allItems = context.read<ContactProvider>().allContacts;
      favItems = context.read<ContactProvider>().favContacts;
    } else if (editMode == EditMode.line) {
      allItems = context.read<LineProvider>().favLineContacts;
      favItems = context.read<LineProvider>().favLineContacts;
    } else {
      allItems = context.read<WidgetProvider>().favWidgets;
      favItems = context.read<WidgetProvider>().favWidgets;
    }
```

將：

```dart
    void saveFavItems(List<String> newFavItems) {
      if (editMode == EditMode.apps) {
        context.read<AppProvider>().saveFavApps(newFavItems);
      } else if (editMode == EditMode.contacts) {
        context.read<ContactProvider>().saveFavContacts(newFavItems);
      } else {
        context.read<LineProvider>().saveFavLineContacts(newFavItems);
      }
    }
```

改為：

```dart
    void saveFavItems(List<String> newFavItems) {
      if (editMode == EditMode.apps) {
        context.read<AppProvider>().saveFavApps(newFavItems);
      } else if (editMode == EditMode.contacts) {
        context.read<ContactProvider>().saveFavContacts(newFavItems);
      } else if (editMode == EditMode.line) {
        context.read<LineProvider>().saveFavLineContacts(newFavItems);
      } else {
        context.read<WidgetProvider>().saveFavWidgets(newFavItems);
      }
    }
```

將標題：

```dart
        title: editMode == EditMode.apps
            ? S.of(context).dlgAppsAddRemove
            : editMode == EditMode.contacts
                ? S.of(context).dlgContactsAddRemove
                : S.of(context).dlgLineAddRemove,
```

改為：

```dart
        title: editMode == EditMode.apps
            ? S.of(context).dlgAppsAddRemove
            : editMode == EditMode.contacts
                ? S.of(context).dlgContactsAddRemove
                : editMode == EditMode.line
                    ? S.of(context).dlgLineAddRemove
                    : S.of(context).dlgWidgetsAddRemove,
```

- [ ] **Step 3: `reorder_page.dart` 加入 import 與 `favItems`/儲存/標題分支**

在 import 區塊，`import '../../../providers/contact_provider.dart';` 之後加入：

```dart
import '../../../providers/widget_provider.dart';
```

將：

```dart
    if (editMode == EditMode.apps) {
      favItems = context.read<AppProvider>().favApps;
    } else if (editMode == EditMode.contacts) {
      favItems = context.read<ContactProvider>().favContacts;
    } else {
      favItems = context.read<LineProvider>().favLineContacts;
    }
```

改為：

```dart
    if (editMode == EditMode.apps) {
      favItems = context.read<AppProvider>().favApps;
    } else if (editMode == EditMode.contacts) {
      favItems = context.read<ContactProvider>().favContacts;
    } else if (editMode == EditMode.line) {
      favItems = context.read<LineProvider>().favLineContacts;
    } else {
      favItems = context.read<WidgetProvider>().favWidgets;
    }
```

將：

```dart
    void saveFavItems(List<String> newFavItems) {
      if (editMode == EditMode.apps) {
        context.read<AppProvider>().saveFavApps(newFavItems);
      } else if (editMode == EditMode.contacts) {
        context.read<ContactProvider>().saveFavContacts(newFavItems);
      } else {
        context.read<LineProvider>().saveFavLineContacts(newFavItems);
      }
    }
```

改為：

```dart
    void saveFavItems(List<String> newFavItems) {
      if (editMode == EditMode.apps) {
        context.read<AppProvider>().saveFavApps(newFavItems);
      } else if (editMode == EditMode.contacts) {
        context.read<ContactProvider>().saveFavContacts(newFavItems);
      } else if (editMode == EditMode.line) {
        context.read<LineProvider>().saveFavLineContacts(newFavItems);
      } else {
        context.read<WidgetProvider>().saveFavWidgets(newFavItems);
      }
    }
```

將標題：

```dart
        title: editMode == EditMode.apps
            ? S.of(context).dlgAppsReorder
            : editMode == EditMode.contacts
                ? S.of(context).dlgContactsReorder
                : S.of(context).dlgLineReorder,
```

改為：

```dart
        title: editMode == EditMode.apps
            ? S.of(context).dlgAppsReorder
            : editMode == EditMode.contacts
                ? S.of(context).dlgContactsReorder
                : editMode == EditMode.line
                    ? S.of(context).dlgLineReorder
                    : S.of(context).dlgWidgetsReorder,
```

- [ ] **Step 4: 確認編譯（預期仍因缺少 l10n 字串而失敗，Task 10 解決）**

Run: `flutter analyze lib/ui/pages/home_page/edit_dialog.dart lib/ui/pages/edit_page/edit_page.dart lib/ui/pages/reorder_page/reorder_page.dart`
Expected: 出現 `dlgWidgetsAddRemove`/`dlgWidgetsReorder`/`dlgWidgetsReload` 未定義的錯誤，屬預期，先繼續。

- [ ] **Step 5: Commit**

```bash
git add lib/ui/pages/home_page/edit_dialog.dart lib/ui/pages/edit_page/edit_page.dart lib/ui/pages/reorder_page/reorder_page.dart
git commit -m "feat: EditDialog/EditPage/ReorderPage 支援 EditMode.widgets"
```

---

## Task 10: l10n 字串新增

**Files:**
- Modify: `lib/l10n/intl_en.arb`
- Modify: `lib/l10n/intl_zh_TW.arb`

依 `docs/CONTRIBUTING.md` 規則，翻譯異動需獨立 PR；此處只新增英文（基準語言，`intl_utils` 產生程式碼所需）與繁體中文（`intl_zh_TW.arb`，本專案主要維護的正體中文語系檔）兩個語系，其餘語系待後續翻譯 PR 補上。

- [ ] **Step 1: 在 `lib/l10n/intl_en.arb` 新增新字串**

將檔案最後一行 `"msgAvatarPickFailed": "Couldn't get the photo. Please try again."` 改為（加上逗號並接續新 key，維持結尾 `}` 不變）：

```json
    "msgAvatarPickFailed": "Couldn't get the photo. Please try again.",
    "Widgets": "Widgets",
    "btnAddWidget": "Add Widget",
    "msgNoWidgets": "You haven't added any widgets",
    "dlgWidgetsAddRemove": "Add/Remove Widgets",
    "dlgWidgetsReorder": "Reorder Widgets",
    "dlgWidgetsReload": "Reload Widgets"
```

- [ ] **Step 2: 在 `lib/l10n/intl_zh_TW.arb` 新增對應翻譯**

將檔案最後一行 `"msgAvatarPickFailed": "無法取得照片，請再試一次。"` 改為：

```json
    "msgAvatarPickFailed": "無法取得照片，請再試一次。",
    "Widgets": "小工具",
    "btnAddWidget": "新增小工具",
    "msgNoWidgets": "你還沒有新增任何小工具",
    "dlgWidgetsAddRemove": "新增/移除小工具",
    "dlgWidgetsReorder": "重新排序小工具",
    "dlgWidgetsReload": "重新載入小工具"
```

- [ ] **Step 3: 重新產生 l10n 程式碼**

Run: `flutter pub run intl_utils:generate`
Expected: 指令成功結束，`lib/generated/l10n.dart`（及 intl_*.dart）出現 `Widgets`/`btnAddWidget`/`msgNoWidgets`/`dlgWidgetsAddRemove`/`dlgWidgetsReorder`/`dlgWidgetsReload` 對應的 getter。

- [ ] **Step 4: 全專案編譯檢查**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings`
Expected: 無錯誤（Task 7～9 中預期的缺字串錯誤此時應全部消失）。

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/intl_en.arb lib/l10n/intl_zh_TW.arb lib/generated/
git commit -m "feat: 新增 Widgets tab 相關 l10n 字串（英文/繁中）"
```

---

## Task 11: 全面測試驗證

**Files:** 無新增/修改（純驗證）

- [ ] **Step 1: 執行完整測試套件**

Run: `flutter test`
Expected: All tests passed!（包含 Task 2、Task 4 新增的測試）

- [ ] **Step 2: 執行完整 lint 檢查**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings`
Expected: 無錯誤或警告（符合 CI 規則）

- [ ] **Step 3: 若上兩步皆通過，無需額外 commit（Task 10 已是最後一次 commit）；若有修正，個別 commit 說明修正內容**

---

## Task 12: 手動驗證清單（實機）

**Files:** 無（純手動測試，不寫 code）

在實機或模擬器上執行 `flutter run`，完成以下項目逐一打勾：

- [ ] 未鎖定時，Widgets tab 清單為空會顯示「新增小工具」提示；鎖定後提示消失（`LockGatedEmptyPrompt` 生效）
- [ ] 新增不需設定畫面的 widget（如系統時鐘）：挑選後直接出現在清單中並正常顯示時間
- [ ] 新增需要設定畫面的 widget（如天氣、日曆類需選城市/帳戶）：能正確跳轉設定畫面，完成後顯示；設定畫面按返回取消則不新增
- [ ] 鎖定時 widget 本身仍可瀏覽/互動，但看不到「新增小工具」按鈕，且 AppBar 編輯鉛筆圖示消失
- [ ] 進入編輯（AppBar 鉛筆 → 新增/移除）取消勾選某個 widget 並儲存後，該 widget 從清單消失，且原生沒有殘留（可用 `adb shell dumpsys appwidget` 或裝置的「小工具」設定頁確認沒有孤兒綁定）
- [ ] 進入編輯（AppBar 鉛筆 → 排序）拖拉調整順序並儲存後，Widgets tab 顯示順序正確更新
- [ ] 完全關閉 App 後重新開啟，先前新增的 widget 清單與畫面正確恢復，不需要重新挑選/綁定
- [ ] 解除安裝提供某個已新增 widget 的來源 App 後重開 App，該項目自動從清單消失，App 不崩潰
- [ ] `flutter analyze --no-fatal-infos --no-fatal-warnings` 與 `flutter test` 皆維持通過（呼應 Task 11）
