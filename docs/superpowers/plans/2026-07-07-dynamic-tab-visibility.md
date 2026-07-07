# 動態隱藏空白 Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Contacts、Line、小工具三個 home tab 在「鎖定且無任何項目」時完全從畫面消失（頁籤標題與內容都消失），解鎖或有項目時恢復顯示；Apps 頁籤永遠顯示不受影響。

**Architecture:** 把 `HomePage` 從 `StatelessWidget` 改為自行管理 `TabController` 生命週期的 `StatefulWidget`（`SingleTickerProviderStateMixin`），依據 `LockProvider`/`ContactProvider`/`LineProvider`/`WidgetProvider` 四個 provider 的狀態算出「目前可見 tab 清單」；只有可見數量改變時才 dispose 舊 controller 重建新的並跳回 index 0。`main.dart` 移除外層寫死的 `DefaultTabController(length: 4, ...)`。

**Tech Stack:** Flutter `TabController`/`SingleTickerProviderStateMixin`（SDK 內建，無新增套件）。

**Spec:** `docs/superpowers/specs/2026-07-07-dynamic-tab-visibility-design.md`

---

## 修改檔案清單

| 動作 | 路徑 |
|------|------|
| Modify | `lib/ui/pages/home_page/home_page.dart` |
| Modify | `lib/main.dart` |

---

## Task 1: HomePage 改為 StatefulWidget，實作動態 TabController

**Files:**
- Modify: `lib/ui/pages/home_page/home_page.dart`
- Modify: `lib/main.dart`

此變更牽涉 `TabController` 生命週期與跨 4 個 provider 的可見性判斷，屬於 UI 邏輯，無法用純 widget test 完整涵蓋（尤其 `SingleTickerProviderStateMixin` 動畫初始化），改以 `flutter analyze` 驗證編譯正確性，實機手動驗證行為正確性（見 Task 2）。

- [ ] **Step 1: 將 `lib/ui/pages/home_page/home_page.dart` 整份改寫**

完整檔案內容改為：

```dart
import 'package:elder_launcher/ui/pages/home_page/line_tab.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/edit_mode.dart';
import '../../../generated/l10n.dart';
import '../../../providers/contact_provider.dart';
import '../../../providers/date_time_provider.dart';
import '../../../ui/pages/home_page/apps_tab.dart';
import '../../../ui/pages/home_page/contacts_tab.dart';
import '../../../ui/pages/home_page/edit_dialog.dart';
import '../../../ui/pages/home_page/widgets_tab.dart';
import '../../../providers/line_provider.dart';
import '../../../providers/lock_provider.dart';
import '../../../providers/widget_provider.dart';
import '../../../ui/theme.dart';

class _HomeTab {
  final EditMode mode;
  final Widget header;
  final Widget body;

  const _HomeTab({required this.mode, required this.header, required this.body});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  TabController? _controllerPendingDispose;
  int _previousVisibleCount = -1;

  @override
  void dispose() {
    _controllerPendingDispose?.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Widget _tabHeader(BuildContext context, IconData icon, String label,
      AutoSizeGroup group) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 4.0, 0),
            child: Icon(icon),
          ),
          Flexible(
            child: AutoSizeText(
              label,
              group: group,
              maxLines: 1,
              style: const TextStyle(fontSize: 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _faTabHeader(BuildContext context, IconData faIcon, String label,
      AutoSizeGroup group) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 4.0, 0),
            child: FaIcon(faIcon),
          ),
          Flexible(
            child: AutoSizeText(
              label,
              group: group,
              maxLines: 1,
              style: const TextStyle(fontSize: 50),
            ),
          ),
        ],
      ),
    );
  }

  List<_HomeTab> _computeVisibleTabs(
      BuildContext context, AutoSizeGroup group) {
    final lockProvider = context.watch<LockProvider>();
    final contactProvider = context.watch<ContactProvider>();
    final lineProvider = context.watch<LineProvider>();
    final widgetProvider = context.watch<WidgetProvider>();

    final tabs = <_HomeTab>[
      _HomeTab(
        mode: EditMode.apps,
        header: _faTabHeader(
            context, FontAwesomeIcons.grip, S.of(context).Apps, group),
        body: const AppsTab(),
      ),
    ];

    final contactsVisible = !lockProvider.isLocked ||
        !contactProvider.isFavListLoaded ||
        contactProvider.favContacts.isNotEmpty;
    if (contactsVisible) {
      tabs.add(_HomeTab(
        mode: EditMode.contacts,
        header: _faTabHeader(context, FontAwesomeIcons.addressBook,
            S.of(context).Contacts, group),
        body: const ContactsTab(),
      ));
    }

    final lineVisible = !lockProvider.isLocked ||
        !lineProvider.isFavListLoaded ||
        lineProvider.favLineContacts.isNotEmpty;
    if (lineVisible) {
      tabs.add(_HomeTab(
        mode: EditMode.line,
        header: _faTabHeader(
            context, FontAwesomeIcons.line, S.of(context).Line, group),
        body: const LineTab(),
      ));
    }

    final widgetsVisible = !lockProvider.isLocked ||
        !widgetProvider.isFavListLoaded ||
        widgetProvider.favWidgets.isNotEmpty;
    if (widgetsVisible) {
      tabs.add(_HomeTab(
        mode: EditMode.widgets,
        header: _tabHeader(
            context, Icons.widgets, S.of(context).Widgets, group),
        body: const WidgetsTab(),
      ));
    }

    return tabs;
  }

  void _syncTabController(int visibleCount) {
    // 上一輪 build() 若换過 controller，此時該輪的 widget 樹比對
    // （TabBar/TabBarView 的 didUpdateWidget）已經跑完、監聽器已從舊
    // controller 解除，這裡才安全 dispose，避免在監聽器還沒解除前
    // dispose 導致 TabBar 內部存取已釋放的 controller 而崩潰。
    _controllerPendingDispose?.dispose();
    _controllerPendingDispose = null;

    if (visibleCount == _previousVisibleCount) return;
    _previousVisibleCount = visibleCount;
    _controllerPendingDispose = _tabController;
    _tabController =
        TabController(length: visibleCount, vsync: this, initialIndex: 0);
  }

  @override
  Widget build(BuildContext context) {
    var appBarTextSizeGroup = AutoSizeGroup();

    final visibleTabs = _computeVisibleTabs(context, appBarTextSizeGroup);
    _syncTabController(visibleTabs.length);
    final tabController = _tabController!;

    void openEditDialog(int tabIndex) {
      EditDialog(context, visibleTabs[tabIndex].mode);
    }

    return PopScope(
      canPop: false,
      child: ChangeNotifierProvider(
        create: (_) => DateTimeProvider(),
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
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
                          onPressed: () =>
                              openEditDialog(tabController.index),
                        ),
                      ),
                    GestureDetector(
                      onDoubleTap: () =>
                          context.read<LockProvider>().toggleLock(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Icon(
                          lockProvider.isLocked
                              ? Icons.lock
                              : Icons.lock_open,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            centerTitle: true,
            title: Consumer<DateTimeProvider>(
              builder: (_, dateTimeProvider, __) => AutoSizeText(
                dateTimeProvider.time,
                maxLines: 1,
                style: TextStyles.headerTime,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size(0, 120),
              child: Column(
                children: <Widget>[
                  Consumer<DateTimeProvider>(
                    builder: (_, dateTimeProvider, __) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AutoSizeText(
                          dateTimeProvider.date,
                          group: appBarTextSizeGroup,
                          maxLines: 1,
                          style: TextStyles.headerDate,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AutoSizeText(
                              dateTimeProvider.lunarDate,
                              group: appBarTextSizeGroup,
                              maxLines: 1,
                              style: TextStyles.headerLunar,
                            ),
                            IconButton(
                              icon: const Icon(Icons.volume_up),
                              onPressed: () => dateTimeProvider.speakDate(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: tabController,
                    tabs: visibleTabs
                        .map((tab) => Tab(child: tab.header))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          body: TabBarView(
            controller: tabController,
            children: visibleTabs.map((tab) => tab.body).toList(),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 更新 `lib/main.dart`，移除外層寫死的 `DefaultTabController`**

將：

```dart
        home: const DefaultTabController(length: 4, child: HomePage()),
