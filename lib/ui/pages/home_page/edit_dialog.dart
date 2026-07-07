import 'package:elder_launcher/providers/line_provider.dart';
import '../../../providers/widget_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/edit_mode.dart';
import '../../../constants/route_names.dart';
import '../../../generated/l10n.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/contact_provider.dart';
import '../../../ui/theme.dart';

// ignore: non_constant_identifier_names
Future EditDialog(BuildContext context, EditMode editMode) {
  String addRemoveText;
  String reorderText;

  if (editMode == EditMode.apps) {
    addRemoveText = S.of(context).dlgAppsAddRemove;
    reorderText = S.of(context).dlgAppsReorder;
  } else if (editMode == EditMode.contacts) {
    addRemoveText = S.of(context).dlgContactsAddRemove;
    reorderText = S.of(context).dlgContactsReorder;
  } else if (editMode == EditMode.line) {
    addRemoveText = S.of(context).dlgLineAddRemove;
    reorderText = S.of(context).dlgLineReorder;
  } else {
    addRemoveText = S.of(context).dlgWidgetsAddRemove;
    reorderText = S.of(context).dlgWidgetsReorder;
  }

  return showCupertinoModalPopup(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: Text(
        S.of(context).dlgEditTitle,
        style: TextStyles.dialogTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => {
            Navigator.pop(context),
            Navigator.pushNamed(context, editPageRoute, arguments: editMode)
          },
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              addRemoveText,
              style: TextStyles.dialogAction,
            ),
          ),
        ),
        CupertinoActionSheetAction(
          onPressed: () => {
            Navigator.pop(context),
            Navigator.pushNamed(context, reorderPageRoute, arguments: editMode)
          },
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              reorderText,
              style: TextStyles.dialogAction,
            ),
          ),
        ),
        CupertinoActionSheetAction(
          onPressed: () => {
            Navigator.pop(context),
            if (editMode == EditMode.apps)
              {context.read<AppProvider>().reloadLists()}
            else if (editMode == EditMode.contacts)
              {context.read<ContactProvider>().reloadLists()}
            else if (editMode == EditMode.line)
              {context.read<LineProvider>().reloadLists()}
            else
              {context.read<WidgetProvider>().reloadLists()}
          },
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              editMode == EditMode.apps
                  ? S.of(context).dlgAppsReload
                  : editMode == EditMode.contacts
                      ? S.of(context).dlgContactsReload
                      : editMode == EditMode.line
                          ? S.of(context).dlgLineReload
                          : S.of(context).dlgWidgetsReload,
              style: TextStyles.dialogAction,
            ),
          ),
        ),
      ],
      cancelButton: Padding(
        padding: const EdgeInsets.all(4.0),
        child: CupertinoActionSheetAction(
          onPressed: () => {Navigator.pop(context)},
          child: Text(S.of(context).dlgCancel),
        ),
      ),
    ),
  );
}
