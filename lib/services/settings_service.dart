// lib/services/settings_service.dart
import 'package:hive/hive.dart';

class SettingsService {
  static const String _boxName = 'settings';

  Future<Box> _openBox() async {
    return Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
  }

  // -------------------------------
  // Theme
  // -------------------------------
  Future<void> saveTheme(bool isDark) async {
    final box = await _openBox();
    await box.put('isDarkMode', isDark);
  }

  Future<bool> loadTheme() async {
    final box = await _openBox();
    return box.get('isDarkMode', defaultValue: false) as bool;
  }

  // -------------------------------
  // Avatar
  // -------------------------------
  Future<void> saveAvatar(String path) async {
    final box = await _openBox();
    await box.put('avatar', path);
  }

  Future<String?> loadAvatar() async {
    final box = await _openBox();
    return box.get('avatar') as String?;
  }

  // -------------------------------
  // UserName
  // -------------------------------
  Future<void> saveUserName(String name) async {
    final box = await _openBox();
    await box.put('userName', name);
  }

  Future<String?> loadUserName() async {
    final box = await _openBox();
    return box.get('userName') as String?;
  }
}
