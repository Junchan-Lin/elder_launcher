import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../constants/custom_functions.dart';
import '../../../models/item.dart';
import '../../../ui/theme.dart';

class FavGridView extends StatelessWidget {
  final List<Item> favItems;
  final VoidItemFunction itemOnClickAction;
  final bool circular;
  final bool showLineBadge;

  const FavGridView(
    this.favItems,
    this.itemOnClickAction, {
    super.key,
    this.circular = false,
    this.showLineBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    var itemName = AutoSizeGroup();

    return Expanded(
      child: GridView.count(
        childAspectRatio: 1.25,
        crossAxisCount: 2,
        padding: const EdgeInsets.all(6),
        children: favItems.map((item) {
          return FavItemCard(
            item: item,
            itemOnClickAction: itemOnClickAction,
            itemName: itemName,
            circular: circular,
            showLineBadge: showLineBadge,
          );
        }).toList(),
      ),
    );
  }
}

class FavItemCard extends StatelessWidget {
  const FavItemCard({
    super.key,
    required this.item,
    required this.itemOnClickAction,
    required this.itemName,
    this.circular = false,
    this.showLineBadge = false,
  });

  final Item item;
  final VoidItemFunction itemOnClickAction;
  final AutoSizeGroup itemName;
  final bool circular;
  final bool showLineBadge;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget;

    if (circular) {
      final hasPhoto = item.icon?.isNotEmpty ?? false;
      iconWidget = Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 35,
            backgroundImage: hasPhoto ? MemoryImage(item.icon!) : null,
            child: hasPhoto ? null : const Icon(Icons.person, size: 35),
          ),
          if (showLineBadge)
            const FaIcon(
              FontAwesomeIcons.line,
              size: 18,
              color: Color(0xFF06C755),
            ),
        ],
      );
    } else if (item.icon?.isNotEmpty ?? false) {
      iconWidget = Image(
        height: 70,
        image: MemoryImage(item.icon!),
      );
    } else {
      iconWidget = const SizedBox.shrink();
    }

    return Card(
      color: Theme.of(context).cardColor,
      elevation: 4,
      child: InkWell(
        splashColor: Colors.blue.withAlpha(50),
        onTap: () => itemOnClickAction(item),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            iconWidget,
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 2, 0, 0),
                child: AutoSizeText(
                  item.name,
                  group: itemName,
                  maxLines: 2,
                  style: TextStyles.cardTitle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
