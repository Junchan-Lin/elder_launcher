import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../generated/l10n.dart';
import '../../../providers/line_provider.dart';
import '../../../models/item.dart';
import '../../../providers/lock_provider.dart';
import '../../../ui/common/buttons.dart';
import '../../../ui/common/color_picker_grid.dart';
import '../../../ui/common/loading_widget.dart';
import '../../../ui/common/lock_gated_empty_prompt.dart';
import '../../../ui/pages/home_page/fav_grid_view.dart';
import '../../../utils/item_utils.dart';

typedef _AvatarPickResult = ({Uint8List? bytes, Color? color});

class LineTab extends StatelessWidget {
  const LineTab({super.key});

  Future<_AvatarPickResult?> _pickAvatarSource(BuildContext context) {
    return showModalBottomSheet<_AvatarPickResult>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, size: 32),
              title: Text(S.of(sheetContext).btnTakePhoto),
              onTap: () async {
                final XFile? picked;
                try {
                  picked = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                    maxWidth: 200,
                    maxHeight: 200,
                    imageQuality: 80,
                  );
                } catch (_) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      SnackBar(
                          content:
                              Text(S.of(sheetContext).msgAvatarPickFailed)),
                    );
                  }
                  return;
                }
                final bytes = picked != null ? await picked.readAsBytes() : null;
                final _AvatarPickResult? result =
                    bytes != null ? (bytes: bytes, color: null) : null;
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext, result);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, size: 32),
              title: Text(S.of(sheetContext).btnChooseFromGallery),
              onTap: () async {
                final XFile? picked;
                try {
                  picked = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 200,
                    maxHeight: 200,
                    imageQuality: 80,
                  );
                } catch (_) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      SnackBar(
                          content:
                              Text(S.of(sheetContext).msgAvatarPickFailed)),
                    );
                  }
                  return;
                }
                final bytes = picked != null ? await picked.readAsBytes() : null;
                final _AvatarPickResult? result =
                    bytes != null ? (bytes: bytes, color: null) : null;
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext, result);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette, size: 32),
              title: Text(S.of(sheetContext).btnChooseColor),
              onTap: () async {
                final color = await showDialog<Color>(
                  context: sheetContext,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(S.of(dialogContext).dlgChooseColorTitle),
                    content: ColorPickerGrid(
                      onColorSelected: (color) =>
                          Navigator.pop(dialogContext, color),
                    ),
                  ),
                );
                final _AvatarPickResult? result =
                    color != null ? (bytes: null, color: color) : null;
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext, result);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLineContactDialog(BuildContext context, {Item? existingItem}) {
    final lineProvider = context.read<LineProvider>();
    final isEditing = existingItem != null;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final idController = TextEditingController(
            text: existingItem != null ? formatItemId(existingItem.id) : '');
        final nameController =
            TextEditingController(text: existingItem?.name ?? '');
        Uint8List? selectedImageBytes = existingItem?.icon;
        Color? selectedColor = existingItem?.avatarColor;

        return StatefulBuilder(
          builder: (sbContext, setState) {
            return AlertDialog(
              title: Text(isEditing
                  ? S.of(sbContext).dlgEditLineTitle
                  : S.of(sbContext).dlgAddLineTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final result = await _pickAvatarSource(sbContext);
                      if (result != null && sbContext.mounted) {
                        setState(() {
                          selectedImageBytes = result.bytes;
                          selectedColor = result.color;
                        });
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor:
                          selectedImageBytes == null ? selectedColor : null,
                      backgroundImage: selectedImageBytes != null
                          ? MemoryImage(selectedImageBytes!)
                          : null,
                      child: selectedImageBytes == null && selectedColor == null
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
                    if (idController.text.isEmpty ||
                        nameController.text.isEmpty) {
                      return;
                    }
                    if (existingItem != null) {
                      lineProvider.editLineContact(
                        existingItem,
                        idController.text,
                        nameController.text,
                        avatarBytes: selectedImageBytes,
                        avatarColor: selectedColor,
                      );
                    } else {
                      lineProvider.addLineContactWithAvatar(
                        idController.text,
                        nameController.text,
                        selectedImageBytes,
                        color: selectedColor,
                      );
                    }
                    Navigator.pop(dialogContext);
                  },
                  child: Text(isEditing
                      ? S.of(sbContext).btnSave
                      : S.of(sbContext).btnAdd),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    void openAddLineDialog() => _showLineContactDialog(context);

    void callLine(Item contact) {
      context.read<LineProvider>().callLine(contact.id);
    }

    return Column(
      children: <Widget>[
        Flexible(
          child: Consumer<LineProvider>(
            builder: (_, lineProvider, __) {
              final isLocked = context.watch<LockProvider>().isLocked;
              void editItem(Item item) =>
                  _showLineContactDialog(context, existingItem: item);

              return Column(
                children: <Widget>[
                  if (lineProvider.isFavListLoaded &&
                      lineProvider.favLineContacts.isNotEmpty) ...[
                    FavGridView(
                      lineProvider.favLineContacts,
                      callLine,
                      itemOnLongPressAction: isLocked ? null : editItem,
                      circular: true,
                      showLineBadge: true,
                    )
                  ] else if (lineProvider.isFavListLoaded &&
                      lineProvider.favLineContacts.isEmpty) ...[
                    LockGatedEmptyPrompt(
                      message: S.of(context).msgNoFavourites,
                      buttonLabel: S.of(context).btnAddFavLine,
                      buttonOnClickAction: openAddLineDialog,
                    ),
                  ] else ...[
                    const LoadingWidget(),
                  ],
                ],
              );
            },
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
