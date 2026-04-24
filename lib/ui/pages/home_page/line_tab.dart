import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../generated/l10n.dart';
import '../../../providers/line_provider.dart';
import '../../../models/item.dart';
import '../../../ui/common/buttons.dart';
import '../../../ui/common/info_action_widget.dart';
import '../../../ui/common/loading_widget.dart';
import '../../../ui/pages/home_page/fav_grid_view.dart';

class LineTab extends StatelessWidget {
  const LineTab({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    void openAddLineDialog() {
      showDialog(
        context: context,
        builder: (context) {
          final idController = TextEditingController();
          final nameController = TextEditingController();
          return AlertDialog(
            title: Text(S.of(context).dlgAddLineTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(hintText: S.of(context).hintLineName),
                ),
                TextField(
                  controller: idController,
                  decoration: InputDecoration(hintText: S.of(context).hintLineId),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).btnCancel),
              ),
              TextButton(
                onPressed: () {
                  if (idController.text.isNotEmpty && nameController.text.isNotEmpty) {
                    context.read<LineProvider>().addLineContact(
                          idController.text,
                          nameController.text,
                        );
                    Navigator.pop(context);
                  }
                },
                child: Text(S.of(context).btnAdd),
              ),
            ],
          );
        },
      );
    }

    void callLine(Item contact) {
      context.read<LineProvider>().callLine(contact.id);
    }

    return Column(
      children: <Widget>[
        Flexible(
          child: Consumer<LineProvider>(
            builder: (_, lineProvider, __) => Column(
              children: <Widget>[
                if (lineProvider.isFavListLoaded &&
                    lineProvider.favLineContacts.isNotEmpty) ...[
                  FavGridView(lineProvider.favLineContacts, callLine)
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
                  const LoadingWidget(),
                ],
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: PrimaryButton(
            S.of(context).btnAddFavLine,
            openAddLineDialog,
          ),
        ),
      ],
    );
  }
}
