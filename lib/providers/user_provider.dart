// lib/providers/user_provider.dart
import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class UserProvider extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  String? _selectedAvatar;
  String? _userName;
  bool _isLoading = true;

  String? get selectedAvatar => _selectedAvatar;
  String? get userName => _userName;
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

  /// Set all user info at once
  Future<void> setUser({
    String? name,
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

    notifyListeners();
  }

  /// Static method to get user profile data directly
  static Future<Map<String, String?>> getUserProfile() async {
    final settingsService = SettingsService();
    final userName = await settingsService.loadUserName();
    final avatar = await settingsService.loadAvatar();
    return {
      'name': userName,
      'avatar': avatar,
    };
  }
}
