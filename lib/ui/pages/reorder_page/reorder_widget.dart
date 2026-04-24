import '../../../utils/item_utils.dart';
import 'package:flutter/material.dart';
import '../../../models/item.dart';
import '../../../services/edit_service.dart';
import '../../../ui/theme.dart';

class ReorderWidget extends StatelessWidget {
  final EditService editService;
  final bool showId;

  const ReorderWidget(this.editService, {super.key, required this.showId});

  @override
  Widget build(BuildContext context) {
    final favItems = editService.sortedItems;

    void reorderItems(int oldIndex, int newIndex) {
      editService.reorderFavItems(oldIndex, newIndex);
    }

    return ReorderableListView(
      onReorder: reorderItems,
      padding: const EdgeInsets.all(6),
      children: favItems
          .map((item) => ReorderableCard(
                item: item,
                showId: showId,
                key: Key(item.id),
              ))
          .toList(),
    );
  }
}

class ReorderableCard extends StatelessWidget {
  const ReorderableCard({
    super.key,
    required this.item,
    required this.showId,
  });

  final Item item;
  final bool showId;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListTile(
          title: Text(
            item.name,
            style: TextStyles.listTitle,
          ),
          subtitle: showId
              ? Text(
                  formatItemId(item.id),
                  style: TextStyles.listTitle,
                )
              : null,
          leading: item.icon?.isNotEmpty ?? false
              ? Image(
                  image: MemoryImage(item.icon!),
                )
              : const CircleAvatar(),
          trailing: const Icon(Icons.drag_handle),
        ),
      ),
    );
  }
}
