# 動態隱藏空白 Tab — Design

**Goal:** Contacts、Line、小工具三個 home tab，在「鎖定且沒有任何項目」時，整個 tab 頁籤（頁籤標題 + 內容）從畫面上完全消失；只要「解鎖」或「有至少一個項目」，就恢復顯示。Apps 頁籤不受影響，永遠顯示。

**Why：** 目前的實作（`LockGatedEmptyPrompt`）只隱藏 tab 內容裡的「新增」提示，並沒有隱藏整個 tab 頁籤本身——鎖定時仍會看到一個空白內容的頁籤，不符合原始需求。

---

## 1. 根本限制

Flutter 的 `TabController`（`DefaultTabController` 底層也是它）長度在建立後不可變更；要讓 tab 數量隨資料/鎖定狀態動態增減，必須自行管理 `TabController` 的生命週期，不能再依賴 `main.dart` 裡外層寫死的 `DefaultTabController(length: 4, ...)`。

---

## 2. 架構調整

- `lib/ui/pages/home_page/home_page.dart`：`HomePage` 由 `StatelessWidget` 改為 `StatefulWidget`（`with SingleTickerProviderStateMixin`），自行持有並管理一個 `TabController`。
- `lib/main.dart`：移除外層的 `DefaultTabController(length: 4, child: HomePage())`，改為直接 `home: const HomePage()`；tab 數量與生命週期完全交由 `HomePage` 自己管理。
- 不涉及 provider／repository／native 層的任何改動。

---

## 3. 可見性判斷

新增私有方法 `_computeVisibleTabs(BuildContext context)`，回傳目前應顯示的 tab 清單，每個項目是一個 `(EditMode mode, Widget tabHeader, Widget tabBody)` 的小型私有 record／class（暫命名 `_HomeTab`），取代目前分散在 `openEditDialog`、`TabBar.tabs`、`TabBarView.children` 三處的重複邏輯，三處共用同一份清單，避免順序寫錯導致頁籤標題與內容對不上。

判斷規則（`context.watch` 監聽 `LockProvider`、`ContactProvider`、`LineProvider`、`WidgetProvider` 四個 provider）：

- **Apps**：永遠加入清單，不受任何條件影響。
- **Contacts／Line／小工具**：滿足 `!lockProvider.isLocked || favList.isNotEmpty` 才加入清單（鎖定且清單為空時才不加入）。
- 若對應 provider 的 `isFavListLoaded == false`（資料尚未載入完成），視同「非空」處理（即傾向顯示），避免啟動時資料還沒讀完的短暫瞬間，tab 先出現又消失的閃爍。

---

## 4. TabController 生命週期

- 每次 `build()` 呼叫 `_computeVisibleTabs()` 取得目前可見清單。
- 只比較「可見 tab 數量」是否與上一次不同（不比較是哪幾個 tab）：
  - 數量不變 → 沿用現有 `TabController`，不重建，避免使用者切到別的 tab 時被意外重置。
  - 數量改變（不論變多或變少）→ dispose 舊 controller，建立新的 `TabController(length: newLength, vsync: this)`，並將 `initialIndex` 設為 `0`（Apps），對應使用者選定的「自動跳回 Apps 頁籤」規則。
- `State` 需在 `dispose()` 中釋放目前持有的 `TabController`（比照現有專案 provider 對 `Timer`/`StreamSubscription` 的 `dispose()` 慣例）。

---

## 5. `openEditDialog` 與 AppBar 編輯鉛筆

- 目前透過 `DefaultTabController.of(context).index` 取得 tab index，再用寫死的 `0/1/2/3 → EditMode` 對照表轉換。
- 改為：從 `_computeVisibleTabs()` 算出的目前可見清單中，依照 `tabIndex` 位置直接取出該項目的 `EditMode`（`visibleTabs[tabIndex].mode`），不再需要任何寫死的 index 對照表。
- AppBar 編輯鉛筆圖示的顯示邏輯（`!lockProvider.isLocked` 時才顯示）維持不變，與本次改動無關。

---

## 6. 測試策略

`TabController` 生命週期與跨 4 個 provider 的可見性判斷屬於 UI 邏輯，且牽涉 `SingleTickerProviderStateMixin` 動畫初始化，不易用純 widget test 完整涵蓋所有情境組合。沿用專案既有慣例，以 `flutter analyze --no-fatal-infos --no-fatal-warnings` 做靜態檢查，並在實機/模擬器上手動驗證：

- [ ] Apps 頁籤不論鎖定/解鎖、其他頁籤有無資料，永遠顯示
- [ ] 聯絡人／Line／小工具個別在「鎖定且無資料」時頁籤消失（標題與內容都消失，不留空白頁籤）
- [ ] 上述三者只要「解鎖」，不論有無資料，頁籤都顯示
- [ ] 上述三者只要「有資料」，不論鎖定與否，頁籤都顯示
- [ ] 正在檢視一個「解鎖時可見、鎖定後會消失」的空白頁籤時，雙擊鎖定，畫面正確跳回 Apps 頁籤，不崩潰
- [ ] 解鎖後原本隱藏的頁籤重新出現，點擊 AppBar 編輯鉛筆能正確進入對應頁籤的新增/移除或排序頁面（驗證 `openEditDialog` 的 mode 對應沒有錯位）
- [ ] App 啟動瞬間（資料剛開始載入）不會出現「頁籤先顯示又消失」的明顯閃爍
- [ ] `flutter analyze --no-fatal-infos --no-fatal-warnings` 與 `flutter test` 皆維持通過
