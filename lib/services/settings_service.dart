import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _deeplApiKey = 'deepl_api_key';

  static Future<void> saveDeepLApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deeplApiKey, apiKey);
  }

  static Future<String?> getDeepLApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deeplApiKey);
  }
}
