import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/content_loader_service.dart';

/// LanguageProvider manages the app's language settings
/// Supports English ('en') and Urdu ('ur') languages
/// Handles RTL (Right-to-Left) layout for Urdu
class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'app_language';
  static const String defaultLanguage = 'en';
  
  // Static reference for service access without context
  static Locale? currentLocale;

  Locale _locale = const Locale(defaultLanguage);
  bool _isLoading = true;

  LanguageProvider() {
    _loadLanguage();
  }

  // Getters
  Locale get locale => _locale;
  bool get isLoading => _isLoading;
  String get currentLanguageCode => _locale.languageCode;
  
  /// Check if current language is RTL (Urdu, Arabic, etc.)
  bool get isRtl => _locale.languageCode == 'ur' || _locale.languageCode == 'ar';
  
  /// Get text direction based on current language
  TextDirection get textDirection => isRtl ? TextDirection.rtl : TextDirection.ltr;

  /// Get language display name
  String get currentLanguageName {
    switch (_locale.languageCode) {
      case 'ur':
        return 'اردو';
      case 'en':
      default:
        return 'English';
    }
  }

  /// Load saved language from SharedPreferences
  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_languageKey) ?? defaultLanguage;
      _locale = Locale(savedLanguage);
      currentLocale = _locale; // Initialize static reference
    } catch (e) {
      _locale = const Locale(defaultLanguage);
      currentLocale = _locale;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set language and persist to SharedPreferences
  Future<void> setLanguage(String languageCode) async {
    if (languageCode == _locale.languageCode) return;
    
    final validCodes = ['en', 'ur'];
    if (!validCodes.contains(languageCode)) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
      _locale = Locale(languageCode);
      currentLocale = _locale; // Update static reference
      
      // Clear content cache to fetch fresh content in new language
      ContentLoaderService().clearCache();
      
      debugPrint('LanguageProvider: Changed language to $languageCode, content cache cleared');
      notifyListeners();
    } catch (e) {
      debugPrint('LanguageProvider: Error saving language: $e');
    }
  }

  /// Toggle between English and Urdu
  Future<void> toggleLanguage() async {
    final newLanguage = _locale.languageCode == 'en' ? 'ur' : 'en';
    await setLanguage(newLanguage);
  }

  /// Set language to English
  Future<void> setEnglish() async {
    await setLanguage('en');
  }

  /// Set language to Urdu
  Future<void> setUrdu() async {
    await setLanguage('ur');
  }

  /// Supported languages list for UI
  List<Map<String, String>> get supportedLanguages => [
    {'code': 'en', 'name': 'English'},
    {'code': 'ur', 'name': 'اردو'},
  ];
}
