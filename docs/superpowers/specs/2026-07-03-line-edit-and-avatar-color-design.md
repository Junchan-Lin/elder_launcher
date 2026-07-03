# LINE 長按編輯、拍照頭像、無照片顏色標記 — 設計文件

日期：2026-07-03

## 動機

- LINE tab 的最愛聯絡人資料（名稱、LINE ID、頭像）是使用者自行輸入的，目前只能在「新增」時設定，無法事後修改，也只能從相簿選圖，不能拍照。
- Contacts 與 LINE 項目在沒有照片時，一律顯示灰底人形 icon，長者不易快速分辨是哪位聯絡人；希望能讓使用者手動指定一個顏色，取代千篇一律的灰底圖示。

## 範圍

**包含：**
1. LINE tab：長按最愛項目（僅在解鎖狀態）→ 彈出編輯對話框，可修改名稱、LINE ID、頭像。
2. 頭像來源新增「拍照」選項（原本只能選相簿），新增與編輯共用同一套頭像來源選單。
3. LINE 與 Contacts 項目：沒有照片時，可以指定一個顏色作為圓形頭像底色，並顯示姓名首字取代人形 icon。
4. Contacts：透過長按（僅在解鎖狀態）開啟「選擇顏色」小對話框（不可編輯姓名/電話，因為那是系統通訊錄資料）。

**不包含：**
- Apps tab 不受影響，維持原有 Edit Page（新增/移除、排序）流程。
- Contacts 的姓名、電話號碼仍為唯讀，無法透過本次功能修改。
- 顏色僅提供一組固定色票（8色），不支援自訂色碼 / 色盤選色。
- LINE 項目的「移除最愛」仍走既有頂部選單 Edit Page 流程，不在編輯對話框內提供移除功能。

## UI / 互動流程

### LINE 編輯對話框
- 觸發：`FavItemCard`（LINE tab 專用）新增 `onLongPress`，僅在 `LockProvider.isLocked == false` 時有效；鎖定狀態下長按無反應。
- 對話框樣式沿用現有「新增 LINE 聯絡人」對話框，改為可共用元件，差異：
  - 標題：新增「新增 LINE 聯絡人」／編輯「編輯 LINE 聯絡人」
  - 欄位預先帶入現有名稱、LINE ID
  - 頭像區塊預先顯示現有照片或顏色底
  - 底部按鈕：新增「新增」／編輯「儲存」
- 點擊頭像圓圈 → 彈出「頭像來源」選單（bottom sheet，大按鈕 + icon + 文字，長者友善尺寸）：
  1. 拍照
  2. 從相簿選擇
  3. 選擇顏色（進入色票網格）
  4. 取消

### Contacts 顏色小對話框
- 觸發：`FavItemCard`（Contacts tab）新增 `onLongPress`，僅在解鎖狀態有效。
- 彈出「選擇顏色」小對話框：只有 8 色色票網格 + 確定/取消，不含姓名/電話欄位。

### 無照片時的頭像呈現
- 有照片：照片優先顯示（跟現況一致，顏色設定被忽略）。
- 無照片、已設定顏色：圓形底色 = 設定的顏色，中間顯示姓名首字（白色文字）。
- 無照片、未設定顏色：維持現況（灰底 + 人形 icon）。

### 色票
- 固定 8 色：紅、橙、黃、綠、藍、靛、紫、灰（其中一色沿用既有 `elderTeal` 以貼近品牌色），定義在 `lib/ui/colors.dart` 新增的 `avatarColorPalette` 常數清單。
- 呈現為 `GridView` 大色塊（每格含勾選狀態框），不做自訂色碼輸入。

## 資料模型 / 儲存

- 顏色儲存**獨立於**頭像 bytes，各自使用獨立的 key（不與圖片資料共用 prefix，避免用字串前綴區分型別的 hack）。
- **LINE**：沿用 `keyLineAvatarPrefix + data` 儲存頭像 bytes 的模式，新增 `keyLineColorPrefix + data` 儲存顏色（存 ARGB 整數轉字串，或 `Color.value.toString()`）。設定新照片時清除對應顏色 key，反之設定顏色時清除對應照片 key（兩者互斥）。
- **Contacts**：新增 `keyContactColorPrefix + contactId`（`contactId` 即電話號碼，對應 `Item.id`），只存顏色字串，Contacts 本身沒有照片儲存機制不受影響。
- `lib/constants/keys.dart` 新增：`keyLineColorPrefix`、`keyContactColorPrefix`。

