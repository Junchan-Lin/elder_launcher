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
