# Elder Launcher 全面優化設計

**日期：** 2026-05-30  
**版本：** v1.6.0  
**範圍：** Bug 修復 + 效能改善 + 架構/程式碼品質

---

## 背景

Elder Launcher 是一款專為長輩設計的 Android launcher，採用 Flutter 開發，Provider + Repository 架構，支援 Apps / 聯絡人 / LINE 三個分頁。本次優化涵蓋三個層面。

---

## Section 1：Bug 修復

### 1.1 `AppProvider` StreamSubscription 記憶體洩漏

**問題：** `AppProvider` 在建構子裡呼叫 `_appEvent.listen(...)` 但未保存回傳的 `StreamSubscription`。`dispose()` 中執行的是 `_appEvent.listen((event) {}).cancel()`，取消的是一個新建立的訂閱，而非原本的那個，導致原訂閱永遠不被取消。

**修正：**
- 新增 `late StreamSubscription _appSub` 欄位
- 建構子改為 `_appSub = _appEvent.listen((event) { _loadApps(); })`
- `dispose()` 改為 `_appSub.cancel()`

### 1.2 `setFavItems()` 未 await

**問題：** `DataRepository` 介面的 `setFavItems()` 宣告為 `void`，但實作內部呼叫 `SharedPrefs().setList()`（`Future<void>`）未加 `await`，形成 fire-and-forget。各 provider 的 save 方法在 `setFavItems` 未完成前就呼叫 `_loadFavItems()`，可能讀到舊資料。

**修正：**
- `DataRepository.setFavItems()` 改為 `Future<void>`
- `AppRepository`、`ContactRepository`、`LineRepository` 的實作補上 `async`/`await`
- `AppProvider.saveFavApps()`、`ContactProvider.saveFavContacts()`、`LineProvider.saveFavLineContacts()` 補上 `await`

### 1.3 LINE 重新載入文字 key 錯誤

**問題：** `edit_dialog.dart` 中 LINE 的「重新載入」選項使用 `dlgContactsReload`（原始碼有 `// Reuse string` 注解），導致多語系不正確。

**修正：**
- 在各語言的 `.arb` 檔案加入 `dlgLineReload` 字串
- `edit_dialog.dart` 改用 `S.of(context).dlgLineReload`

---

## Section 2：效能改善

### 2.1 `SharedPrefs` 快取 instance

**問題：** 每次呼叫 `SharedPrefs().getList()` / `setList()` 都執行 `SharedPreferences.getInstance()`，雖然底層有快取但仍是非同步查找。

**修正：**
- `SharedPrefs` 改為靜態快取：`static SharedPreferences? _prefs`
- 新增 `static Future<void> init()` 方法供 `main()` 在啟動時呼叫一次
- 各 getter/setter 方法改為同步存取 `_prefs!`，移除 `async`

**影響：**
- `main()` 須改為 `async`，加入 `await SharedPrefs.init()`
- `SharedPrefs` 各方法（`getList`、`setList`、`getBool`、`setBool`、`getInt`、`setInt`）改為同步回傳（移除 `Future` 包裝），呼叫端（`AppRepository`、`ContactRepository`、`LineRepository`、`AppProvider`）需同步移除對應的 `await`

### 2.2 `AppRepository.getFavItems()` 並行載入

**問題：** 目前以 for loop 依序 `await DeviceApps.getApp(packageName, true)`，N 個常用 app 需等待 N 次。

**修正：** 改用 `Future.wait`：
```dart
final results = await Future.wait(
  favPackages.map((p) => DeviceApps.getApp(p, true)),
);
```

### 2.3 移除 `_sortItems()` 多餘的 `async`

**問題：** `AppRepository._sortItems()` 宣告為 `Future<List<Item>>` 但函式本體只有同步的 `.sort()`。

**修正：** 改為 `List<Item> _sortItems(List<Item> apps)`，呼叫端移除 `await`。

---

## Section 3：架構與程式碼品質

### 3.1 LINE ID 解析邏輯統一

**問題：** `LineProvider.callLine()` 內有 `combinedId.split('|')[0]`，與 `item_utils.dart` 的 `formatItemId()` 邏輯重複。

**修正：** `callLine()` 改為呼叫 `formatItemId(combinedId)`，移除重複的 split 邏輯。

### 3.2 `ContactProvider` 的 `late bool` 改為 nullable

**問題：** `_hasTelephoneFeature`、`_isContactsPermissionGranted`、`_isPhonePermissionGranted` 宣告為 `late bool`，若初始化前被讀取或初始化方法拋出例外，會觸發 `LateInitializationError`。

**修正：**
- 三個欄位改為 `bool?`（可為 null）
- 對應 getter 回傳 `bool`，預設值為 `false`：`bool get hasTelephoneFeature => _hasTelephoneFeature ?? false;`

### 3.3 `SettingsPage` 清理

**問題：** 目前有硬編碼字串 `'Settings'`、`'Appearance Settings'`，以及一個 `value: true` / `onChanged: null` 的假 checkbox，誤導使用者以為功能存在。

**修正：** 移除假 UI，改為空的 `ListView`，等後續功能開發時再填入。

---

## 不在此次範圍內

- 新增功能（SettingsPage 實際功能實作）
- 主題切換
- `ContactRepository._toDistinctItems()` 的效能重寫（需要更廣泛的測試）
- UI 視覺調整

---

## 影響範圍

| 檔案 | 變更類型 |
|------|--------|
| `lib/utils/shared_prefs.dart` | 重構（靜態快取） |
| `lib/main.dart` | 新增 `SharedPrefs.init()` |
| `lib/models/interfaces/data_repository.dart` | 介面修改 |
| `lib/data_sources/app_repository.dart` | Bug 修復 + 效能 |
| `lib/data_sources/contact_repository.dart` | Bug 修復 |
| `lib/data_sources/line_repository.dart` | Bug 修復 |
| `lib/providers/app_provider.dart` | Bug 修復（記憶體洩漏） |
| `lib/providers/contact_provider.dart` | 架構改善 |
| `lib/providers/line_provider.dart` | Bug 修復 + 重構 |
| `lib/ui/pages/home_page/edit_dialog.dart` | Bug 修復（文字 key） |
| `lib/ui/pages/settings_page/settings_page.dart` | 清理 |
| `lib/l10n/*.arb`（各語言） | 新增 `dlgLineReload` |
