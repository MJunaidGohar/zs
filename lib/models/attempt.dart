import 'package:hive/hive.dart';

part 'attempt.g.dart';

@HiveType(typeId: 0)
class Attempt extends HiveObject {
  @HiveField(0)
  final String selectedClass; // DEPRECATED: maps to topic

  @HiveField(1)
  final String subject; // DEPRECATED: maps to level

  @HiveField(2)
  final String selectedUnit; // DEPRECATED: maps to subtopic

  @HiveField(8)
  final String? topic; // NEW: alternative to selectedClass

  @HiveField(9)
  final String? level; // NEW: alternative to subject

  @HiveField(10)
  final String? subtopic; // NEW: alternative to selectedUnit

  @HiveField(3)
  final String selectedCategory;

  @HiveField(4)
  final String questionType;

  @HiveField(5)
  final int score;

  @HiveField(6)
  final int total;

  /// Stores when the attempt happened
  @HiveField(7)
  final DateTime timestamp;

  Attempt({
    String? selectedClass,
    String? subject,
    String? selectedUnit,
    String? topic,
    String? level,
    String? subtopic,
    required this.selectedCategory,
    required this.questionType,
    required this.score,
    required this.total,
    DateTime? timestamp,
  })  : selectedClass = selectedClass ?? topic ?? 'unknown',
        subject = subject ?? level ?? 'basic',
        selectedUnit = selectedUnit ?? subtopic ?? 'general',
        topic = topic,
        level = level,
        subtopic = subtopic,
        timestamp = timestamp ?? DateTime.now();

  /// Get display name for the category (topic or selectedClass)
  String get displayTopic => topic ?? selectedClass;
  
  /// Get display name for the level (subject or level)
  String get displayLevel => level ?? subject;
  
  /// Get display name for the subtopic (selectedUnit or subtopic)
  String get displaySubtopic => subtopic ?? selectedUnit;
}
