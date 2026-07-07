# App Widget Tab — Design

**Goal:** 新增第四個 home tab「Widgets」，承載真正的 Android 系統 App Widget（如時鐘、天氣、日曆等其他 App 提供的 Home Screen Widget），比照 Apps/Contacts/LINE 三個現有 tab 的「鎖定時隱藏新增/編輯」慣例（`LockGatedEmptyPrompt` + `EditMode` + `EditPage`/`ReorderPage`）。

**Why 需要原生實作：** Flutter 生態沒有能承載「第三方系統 App Widget」的套件（`home_widget` 只能反向讓自己的 App 提供 widget 給桌面用）。承載任意第三方 widget 是所有 Android launcher 的原生能力，必須用 `AppWidgetHost` + `PlatformView` 自行實作。

---

## 1. 整體架構

- **原生層（Kotlin, `MainActivity`）**：建立並持有一個固定 `HOST_ID` 的 `AppWidgetHost`；透過 `AppWidgetManager.bindAppWidgetIdIfAllowed` 綁定 widget，若系統要求授權則用 `ACTION_APPWIDGET_BIND` intent 跳系統確認框；若 widget 的 `AppWidgetProviderInfo.configure` 不為空，再用 `startActivityForResult` 跳轉該 widget 自己的設定 Activity。
- **PlatformView**：每個已新增 widget 對應一個 `AppWidgetHostView`（`AppWidgetHost.createView(...)`），以 Hybrid Composition 包成 `PlatformView`，用 `appWidgetId` 當作 view 的建立參數。
- **新 MethodChannel**：新增 `channelWidgets`（`com.code_sky.customlancher/widgets`），獨立於 `channelCore`/`channelContacts`，負責挑選/綁定/設定/刪除 widget 的原生互動。
- **Flutter 層**：新增 `WidgetRepository`（實作 `DataRepository`）、`WidgetProvider`（比照 `LineProvider`）、`WidgetsTab`、`EditMode.widgets`。

---

## 2. 資料流與模型

- **持久化**：`SharedPrefs` 新增 `keyFavWidgets`，儲存已新增 widget 的 `appWidgetId`（字串）有序清單 — 此清單同時代表顯示順序與 widget 身分。重開機後直接用這些 id 呼叫 `AppWidgetHost.createView` 重新掛回原生 view，不需要重新走綁定流程。
- **`Item` 映射**：`Item.id` = `appWidgetId.toString()`；`Item.name` = widget 的 `loadLabel()`；`Item.icon` = widget 的 `loadPreviewImage()`（無則退回 `loadIcon()`）轉成的 PNG bytes，供 `EditPage`/`ReorderPage` 清單顯示（這兩頁不需即時渲染 widget，只需圖示+名稱）。
- **`WidgetRepository implements DataRepository`**：`getAllItems()`/`getFavItems()` 都回傳同一份已存清單（比照 `LineRepository` — 沒有「所有可選清單」概念，可選清單由系統挑選器負責）；`setFavItems(ids)` 寫回 `keyFavWidgets`，供 `EditPage` 儲存移除/排序結果用。
- **`WidgetProvider extends ChangeNotifier`**：持有 `favWidgets`（`List<Item>`）、`isFavListLoaded`；`addWidget()` 呼叫原生挑選/綁定/設定流程，成功後把回傳的 `Item` 加入清單並寫回 repository；`reloadLists()` 比照其他 provider。

---

## 3. 新增流程（含設定畫面）

- `WidgetsTab` 未鎖定時（清單為空走 `LockGatedEmptyPrompt`，非空時底部固定按鈕）顯示「新增 Widget」按鈕，比照 `LineTab`/`AppsTab` 的 `PrimaryButton` 模式。
- 按下呼叫 `NativeMethods.pickAndBindWidget()`（`channelWidgets`）。原生端流程：
  1. 呼叫系統 `ACTION_APPWIDGET_PICK`（系統內建挑選器，列出所有已安裝 widget）。
  2. 使用者選擇後，若尚未取得綁定權限，跳 `ACTION_APPWIDGET_BIND` 確認框。
  3. 若該 widget 有 `configure` Activity，`startActivityForResult` 跳轉過去，等待使用者完成設定後返回。
  4. 使用者中途取消（挑選器取消、綁定被拒、設定畫面按返回）— 任一步都視為新增失敗：原生端呼叫 `AppWidgetHost.deleteAppWidgetId` 清掉暫時 id，MethodChannel 回傳 `null`；Flutter 端不新增項目、不顯示錯誤（視為使用者主動取消，非例外狀況）。
  5. 成功則回傳 `{appWidgetId, label, previewIconBytes}`，`WidgetProvider.addWidget()` 收到後加入清單並存檔。

---

## 4. 顯示、移除、排序