```

改為：

```dart
        home: const HomePage(),
```

- [ ] **Step 3: 確認編譯正常**

Run: `flutter analyze lib/ui/pages/home_page/home_page.dart lib/main.dart`
Expected: `No issues found!`

- [ ] **Step 4: 執行所有測試**

Run: `flutter test`
Expected: All tests passed!（`home_page.dart` 本身無單元測試，此步驟純粹確認沒有破壞既有測試套件，例如 `test/widget_test.dart` 的 app smoke test）

- [ ] **Step 5: Commit**

```bash
git add lib/ui/pages/home_page/home_page.dart lib/main.dart
git commit -m "feat: HomePage 動態隱藏鎖定且無資料的 Contacts/Line/小工具頁籤"
```

---

## Task 2: 手動驗證清單（實機）

**Files:** 無（純手動測試，不寫 code）

在實機或模擬器上執行安裝後的 App，完成以下項目逐一打勾（對應 spec 第 6 節）：

- [ ] Apps 頁籤不論鎖定/解鎖、其他頁籤有無資料，永遠顯示
- [ ] 聯絡人／Line／小工具個別在「鎖定且無資料」時頁籤消失（標題與內容都消失，不留空白頁籤）
- [ ] 上述三者只要「解鎖」，不論有無資料，頁籤都顯示
- [ ] 上述三者只要「有資料」，不論鎖定與否，頁籤都顯示
- [ ] 正在檢視一個「解鎖時可見、鎖定後會消失」的空白頁籤時，雙擊鎖定，畫面正確跳回 Apps 頁籤，不崩潰
- [ ] 解鎖後原本隱藏的頁籤重新出現，點擊 AppBar 編輯鉛筆能正確進入對應頁籤的新增/移除或排序頁面（驗證 `openEditDialog` 的 mode 對應沒有錯位）
- [ ] App 啟動瞬間（資料剛開始載入）不會出現「頁籤先顯示又消失」的明顯閃爍
- [ ] `flutter analyze --no-fatal-infos --no-fatal-warnings` 與 `flutter test` 皆維持通過
