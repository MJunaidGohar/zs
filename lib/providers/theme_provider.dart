import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class ThemeProvider extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _settingsService.saveTheme(_isDarkMode);
    notifyListeners();
  }

  Future<void> _loadTheme() async {
    _isDarkMode = await _settingsService.loadTheme();
    notifyListeners();
  }
}
