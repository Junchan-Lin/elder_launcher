import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/custom_functions.dart';
import '../../providers/lock_provider.dart';
import 'info_action_widget.dart';

/// Wraps [InfoActionWidget.add] so the "add favourites" prompt only shows
/// when unlocked. When locked, this renders nothing — showing an empty-list
/// prompt with a working add button while locked would let a user bypass
/// the lock and start editing favourites.
class LockGatedEmptyPrompt extends StatelessWidget {
  final String message;
  final String buttonLabel;
  final VoidFunction buttonOnClickAction;

  const LockGatedEmptyPrompt({
    super.key,
    required this.message,
    required this.buttonLabel,
    required this.buttonOnClickAction,
  });

  @override
  Widget build(BuildContext context) {
    if (context.watch<LockProvider>().isLocked) {
      return const SizedBox.shrink();
    }
    return Expanded(
      child: InfoActionWidget.add(
        message: message,
        buttonLabel: buttonLabel,
        buttonOnClickAction: buttonOnClickAction,
      ),
    );
  }
}
