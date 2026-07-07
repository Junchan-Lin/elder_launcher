import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../generated/l10n.dart';
import '../../../providers/lock_provider.dart';
import '../../../providers/widget_provider.dart';
import '../../../ui/common/buttons.dart';
import '../../../ui/common/loading_widget.dart';
import '../../../ui/common/lock_gated_empty_prompt.dart';
import 'widget_host_view.dart';

class WidgetsTab extends StatelessWidget {
  const WidgetsTab({super.key});

  @override
  Widget build(BuildContext context) {
    void addWidget() => context.read<WidgetProvider>().addWidget();

    return Column(
      children: <Widget>[
        Flexible(
          child: Consumer<WidgetProvider>(
            builder: (_, widgetProvider, __) {
              return Column(
                children: <Widget>[
                  if (widgetProvider.isFavListLoaded &&
                      widgetProvider.favWidgets.isNotEmpty) ...[
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        children: widgetProvider.favWidgets
                            .map((item) => Padding(
                                  key: Key(item.id),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: WidgetHostView(
                                    appWidgetId: int.parse(item.id),
                                    height: widgetProvider
                                        .getWidgetHeight(item.id)
                                        .toDouble(),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ] else if (widgetProvider.isFavListLoaded &&
                      widgetProvider.favWidgets.isEmpty) ...[
                    LockGatedEmptyPrompt(
                      message: S.of(context).msgNoWidgets,
                      buttonLabel: S.of(context).btnAddWidget,
                      buttonOnClickAction: addWidget,
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
                    S.of(context).btnAddWidget,
                    addWidget,
                  ),
                ),
        ),
      ],
    );
  }
}