- **`WidgetsTab`**：`Consumer<WidgetProvider>`，`favWidgets` 非空時用可捲動的 `Column`（非 `FavGridView` 的格狀排列，因每個 widget 是原生建議尺寸的矩形而非固定小圖示）依序渲染每個 `appWidgetId` 對應的 `AndroidView`（PlatformView），高度取該 widget 的 `minHeight`；為空時走 `LockGatedEmptyPrompt`（鎖定時不顯示新增提示，跟現有 tab 一致）。不支援使用者拖拑調整尺寸，固定使用官方建議的最小單元尺寸。
- **移除/排序**：沿用 `EditMode.widgets` 走現有 `EditPage`/`ReorderPage`/`MultiSelectWidget`，`allItems = favItems = favWidgets`（比照 LINE 模式），toggle off 即代表移除。`EditDialog` 的 `CupertinoActionSheet` 加入第三種文案（`dlgWidgetsAddRemove`/`dlgWidgetsReorder`/`dlgWidgetsReload`）；但「新增」動作改成觸發第 3 節的原生新增流程（比照 `openAddLineDialog`），而非 `EditPage` 內的 fav-toggle 新增，因為可選清單來自系統挑選器，不是 Flutter 端可列舉的清單。
- **真正刪除時機**：`EditPage` 儲存後，`WidgetProvider.saveFavWidgets(newIds)` 比對出被移除的 id，呼叫原生 `AppWidgetHost.deleteAppWidgetId(id)` 釋放資源，避免遺留無主的 widget 綁定。

---

## 5. 生命週期與持久化

- **App 啟動**：`MainActivity.onCreate` 建立/取回固定 `HOST_ID` 的 `AppWidgetHost`，呼叫 `appWidgetHost.startListening()`；`onStop`/`onDestroy` 對應呼叫 `stopListening()`（標準 Android 慣例，避免無謂背景更新耗電）。
- **重開機/App 重啟**：不需重新走挑選/綁定流程，`WidgetProvider` 載入時把 `keyFavWidgets` 存的 `appWidgetId` 清單交給原生端，逐一 `createView` 掛回 PlatformView；若某個 `appWidgetId` 對應的來源 App 已被移除（`info` 為 null），視為失效項目，安靜地從清單移除並更新 `SharedPrefs`（不跳錯誤，避免鎖定畫面卡住空白區塊）。
- **鎖定模式下**：widget 本身仍正常顯示、可互動 — 鎖定只影響「新增/移除/編輯」介面，不影響瀏覽現有內容，跟 Apps/Contacts/Line 三個 tab 的既有邏輯一致。

---

## 6. 測試策略

- **可自動化**：`WidgetRepository`（SharedPrefs 讀寫）、`WidgetProvider`（fav 清單增刪、`saveFavWidgets` diff 出待刪除 id 的邏輯）— 沿用 `test/data_sources/`、`test/providers/` 模式，mock `channelWidgets` 的 MethodChannel（比照 `test/utils/set_mock_*.dart`）。
- **無法自動化**：實際 widget 挑選器跳轉、系統綁定授權框、`configure` Activity 的 `startActivityForResult` 往返、`AppWidgetHostView` 實際渲染 — 依賴真實 Android 系統元件與已安裝的第三方 widget，`flutter test` 無法覆蓋，需實機手動驗證。
- **手動驗證清單**：
  - [ ] 新增不需設定的 widget（如時鐘）
  - [ ] 新增需要設定的 widget（如天氣），含中途取消設定畫面
  - [ ] 鎖定時瀏覽 widget 正常運作，但無法新增/移除
  - [ ] `EditPage` 移除 widget 後原生資源確實釋放（不留殘留 host）
  - [ ] 重開 App 後 widget 清單與畫面正確恢復
  - [ ] 來源 App 被移除後，對應項目自動消失且不崩潰

---

## 修改/新增檔案清單

| 動作 | 路徑 |
|------|------|
| Modify | `android/app/src/main/kotlin/com/code_sky/customlancher/MainActivity.kt` |
| Modify | `lib/constants/channels.dart` |
| Modify | `lib/constants/edit_mode.dart` |
| Modify | `lib/constants/keys.dart` |
| Modify | `lib/utils/native_methods.dart` |
| Add | `lib/data_sources/widget_repository.dart` |
| Add | `lib/providers/widget_provider.dart` |
| Add | `lib/ui/pages/home_page/widgets_tab.dart` |
| Modify | `lib/ui/pages/home_page/home_page.dart`（第四個 Tab） |
| Modify | `lib/ui/pages/home_page/edit_dialog.dart`（`EditMode.widgets` 文案分支） |
| Modify | `lib/ui/pages/edit_page/edit_page.dart`（`EditMode.widgets` 分支） |
| Modify | `lib/main.dart`（註冊 `WidgetProvider`） |
| Modify | `lib/l10n/intl_*.arb`（新字串，需另開翻譯 PR，依 CONTRIBUTING 規則） |
