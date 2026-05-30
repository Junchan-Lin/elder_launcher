import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../generated/l10n.dart';
import '../../../providers/line_provider.dart';
import '../../../models/item.dart';
import '../../../providers/lock_provider.dart';
import '../../../ui/common/buttons.dart';
import '../../../ui/common/info_action_widget.dart';
import '../../../ui/common/loading_widget.dart';
import '../../../ui/pages/home_page/fav_grid_view.dart';

class LineTab extends StatelessWidget {
  const LineTab({super.key});

  @override
  Widget build(BuildContext context) {
    void openAddLineDialog() {
      final lineProvider = context.read<LineProvider>();
      showDialog(
        context: context,
        builder: (dialogContext) {
          final idController = TextEditingController();
          final nameController = TextEditingController();
          Uint8List? selectedImageBytes;

          return StatefulBuilder(
            builder: (sbContext, setState) {
              return AlertDialog(
                title: Text(S.of(sbContext).dlgAddLineTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final picked = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 200,
                          maxHeight: 200,
                          imageQuality: 80,
                        );
                        if (picked != null) {
                          final bytes = await picked.readAsBytes();
                          setState(() => selectedImageBytes = bytes);
                        }
                      },
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: selectedImageBytes != null
                            ? MemoryImage(selectedImageBytes!)
                            : null,
                        child: selectedImageBytes == null
                            ? const Icon(Icons.add_a_photo, size: 30)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                          hintText: S.of(sbContext).hintLineName),
                    ),
                    TextField(
                      controller: idController,
                      decoration:
                          InputDecoration(hintText: S.of(sbContext).hintLineId),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(S.of(sbContext).btnCancel),
                  ),
                  TextButton(
                    onPressed: () {
                      if (idController.text.isNotEmpty &&
                          nameController.text.isNotEmpty) {
                        lineProvider.addLineContactWithAvatar(
                          idController.text,
                          nameController.text,
                          selectedImageBytes,
                        );
                        Navigator.pop(dialogContext);
                      }
                    },
                    child: Text(S.of(sbContext).btnAdd),
                  ),
                ],
              );
            },
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
                  FavGridView(
                    lineProvider.favLineContacts,
                    callLine,
                    circular: true,
                    showLineBadge: true,
                  )
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
        Consumer<LockProvider>(
          builder: (context, lockProvider, _) => lockProvider.isLocked
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.bottomCenter,
                  child: PrimaryButton(
                    S.of(context).btnAddFavLine,
                    openAddLineDialog,
                  ),
                ),
        ),
      ],
    );
  }
}
