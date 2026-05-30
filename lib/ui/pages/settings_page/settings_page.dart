import 'package:flutter/material.dart';
import '../../common/elder_page_scaffold.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ElderPageScaffold(
      title: 'Settings',
      body: const SizedBox.shrink(),
    );
  }
}
