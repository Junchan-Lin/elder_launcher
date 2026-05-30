import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static List<String> getList(String key) =>
      _prefs!.getStringList(key) ?? [];

  static void setList(String key, List<String> stringList) =>
      _prefs!.setStringList(key, stringList);

  // ignore: avoid_positional_boolean_parameters
  static bool getBool(String key, bool defaultValue) =>
      _prefs!.getBool(key) ?? defaultValue;

  // ignore: avoid_positional_boolean_parameters
  static void setBool(String key, bool value) =>
      _prefs!.setBool(key, value);

  static int getInt(String key, int defaultValue) =>
      _prefs!.getInt(key) ?? defaultValue;

  static void setInt(String key, int value) =>
      _prefs!.setInt(key, value);

  static String? getString(String key) => _prefs!.getString(key);

  static void setString(String key, String value) =>
      _prefs!.setString(key, value);

  static void removeKey(String key) => _prefs!.remove(key);
}
