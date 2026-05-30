# Icons & Avatars Implementation Design

**Goal:** 替換 TabBar 為 font_awesome_flutter 圖示，並為聯絡人與 LINE 聯絡人加入圓框頭像顯示（LINE 頭像右下角有 LINE badge）。

**Architecture:** 兩個功能合併實作。TabBar 圖示替換只改 `home_page.dart`。圓框頭像透過 `FavItemCard` 的新參數控制，聯絡人頭像來自 `contacts_service` 既有資料，LINE 頭像由使用者從相簿選圖後以 base64 存入 SharedPrefs。

**Tech Stack:** Flutter, `font_awesome_flutter ^10.7.0`, `image_picker ^1.1.2`, `dart:convert` (base64), SharedPreferences

---

## Feature 1: TabBar 圖示

在 `home_page.dart` TabBar 的三個 `Icon(...)` 換成 `FaIcon(...)`:

| Tab | 原本 | 換成 |
|-----|------|------|
| Apps | `Icons.apps` | `FontAwesomeIcons.grip` |
| 聯絡人 | `Icons.contacts` | `FontAwesomeIcons.addressBook` |
| LINE | `Icons.message` | `FontAwesomeIcons.line` |

---

## Feature 2: 圓框頭像

### 聯絡人頭像

`contacts_service` 已回傳 `contact.avatar`（`Uint8List?`），已存入 `Item.icon`。目前 `FavItemCard` 顯示為方形 `Image`。

改動：`FavItemCard` 加 `circular: bool`。當 `circular: true` 時：
- 有頭像（`item.icon != null && isNotEmpty`）→ `CircleAvatar(backgroundImage: MemoryImage(item.icon!))`
- 無頭像 → `CircleAvatar(child: Icon(Icons.person))`

`ContactsTab` 傳 `circular: true` 給 `FavGridView`。

### LINE 頭像

LINE 頭像由使用者手動設定，存在 SharedPrefs。

**儲存格式：**
- Key: `line_avatar_<lineId>`（lineId 為 `id|name` 格式的完整字串）
- Value: base64 編碼的圖片 bytes（`image_picker` 選圖時限制 `maxWidth: 200, maxHeight: 200, imageQuality: 80`）

**SharedPrefs 新增方法：**
```dart
static String? getString(String key) => _prefs!.getString(key);
static void setString(String key, String value) => _prefs!.setString(key, value);
static void removeKey(String key) => _prefs!.remove(key);
```

**Constants 新增：**
```dart
const keyLineAvatarPrefix = 'line_avatar_';
```

**LineRepository 新增：**
- `getFavItems()` 讀取頭像：對每個 LINE 聯絡人，以 `SharedPrefs.getString(keyLineAvatarPrefix + data)` 取得 base64，decode 後填入 `Item.icon`
- `setLineAvatar(String lineId, Uint8List bytes)`：encode 為 base64，呼叫 `SharedPrefs.setString`
- `removeLineAvatar(String lineId)`：呼叫 `SharedPrefs.removeKey`

**LineProvider 新增：**
```dart
Future<void> setLineAvatar(String lineId, Uint8List bytes) async {
  _repository.setLineAvatar(lineId, bytes);
  _loadFavItems();
}
```

**Add LINE Dialog（line_tab.dart）：**
新增一個可選的頭像選擇區：
- 圓形佔位符（預設 person icon）
- 點擊呼叫 `image_picker` 從相簿選圖
- 選圖後在 Dialog 內預覽
- 按下「新增」時若有選圖，呼叫 `lineProvider.setLineAvatar(combinedId, imageBytes)` 儲存

**FavGridView 新增參數（往下傳給 FavItemCard）：**
```dart
const FavGridView(
  this.favItems,
  this.itemOnClickAction, {
  this.circular = false,
  this.showLineBadge = false,
  super.key,
});
```

**FavItemCard 新增參數：**
```dart
const FavItemCard({
  ...
  this.circular = false,
  this.showLineBadge = false,
});
```

LINE badge：在圓框頭像右下角疊加 `FaIcon(FontAwesomeIcons.line, size: 18, color: Color(0xFF06C755))` 使用 `Stack` + `Positioned`。

`LineTab` 傳 `circular: true, showLineBadge: true` 給 `FavGridView`。

---

## 不在範圍內

- 修改已存在 LINE 聯絡人的頭像（現有聯絡人顯示預設頭像，未來可透過另一個 issue 處理）
- 聯絡人自訂頭像（使用系統頭像即可）
- 圖片裁切 UI（由 image_picker 內建限制尺寸取代）
