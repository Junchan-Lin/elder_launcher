import 'package:flutter/foundation.dart';
import '../constants/keys.dart';
import '../utils/shared_prefs.dart';

class LockProvider extends ChangeNotifier {
  bool _isLocked;

  LockProvider() : _isLocked = SharedPrefs.getBool(keyIsLocked, true);

  bool get isLocked => _isLocked;

  void toggleLock() {
    _isLocked = !_isLocked;
    SharedPrefs.setBool(keyIsLocked, _isLocked);
    notifyListeners();
  }
}
