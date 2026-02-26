import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

/// Chat Quota Service
/// Manages daily message quota (15 messages per user per day)
/// Persists data using Hive for offline capability
class ChatQuotaService {
  static const String _boxName = 'chat_quota_box';
  static const String _quotaKey = 'daily_quota';
  static const String _lastDateKey = 'last_used_date';
  static const String _firstUseKey = 'first_use_date';
  
  // Maximum messages per day
  static const int maxDailyMessages = 15;
  
  Box<dynamic>? _box;
  
  // Private constructor
  ChatQuotaService._();
  
  // Singleton instance
  static final ChatQuotaService _instance = ChatQuotaService._();
  
  /// Get singleton instance
  factory ChatQuotaService() => _instance;
  
  /// Initialize the service
  Future<void> init() async {
    try {
      _box = await Hive.openBox(_boxName);
      _checkAndResetQuota();
    } catch (e) {
      debugPrint('ChatQuotaService init error: $e');
    }
  }
  
  /// Check if service is ready
  bool get isReady => _box != null && _box!.isOpen;
  
  /// Get current quota remaining
  int get remainingQuota {
    if (!isReady) return maxDailyMessages;
    
    _checkAndResetQuota();
    return _box!.get(_quotaKey, defaultValue: maxDailyMessages) as int;
  }
  
  /// Get messages used today
  int get usedMessages => maxDailyMessages - remainingQuota;
  
  /// Check if user has quota available
  bool get hasQuota => remainingQuota > 0;
  
  /// Check if quota is exhausted
  bool get isExhausted => remainingQuota <= 0;
  
  /// Get quota percentage (0.0 to 1.0)
  double get quotaPercentage => remainingQuota / maxDailyMessages;
  
  /// Get quota status for UI display
  QuotaStatus get status {
    if (remainingQuota == 0) return QuotaStatus.exhausted;
    if (remainingQuota <= 3) return QuotaStatus.low;
    if (remainingQuota <= 8) return QuotaStatus.medium;
    return QuotaStatus.good;
  }
  
  /// Decrement quota by 1
  /// Returns true if successful, false if no quota left
  Future<bool> decrementQuota() async {
    if (!isReady) return false;
    
    _checkAndResetQuota();
    
    final current = remainingQuota;
    if (current <= 0) return false;
    
    await _box!.put(_quotaKey, current - 1);
    return true;
  }
  
  /// Reset quota to max (for testing or manual reset)
  Future<void> resetQuota() async {
    if (!isReady) return;
    
    await _box!.put(_quotaKey, maxDailyMessages);
    await _box!.put(_lastDateKey, DateTime.now().toIso8601String().split('T')[0]);
  }
  
  /// Check if quota needs to be reset (new day)
  void _checkAndResetQuota() {
    if (!isReady) return;
    
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastDate = _box!.get(_lastDateKey, defaultValue: '') as String;
    
    // If new day, reset quota
    if (lastDate != today) {
      _box!.put(_quotaKey, maxDailyMessages);
      _box!.put(_lastDateKey, today);
      
      // Track first use
      if (_box!.get(_firstUseKey) == null) {
        _box!.put(_firstUseKey, today);
      }
    }
  }
  
  /// Get days since first use
  int? get daysSinceFirstUse {
    if (!isReady) return null;
    
    final firstUse = _box!.get(_firstUseKey) as String?;
    if (firstUse == null) return null;
    
    final firstDate = DateTime.parse(firstUse);
    final now = DateTime.now();
    return now.difference(firstDate).inDays;
  }
  
  /// Get quota display string
  String get quotaDisplay => '$remainingQuota/$maxDailyMessages';
  
  /// Close the box (cleanup)
  Future<void> dispose() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
  }
}

/// Quota Status Enum for UI coloring
enum QuotaStatus {
  good,     // Green - plenty left
  medium,   // Yellow - getting low
  low,      // Orange - almost out
  exhausted, // Red - none left
}

/// Extension for QuotaStatus
extension QuotaStatusExtension on QuotaStatus {
  String get displayText {
    switch (this) {
      case QuotaStatus.good:
        return 'Messages available';
      case QuotaStatus.medium:
        return 'Messages running low';
      case QuotaStatus.low:
        return 'Only a few messages left';
      case QuotaStatus.exhausted:
        return 'Daily limit reached';
    }
  }
  
  /// Get color hint for UI
  String get colorName {
    switch (this) {
      case QuotaStatus.good:
        return 'green';
      case QuotaStatus.medium:
        return 'yellow';
      case QuotaStatus.low:
        return 'orange';
      case QuotaStatus.exhausted:
        return 'red';
    }
  }
}
