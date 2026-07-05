# 鎖定時隱藏空清單新增提示 — 設計文件

日期：2026-07-05

## 動機

`ContactsTab`／`LineTab` 目前在「最愛清單為空」時，一律顯示「您尚未新增任何常用項目」訊息 + 「新增」按鈕，**不論裝置目前是否處於鎖定狀態**。這代表只要清單是空的，即使裝置被鎖定，使用者仍然能看到並點擊「新增」按鈕進入編輯流程（`openEditScreen`／`openAddLineDialog`），等於繞過了鎖定保護。

`AppsTab` 有同樣的模式，但本次**不修改** `AppsTab`（依需求指定範圍）。

## 範圍

**包含：**
- 新增共用 widget `LockGatedEmptyPrompt`，包裝既有的 `InfoActionWidget.add`，鎖定時回傳空白（`SizedBox.shrink()`），解鎖時才顯示原本的提示 + 新增按鈕。
- `ContactsTab`／`LineTab` 各自「favourites 清單為空」的分支，改用 `LockGatedEmptyPrompt` 取代目前直接呼叫的 `Expanded(child: InfoActionWidget.add(...))`。

**不包含：**
- `AppsTab` 維持現狀不變。
- 不影響「清單有資料」「載入中」等其他分支的顯示邏輯。
- 不新增/移除既有的頂部編輯選單（`EditDialog`）、長按編輯、選色等其他鎖定相關的既有機制，這些已經各自正確地依 `LockProvider.isLocked` 顯示/隱藏。

## 設計

### 新元件：`LockGatedEmptyPrompt`

檔案：`lib/ui/common/lock_gated_empty_prompt.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/custom_functions.dart';
import '../../providers/lock_provider.dart';
import 'info_action_widget.dart';

class LockGatedEmptyPrompt extends StatelessWidget {
  final String message;
  final String buttonLabel;
  final VoidFunction buttonOnClickAction;

  const LockGatedEmptyPrompt({
    super.key,
    required this.message,
    required this.buttonLabel,
    required this.buttonOnClickAction,
  });

  @override
  Widget build(BuildContext context) {
    if (context.watch<LockProvider>().isLocked) {
      return const SizedBox.shrink();
    }
    return Expanded(
      child: InfoActionWidget.add(
        message: message,
        buttonLabel: buttonLabel,
        buttonOnClickAction: buttonOnClickAction,
      ),
    );
  }
}
```

- 用 `context.watch<LockProvider>()` 訂閱鎖定狀態，跟專案裡其他判斷鎖定狀態的地方（`HomePage`、`LineTab`、`ContactsTab` 本身的底部新增按鈕）寫法一致；鎖定狀態透過 `LockProvider.toggleLock()` 切換時，這個 widget 會自動重建、即時顯示/隱藏。
- 鎖定時回傳 `SizedBox.shrink()`（不佔版面、零尺寸），解鎖時回傳跟現況完全相同的 `Expanded(InfoActionWidget.add(...))`，確保解鎖狀態下的外觀/行為零改變。

### 套用處

- `lib/ui/pages/home_page/contacts_tab.dart`：「`favContacts.isEmpty`」分支，把
  ```dart
  Expanded(
    child: InfoActionWidget.add(
      message: S.of(context).msgNoFavourites,
      buttonLabel: S.of(context).btnAddFavContacts,
      buttonOnClickAction: openEditScreen,
    ),
  ),
  ```
  改成
  ```dart
  LockGatedEmptyPrompt(
    message: S.of(context).msgNoFavourites,
    buttonLabel: S.of(context).btnAddFavContacts,
    buttonOnClickAction: openEditScreen,
  ),
  ```
- `lib/ui/pages/home_page/line_tab.dart`：「`favLineContacts.isEmpty`」分支，同樣把 `Expanded(child: InfoActionWidget.add(...))` 換成 `LockGatedEmptyPrompt(...)`（`buttonOnClickAction: openAddLineDialog`）。

兩處都是單純替換 widget 呼叫，其餘周圍程式碼（`if`/`else if`/`else` 結構、其他分支）不變。

## 測試計畫

- 這個 widget 純粹是 UI 顯示邏輯（依 Provider 狀態切換 `SizedBox.shrink()` 或既有元件），本專案目前沒有 widget test 慣例，跟其餘 UI 變更一致，不新增 widget test。
- 手動驗證（`flutter analyze`/`flutter test` 涵蓋不到的部分）：
  1. 清空 LINE／Contacts 最愛清單，鎖定裝置 → 確認該 tab 顯示空白，沒有任何提示或按鈕。
  2. 同樣狀態下解鎖 → 確認提示文字與「新增」按鈕正常出現，點擊能正常進入原本的新增流程。
  3. 確認有最愛項目時（不論鎖定與否）該 tab 顯示 Grid，不受影響。
