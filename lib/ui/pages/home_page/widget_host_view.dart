import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _widgetHostViewType = 'widget_host_view';

class WidgetHostView extends StatelessWidget {
  final int appWidgetId;
  final double height;

  const WidgetHostView(
      {required this.appWidgetId, required this.height, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: AndroidView(
        viewType: _widgetHostViewType,
        creationParams: {'appWidgetId': appWidgetId},
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}
