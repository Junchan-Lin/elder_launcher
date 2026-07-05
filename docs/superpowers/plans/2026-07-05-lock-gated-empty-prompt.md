# 鎖定時隱藏空清單新增提示 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `ContactsTab`／`LineTab` 在最愛清單為空時，只有解鎖狀態才顯示「尚未新增任何常用項目 + 新增」提示；鎖定時完全隱藏，避免繞過鎖定保護進入編輯流程。

**Architecture:** 新增一個共用 `StatelessWidget`（`LockGatedEmptyPrompt`），內部用 `context.watch<LockProvider>()` 判斷鎖定狀態，鎖定時回傳 `SizedBox.shrink()`，解鎖時回傳跟現況相同的 `Expanded(InfoActionWidget.add(...))`。`ContactsTab`／`LineTab` 各自「清單為空」的分支改呼叫這個新 widget，取代原本直接呼叫 `InfoActionWidget.add`。`AppsTab` 不在本次範圍內。

**Tech Stack:** Flutter / Dart 3、`provider`（沿用既有的 `LockProvider`）。本專案沒有 widget test 慣例，這個變更以 `flutter analyze` + 手動驗證確認，不新增 widget test 基礎設施。

**規格文件：** `docs/superpowers/specs/2026-07-05-lock-gated-empty-prompt-design.md`

---

### Task 1: 新增 `LockGatedEmptyPrompt` 共用元件

**Files:**
- Create: `lib/ui/common/lock_gated_empty_prompt.dart`

- [ ] **Step 1: 建立 `lib/ui/common/lock_gated_empty_prompt.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/custom_functions.dart';
import '../../providers/lock_provider.dart';
import 'info_action_widget.dart';

/// Wraps [InfoActionWidget.add] so the "add favourites" prompt only shows
/// when unlocked. When locked, this renders nothing — showing an empty-list
/// prompt with a working add button while locked would let a user bypass
/// the lock and start editing favourites.
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

- [ ] **Step 2: 靜態檢查**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings lib/ui/common/lock_gated_empty_prompt.dart`
Expected: 沒有 error

- [ ] **Step 3: Commit**

```bash
git add lib/ui/common/lock_gated_empty_prompt.dart
git commit -m "feat: 新增 LockGatedEmptyPrompt，鎖定時隱藏空清單新增提示"
```

---

### Task 2: `ContactsTab` 套用 `LockGatedEmptyPrompt`

**Files:**
- Modify: `lib/ui/pages/home_page/contacts_tab.dart:104-113`

- [ ] **Step 1: 修改 import 區塊**，在 `import '../../../ui/common/loading_widget.dart';` 之後新增一行（維持字母順序）：

```dart
import '../../../ui/common/info_action_widget.dart';
import '../../../ui/common/loading_widget.dart';
import '../../../ui/common/lock_gated_empty_prompt.dart';
```

- [ ] **Step 2: 把「清單為空」分支換成 `LockGatedEmptyPrompt`**

把目前的：

```dart
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
```

改成：

```dart
                  ] else if (contactProvider.isFavListLoaded &&
                      contactProvider.favContacts.isEmpty) ...[
                    // Show Add Favourites Prompt (only when unlocked)
                    LockGatedEmptyPrompt(
                      message: S.of(context).msgNoFavourites,
                      buttonLabel: S.of(context).btnAddFavContacts,
                      buttonOnClickAction: openEditScreen,
                    ),
                  ] else if (contactProvider.isContactsPermissionChecked &&
```

其餘分支（有資料時的 `FavGridView`、電話權限提示、聯絡人權限提示、`LoadingWidget`）都不動。

- [ ] **Step 3: 靜態檢查**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings lib/ui/pages/home_page/contacts_tab.dart`
Expected: 沒有 error

- [ ] **Step 4: Commit**

```bash
git add lib/ui/pages/home_page/contacts_tab.dart
git commit -m "feat: ContactsTab 鎖定時隱藏空清單的新增提示"
```

---

### Task 3: `LineTab` 套用 `LockGatedEmptyPrompt`

**Files:**
- Modify: `lib/ui/pages/home_page/line_tab.dart:11-12`, `line_tab.dart:242-251`

- [ ] **Step 1: 修改 import 區塊**，在 `import '../../../ui/common/loading_widget.dart';` 之後新增一行（維持字母順序）：

```dart
import '../../../ui/common/info_action_widget.dart';
import '../../../ui/common/loading_widget.dart';
import '../../../ui/common/lock_gated_empty_prompt.dart';
```

- [ ] **Step 2: 把「清單為空」分支換成 `LockGatedEmptyPrompt`**

把目前的：

```dart
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
```

改成：

```dart
                  ] else if (lineProvider.isFavListLoaded &&
                      lineProvider.favLineContacts.isEmpty) ...[
                    LockGatedEmptyPrompt(
                      message: S.of(context).msgNoFavourites,
                      buttonLabel: S.of(context).btnAddFavLine,
                      buttonOnClickAction: openAddLineDialog,
                    ),
                  ] else ...[
```

`isLocked` 這個區域變數（`final isLocked = context.watch<LockProvider>().isLocked;`，用在 `itemOnLongPressAction: isLocked ? null : editItem`）維持不變，跟 `LockGatedEmptyPrompt` 內部自己的 `context.watch<LockProvider>()` 各自獨立，沒有衝突。

- [ ] **Step 3: 靜態檢查**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings lib/ui/pages/home_page/line_tab.dart`
Expected: 沒有 error

- [ ] **Step 4: Commit**

```bash
git add lib/ui/pages/home_page/line_tab.dart
git commit -m "feat: LineTab 鎖定時隱藏空清單的新增提示"
```

---

### Task 4: 全專案驗證

**Files:** 無新增變更，純驗證

- [ ] **Step 1: 全量靜態分析**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings`
Expected: 沒有新增的 error（跟目前既有的 info 級提示數量一致，不因這次改動增加）

- [ ] **Step 2: 全量測試**

Run: `flutter test`
Expected: 全部 PASS（這次改動沒有新增/修改任何測試，確認既有測試不受影響）

- [ ] **Step 3: 手動實機/模擬器驗證（自動化測試涵蓋不到的部分）**

Run: `flutter run`，手動確認：
1. 清空 LINE 最愛清單，鎖定裝置 → LINE tab 顯示空白，沒有任何提示文字或按鈕。
2. 同樣狀態解鎖 → 出現「您尚未新增任何常用項目」+「新增 Line 聯絡人」按鈕，點擊能正常開啟新增對話框。
3. 對 Contacts tab 重複步驟 1-2（用 `btnAddFavContacts`/`openEditScreen`）。
4. 確認 LINE／Contacts 有最愛項目時，不論鎖定與否，Grid 正常顯示，不受這次改動影響。
5. 確認 Apps tab 行為完全不變（不在本次範圍內）。

- [ ] **Step 4: 若手動驗證發現問題，修正後重跑 Step 1-2 再 commit；若全部通過則不需要額外 commit（此 Task 純驗證）**
