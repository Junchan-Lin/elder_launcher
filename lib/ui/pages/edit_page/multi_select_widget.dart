import '../../../utils/item_utils.dart';
import 'package:flutter/material.dart';
import '../../../services/edit_service.dart';
import '../../../ui/theme.dart';

class MultiSelectWidget extends StatelessWidget {
  final EditService editService;
  final bool showId;

  const MultiSelectWidget(this.editService, {super.key, required this.showId});

  @override
  Widget build(BuildContext context) {
    final allItems = editService.sortedItems;

    void toggleFav(int position) {
      editService.toggleFav(position);
    }

    return ListView.separated(
      itemCount: allItems.length,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemBuilder: (context, position) {
        var item = allItems[position];
        var isFav = editService.isFav(position);

        return CheckboxListTile(
          key: Key(item.id),
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
          secondary: item.icon?.isNotEmpty ?? false
              ? Image(
                  image: MemoryImage(item.icon!),
                )
              : const CircleAvatar(),
          value: isFav,
          onChanged: (isChecked) {
            toggleFav(position);
          },
        );
      },
      separatorBuilder: (_, __) {
        return const Divider(
          thickness: Values.dividerThickness,
        );
      },
    );
  }
}
