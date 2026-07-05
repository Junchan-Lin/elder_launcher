import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

/// Data class used for storing app or contact info.
@immutable
class Item {
  /// App package name or Phone number
  final String id;

  final String name;
  final Uint8List? icon;

  /// Fallback circle-avatar background colour, used when [icon] is null.
  final Color? avatarColor;

  const Item(this.id, this.name, this.icon, {this.avatarColor});

  @override
  // ignore: type_annotate_public_apis, avoid_renaming_method_parameters
  bool operator ==(Object o) => o is Item && o.id.compareTo(id) == 0;

  @override
  int get hashCode => id.hashCode;
}
