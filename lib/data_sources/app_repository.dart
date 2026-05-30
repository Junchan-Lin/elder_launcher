import 'dart:typed_data';
import 'package:device_apps/device_apps.dart';
import '../constants/keys.dart';
import '../models/interfaces/data_repository.dart';
import '../models/item.dart';
import '../utils/shared_prefs.dart';

class AppRepository implements DataRepository {
  @override
  Future<List<Item>> getAllItems() async {
    var allApps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: true,
        onlyAppsWithLaunchIntent: true);
    return _sortItems(await _toItems(allApps));
  }

  @override
  Future<List<Item>> getFavItems() async {
    var favPackages = SharedPrefs.getList(keyFavApps);
    final results = await Future.wait(
      favPackages.map((p) => DeviceApps.getApp(p, true)),
    );
    final favApps = results.whereType<ApplicationWithIcon>().toList();
    return _toItems(favApps);
  }

  @override
  void setFavItems(List<String> favPackages) {
    SharedPrefs.setList(keyFavApps, favPackages);
  }

  Future<List<Item>> _toItems(List<Application> apps) async {
    return apps
        .map((app) => Item(
              app.packageName,
              app.appName,
              app is ApplicationWithIcon
                  ? app.icon as Uint8List // ignore: unnecessary_cast
                  : null,
            ))
        .toList();
  }

  // TODO: Sort Apps as per locale and pronounciation
  List<Item> _sortItems(List<Item> apps) {
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return apps;
  }
}
