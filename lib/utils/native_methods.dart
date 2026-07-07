import 'package:flutter/services.dart';
import '../constants/channels.dart';

class NativeMethods {
  final platformCore = const MethodChannel(channelCore);
  final platformContacts = const MethodChannel(channelContacts);
  final platformWidgets = const MethodChannel(channelWidgets);

  /*
  ** Contacts & Call
  */

  Future<bool> hasTelephoneFeature() async {
    var hasTelephoneFeatureResult =
        await platformContacts.invokeMethod<bool>('hasTelephoneFeature');
    return hasTelephoneFeatureResult ?? false;
  }

  void launchContactsApp() {
    platformContacts.invokeMethod('launchContactsApp');
  }

  void launchDialerApp(String number) {
    platformContacts.invokeMethod('launchDialerWithNumber', {'number': number});
  }

  void startPhoneCall(String number) {
    platformContacts.invokeMethod('startPhoneCall', {'number': number});
  }

  /*
  ** Core
  */

  Future<bool> canSetDefaultLauncher() async {
    var canSetDefaultLauncherResult =
        await platformCore.invokeMethod<bool>('canSetDefaultLauncher');
    return canSetDefaultLauncherResult ?? false;
  }

  void setDefaultLauncher() {
    platformCore.invokeMethod('setDefaultLauncher');
  }

  Future<List<String>> getDeprecatedPrefsList() async {
    var favAppsInDeprecatedList =
        await platformCore.invokeListMethod<String>('getDeprecatedFavAppIds');
    return favAppsInDeprecatedList ?? <String>[];
  }

  /*
  ** Widgets
  */

  Future<Map<String, dynamic>?> pickAndBindWidget() async {
    final result =
        await platformWidgets.invokeMethod<Map>('pickAndBindWidget');
    return result?.cast<String, dynamic>();
  }

  void deleteWidget(int appWidgetId) {
    platformWidgets
        .invokeMethod('deleteWidget', {'appWidgetId': appWidgetId});
  }

  Future<List<int>> filterValidWidgetIds(List<int> appWidgetIds) async {
    final result = await platformWidgets.invokeListMethod<int>(
        'filterValidWidgetIds', {'appWidgetIds': appWidgetIds});
    return result ?? appWidgetIds;
  }
}
