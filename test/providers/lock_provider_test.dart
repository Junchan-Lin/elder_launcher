import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elder_launcher/providers/lock_provider.dart';
import 'package:elder_launcher/utils/shared_prefs.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefs.init();
  });

  test('初始狀態預設為鎖定', () {
    final provider = LockProvider();
    expect(provider.isLocked, isTrue);
  });

  test('toggleLock 從鎖定切換到解鎖', () {
    final provider = LockProvider();
    provider.toggleLock();
    expect(provider.isLocked, isFalse);
  });

  test('toggleLock 從解鎖再切換回鎖定', () {
    final provider = LockProvider();
    provider.toggleLock(); // → 解鎖
    provider.toggleLock(); // → 鎖定
    expect(provider.isLocked, isTrue);
  });

  test('toggleLock 後狀態持久化，新建 provider 讀回相同狀態', () {
    final p1 = LockProvider();
    p1.toggleLock(); // → 解鎖並寫入 SharedPrefs
    final p2 = LockProvider(); // 讀取持久化狀態
    expect(p2.isLocked, isFalse);
  });
}