### LINE 編輯時的資料搬移（沿用先前已確認的設計）
- LINE 的 `data`（`"id|name"`）改變時（使用者改了 ID 或名稱），原本 key 在 `keyLineAvatarPrefix`/`keyLineColorPrefix` 下的舊資料（照片或顏色其中之一）需要搬到新的 `data` key，並清除舊 key。
- 最愛清單中的項目採「原地替換」（用 index 覆蓋字串），維持在 Grid 中原有的顯示順序，而非刪除後排到最後。

## 程式改動（檔案層級）

- `lib/ui/colors.dart`：新增 `avatarColorPalette`（8色 List<Color>）。
- `lib/constants/keys.dart`：新增 `keyLineColorPrefix`、`keyContactColorPrefix`。
- `android/app/src/main/AndroidManifest.xml`：新增 `<uses-permission android:name="android.permission.CAMERA" />`（`image_picker` 使用 `ImageSource.camera` 在 Android 需要此權限）。
- `lib/data_sources/line_repository.dart`：
  - 新增 `getFavItems()` 讀取時一併讀出顏色（若有），或改為回傳額外資訊供 `Item`/UI 使用（見下方「Item 模型調整」）。
  - 新增 `updateLineContact(oldData, newId, newName, {Uint8List? newAvatarBytes, Color? newColor, bool clearAvatar = false})`：處理原地替換清單、頭像/顏色的搬移或覆蓋、互斥清除。
  - 新增 `setLineColor` / `removeLineColor`，比照現有 `setLineAvatar` / `removeLineAvatar`。
- `lib/data_sources/contact_repository.dart`：新增讀取/設定聯絡人顏色的方法（`setContactColor` / `removeContactColor`），`getFavItems()`/`getAllItems()` 一併帶出顏色資訊。
- `lib/providers/line_provider.dart`：新增 `editLineContact(...)` 薄封裝，呼叫 repository 後 `_loadFavItems()`。
- `lib/providers/contact_provider.dart`：新增 `setContactColor(String contactId, Color color)` / `removeContactColor(String contactId)`，呼叫後重新載入最愛清單。
- **`Item` 模型**（`lib/models/item.dart`）：新增可選欄位 `final Color? avatarColor;`，讓 `FavItemCard` 可以直接依 `item.icon`/`item.avatarColor` 判斷畫面呈現，不用額外傳參數。
- `lib/ui/pages/home_page/fav_grid_view.dart`：`FavItemCard` 顯示邏輯調整為三態（照片 > 顏色+首字 > 灰底人形 icon），並新增 `onLongPress`（nullable，預設 null 表示不啟用，Apps tab 不受影響）。
- `lib/ui/pages/home_page/line_tab.dart`：抽出共用的 `_showLineContactDialog(context, {Item? existingItem})` 與「頭像來源選單」helper；`FavGridView` 傳入 `onLongPress`（依 `LockProvider.isLocked` 決定是否為 null）。
- `lib/ui/pages/home_page/contacts_tab.dart`：新增「選擇顏色」小對話框（共用色票網格元件），`FavGridView` 傳入對應 `onLongPress`。
- 共用色票網格元件：新增 `lib/ui/common/color_picker_grid.dart`，LINE 編輯對話框與 Contacts 顏色對話框共用。
- l10n：`intl_en.arb` / `intl_zh_TW.arb` 新增：`dlgEditLineTitle`、`btnSave`、`dlgChooseAvatarSource`、`btnTakePhoto`、`btnChooseFromGallery`、`btnChooseColor`、`dlgChooseColorTitle`、`btnConfirm`。其餘語言檔留待既有翻譯流程。

## 測試計畫

- `test/data_sources/line_repository_test.dart`：新增 `updateLineContact` 相關測試（原地替換順序、頭像/顏色搬移、互斥清除）。
- `test/data_sources/contact_repository_test.dart`：新增顏色設定/讀取/移除的測試。
- 手動驗證（無法自動化的部分）：
  - 實機測試拍照流程（camera 權限請求、拍照後裁切/回傳 bytes）。
  - 長按互動在鎖定/解鎖狀態下的行為。
  - 頭像三態顯示（照片／顏色+首字／預設灰底 icon）在淺色/深色主題下的視覺效果。

## 待確認事項（本次因使用者暫時未回覆，先採用預設判斷，待確認後可能調整）

1. 無照片時顯示「顏色底 + 姓名首字」，而非「顏色底 + 人形 icon」— 採用前者為預設。
2. LINE 顏色資料採用**獨立新 key**（`keyLineColorPrefix`），而非與頭像 bytes 共用 key 加前綴字串區分 — 採用前者為預設。
