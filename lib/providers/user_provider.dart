// lib/providers/user_provider.dart
import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class UserProvider extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  String? _selectedAvatar;
  String? _userName;
  String? _userClass; // added to store user class
  bool _isLoading = true;

  String? get selectedAvatar => _selectedAvatar;
  String? get userName => _userName;
  String? get userClass => _userClass; // new getter
  bool get isLoading => _isLoading;

  UserProvider();

  /// Initialize and load data
  Future<void> loadUserData() async {
    _selectedAvatar = await _settingsService.loadAvatar();
    _userName = await _settingsService.loadUserName();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setAvatar(String path) async {
    _selectedAvatar = path;
    await _settingsService.saveAvatar(path);
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    await _settingsService.saveUserName(name);
    notifyListeners();
  }

  /// 🔹 New method to set all user info at once
  Future<void> setUser({
    String? name,
    String? userClass,
    String? avatar,
  }) async {
    if (name != null) {
      _userName = name;
      await _settingsService.saveUserName(name);
    }

    if (avatar != null) {
      _selectedAvatar = avatar;
      await _settingsService.saveAvatar(avatar);
    }

    if (userClass != null) {
      _userClass = userClass;
      // optionally save userClass in SettingsService if needed
    }

    notifyListeners();
  }
}
