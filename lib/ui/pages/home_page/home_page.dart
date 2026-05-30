import 'package:elder_launcher/ui/pages/home_page/line_tab.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/edit_mode.dart';
import '../../../generated/l10n.dart';
import '../../../providers/date_time_provider.dart';
import '../../../ui/pages/home_page/apps_tab.dart';
import '../../../ui/pages/home_page/contacts_tab.dart';
import '../../../ui/pages/home_page/edit_dialog.dart';
import '../../../providers/lock_provider.dart';
import '../../../ui/theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    var appBarTextSizeGroup = AutoSizeGroup();

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
                          onPressed: () => openEditDialog(
                              DefaultTabController.of(context).index),
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
              preferredSize: const Size(0, 80),
              child: Column(
                children: <Widget>[
                  Consumer<DateTimeProvider>(
                    builder: (_, dateTimeProvider, __) => AutoSizeText(
                      dateTimeProvider.date,
                      group: appBarTextSizeGroup,
                      maxLines: 1,
                      style: TextStyles.headerDate,
                    ),
                  ),
                  TabBar(tabs: [
                    Tab(
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Padding(
                              padding: EdgeInsets.fromLTRB(0, 0, 4.0, 0),
                              child: FaIcon(FontAwesomeIcons.grip),
                            ),
                            Flexible(
                              child: AutoSizeText(
                                S.of(context).Apps,
                                group: appBarTextSizeGroup,
                                maxLines: 1,
                                style: const TextStyle(fontSize: 50),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Padding(
                              padding: EdgeInsets.fromLTRB(0, 0, 4.0, 0),
                              child: FaIcon(FontAwesomeIcons.addressBook),
                            ),
                            Flexible(
                              child: AutoSizeText(
                                S.of(context).Contacts,
                                group: appBarTextSizeGroup,
                                maxLines: 1,
                                style: const TextStyle(fontSize: 50),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Padding(
                              padding: EdgeInsets.fromLTRB(0, 0, 4.0, 0),
                              child: FaIcon(FontAwesomeIcons.line),
                            ),
                            Flexible(
                              child: AutoSizeText(
                                S.of(context).Line,
                                group: appBarTextSizeGroup,
                                maxLines: 1,
                                style: const TextStyle(fontSize: 50),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          body: const TabBarView(
              children: <Widget>[AppsTab(), ContactsTab(), LineTab()]),
        ),
      ),
    );
  }
}
