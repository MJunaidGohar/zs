import 'package:hive/hive.dart';

part 'attempt.g.dart';

@HiveType(typeId: 0)
class Attempt extends HiveObject {
  @HiveField(0)
  final String selectedClass;

  @HiveField(1)
  final String subject;

  @HiveField(2)
  final String selectedUnit;

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
    required this.selectedClass,
    required this.subject,
    required this.selectedUnit,
    required this.selectedCategory,
    required this.questionType,
    required this.score,
    required this.total,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
