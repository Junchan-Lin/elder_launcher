import 'package:elder_launcher/providers/line_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/edit_mode.dart';
import '../../../generated/l10n.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/contact_provider.dart';
import '../../../models/item.dart';
import '../../../services/edit_service.dart';
import '../../../ui/common/info_action_widget.dart';
import '../../../ui/pages/reorder_page/reorder_widget.dart';
import '../../../ui/theme.dart';
import '../../common/elder_page_scaffold.dart';

class ReorderPage extends StatelessWidget {
  const ReorderPage(this.editMode, {super.key});

  final EditMode editMode;

  @override
  Widget build(BuildContext context) {
    var favItems = <Item>[];

    if (editMode == EditMode.apps) {
      favItems = context.read<AppProvider>().favApps;
    } else if (editMode == EditMode.contacts) {
      favItems = context.read<ContactProvider>().favContacts;
    } else {
      favItems = context.read<LineProvider>().favLineContacts;
    }

    void backToHome() {
      Navigator.pop(context);
    }

    void saveFavItems(List<String> newFavItems) {
      if (editMode == EditMode.apps) {
        context.read<AppProvider>().saveFavApps(newFavItems);
      } else if (editMode == EditMode.contacts) {
        context.read<ContactProvider>().saveFavContacts(newFavItems);
      } else {
        context.read<LineProvider>().saveFavLineContacts(newFavItems);
      }
    }

    return ChangeNotifierProvider(
      create: (_) => EditService(favItems: favItems),
      child: ElderPageScaffold(
        title: editMode == EditMode.apps
            ? S.of(context).dlgAppsReorder
            : editMode == EditMode.contacts
                ? S.of(context).dlgContactsReorder
                : S.of(context).dlgLineReorder,
        body: Consumer<EditService>(builder: (_, editService, __) {
          if (editService.sortedItems.isNotEmpty) {
            return ReorderWidget(editService,
                showId: editMode == EditMode.contacts || editMode == EditMode.line);
          } else {
            return InfoActionWidget.close(
                message: S.of(context).msgNoData,
                buttonLabel: S.of(context).btnBackToHome,
                buttonOnClickAction: backToHome);
          }
        }),
        floatingActionButton: Consumer<EditService>(
          builder: (context, editService, _) {
            if (editService.isListModified) {
              return Padding(
                padding:
                    const EdgeInsets.only(bottom: Values.fabSafeBottomPadding),
                child: FloatingActionButton.extended(
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  onPressed: () {
                    saveFavItems(editService.getFavIds());
                    Navigator.pop(context);
                  },
                ),
              );
            } else {
              return const SizedBox(height: 0, width: 0);
            }
          },
        ),
      ),
    );
  }
}
