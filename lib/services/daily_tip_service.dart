import 'package:flutter/foundation.dart';
import '../models/daily_tip.dart';

/// Daily Tip Service
/// Manages daily educational tips rotation and display
class DailyTipService {
  // Private constructor
  DailyTipService._();
  
  // Singleton instance
  static final DailyTipService _instance = DailyTipService._();
  
  /// Get singleton instance
  factory DailyTipService() => _instance;
  
  DailyTip? _currentTip;
  DateTime? _lastTipDate;
  
  /// Initialize the service
  void init() {
    _refreshTipIfNeeded();
  }
  
  /// Get today's tip
  /// Returns cached tip if already fetched today, otherwise gets new one
  DailyTip getTodayTip() {
    _refreshTipIfNeeded();
    return _currentTip ?? DailyTipsDatabase.getTodayTip();
  }
  
  /// Force refresh the tip (for testing or when day changes)
  DailyTip refreshTip() {
    _currentTip = DailyTipsDatabase.getTodayTip();
    _lastTipDate = DateTime.now();
    return _currentTip!;
  }
  
  /// Get tip for a specific day
  DailyTip getTipForDay(String dayOfWeek) {
    return DailyTipsDatabase.getTipForDay(dayOfWeek);
  }
  
  /// Get random general tip
  DailyTip getRandomTip() {
    return DailyTipsDatabase.getRandomGeneralTip();
  }
  
  /// Refresh tip if day has changed
  void _refreshTipIfNeeded() {
    final now = DateTime.now();
    
    if (_lastTipDate == null || !_isSameDay(_lastTipDate!, now)) {
      _currentTip = DailyTipsDatabase.getTodayTip();
      _lastTipDate = now;
      debugPrint('DailyTipService: Refreshed tip for ${now.toIso8601String()}');
    }
  }
  
  /// Check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
  
  /// Get tip display text with icon
  String getTipDisplayText() {
    final tip = getTodayTip();
    final iconStr = _getIconString(tip.icon);
    return '$iconStr ${tip.tip}';
  }
  
  /// Get icon string representation
  String _getIconString(dynamic icon) {
    if (icon == null) return '🧠';
    // Map common icons to emojis
    const iconMap = {
      'language': '📚',
      'computer': '💻',
      'trending_up': '📈',
      'code': '💻',
      'play_circle_outline': '🎬',
      'timer': '⏱️',
      'lightbulb': '💡',
      'self_improvement': '🧘',
      'school': '🎓',
      'psychology': '🧠',
    };
    return iconMap[icon.toString().toLowerCase()] ?? '🧠';
  }
  
  /// Get category color hint
  String getCategoryColor(String category) {
    final colors = {
      'English': 'blue',
      'Computer': 'indigo',
      'Digital Marketing': 'teal',
      'Web Development': 'purple',
      'YouTube': 'red',
      'Study': 'green',
      'Motivation': 'orange',
      'General': 'grey',
    };
    return colors[category] ?? 'grey';
  }
}
