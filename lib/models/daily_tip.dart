import 'package:flutter/material.dart';

/// Daily Tip Model
/// Represents an educational tip displayed to users
class DailyTip {
  final String id;
  final String category;
  final String tip;
  final String? dayOfWeek;
  final IconData? icon;

  DailyTip({
    required this.id,
    required this.category,
    required this.tip,
    this.dayOfWeek,
    this.icon,
  });

  @override
  String toString() {
    return 'DailyTip{category: $category, tip: $tip}';
  }
}

/// Pre-defined daily tips database
class DailyTipsDatabase {
  static final List<DailyTip> _tips = [
    // Monday - English
    DailyTip(
      id: 'mon_1',
      category: 'English',
      tip: "'Affect' is a verb (to influence), 'Effect' is a noun (the result).",
      dayOfWeek: 'Monday',
      icon: Icons.language,
    ),
    DailyTip(
      id: 'mon_2',
      category: 'English',
      tip: "'Their' = possession, 'There' = place, 'They're' = they are.",
      dayOfWeek: 'Monday',
      icon: Icons.language,
    ),
    
    // Tuesday - Computer
    DailyTip(
      id: 'tue_1',
      category: 'Computer',
      tip: "RAM is temporary memory. More RAM = faster multitasking!",
      dayOfWeek: 'Tuesday',
      icon: Icons.computer,
    ),
    DailyTip(
      id: 'tue_2',
      category: 'Computer',
      tip: "Ctrl+C copies, Ctrl+V pastes - universal shortcuts everywhere!",
      dayOfWeek: 'Tuesday',
      icon: Icons.computer,
    ),
    
    // Wednesday - Digital Marketing
    DailyTip(
      id: 'wed_1',
      category: 'Digital Marketing',
      tip: "Use 5-10 relevant hashtags for best reach on social media.",
      dayOfWeek: 'Wednesday',
      icon: Icons.trending_up,
    ),
    DailyTip(
      id: 'wed_2',
      category: 'Digital Marketing',
      tip: "Post when your audience is most active. Check your Insights!",
      dayOfWeek: 'Wednesday',
      icon: Icons.trending_up,
    ),
    
    // Thursday - Web Development
    DailyTip(
      id: 'thu_1',
      category: 'Web Development',
      tip: "Mobile-first design: 60% of users browse websites on phones.",
      dayOfWeek: 'Thursday',
      icon: Icons.code,
    ),
    DailyTip(
      id: 'thu_2',
      category: 'Web Development',
      tip: "Always use alt text for images - better accessibility & SEO!",
      dayOfWeek: 'Thursday',
      icon: Icons.code,
    ),
    
    // Friday - YouTube
    DailyTip(
      id: 'fri_1',
      category: 'YouTube',
      tip: "Thumbnails with faces get 38% more clicks. Show expressions!",
      dayOfWeek: 'Friday',
      icon: Icons.play_circle_outline,
    ),
    DailyTip(
      id: 'fri_2',
      category: 'YouTube',
      tip: "First 30 seconds are critical. Hook viewers immediately!",
      dayOfWeek: 'Friday',
      icon: Icons.play_circle_outline,
    ),
    
    // Saturday - Study Techniques
    DailyTip(
      id: 'sat_1',
      category: 'Study',
      tip: "Pomodoro technique: 25 min study, 5 min break = better retention!",
      dayOfWeek: 'Saturday',
      icon: Icons.timer,
    ),
    DailyTip(
      id: 'sat_2',
      category: 'Study',
      tip: "Spaced repetition: Review notes after 1 day, 3 days, 7 days.",
      dayOfWeek: 'Saturday',
      icon: Icons.timer,
    ),
    
    // Sunday - Motivation
    DailyTip(
      id: 'sun_1',
      category: 'Motivation',
      tip: "Progress, not perfection. Every expert started as a beginner!",
      dayOfWeek: 'Sunday',
      icon: Icons.lightbulb,
    ),
    DailyTip(
      id: 'sun_2',
      category: 'Motivation',
      tip: "Consistency beats intensity. Small daily steps lead to success!",
      dayOfWeek: 'Sunday',
      icon: Icons.lightbulb,
    ),
    
    // General tips (any day)
    DailyTip(
      id: 'gen_1',
      category: 'General',
      tip: "Take regular breaks. Your brain absorbs information better with rest!",
      icon: Icons.self_improvement,
    ),
    DailyTip(
      id: 'gen_2',
      category: 'General',
      tip: "Teach what you learn. Explaining concepts helps you master them!",
      icon: Icons.school,
    ),
    DailyTip(
      id: 'gen_3',
      category: 'General',
      tip: "Stay curious. Ask 'why' and 'how' to deepen understanding!",
      icon: Icons.psychology,
    ),
  ];

  /// Get all tips
  static List<DailyTip> get allTips => List.unmodifiable(_tips);

  /// Get tip for specific day
  static DailyTip getTipForDay(String dayOfWeek) {
    final dayTips = _tips.where((t) => t.dayOfWeek == dayOfWeek).toList();
    if (dayTips.isNotEmpty) {
      // Return random tip for that day
      return dayTips[DateTime.now().millisecond % dayTips.length];
    }
    // Fallback to general tips
    return getRandomGeneralTip();
  }

  /// Get today's tip based on current day
  static DailyTip getTodayTip() {
    final now = DateTime.now();
    final dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return getTipForDay(dayNames[now.weekday % 7]);
  }

  /// Get random general tip
  static DailyTip getRandomGeneralTip() {
    final generalTips = _tips.where((t) => t.dayOfWeek == null).toList();
    return generalTips[DateTime.now().millisecond % generalTips.length];
  }

  /// Get tip by ID
  static DailyTip? getTipById(String id) {
    try {
      return _tips.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
}
