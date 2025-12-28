import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'question.g.dart';

@HiveType(typeId: 1)
class Question extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String questionText;

  @HiveField(2)
  final List<String>? options;

  @HiveField(3)
  final String? correctAnswer;

  @HiveField(4)
  final String? answer; // for short/long answers (Learn mode)

  @HiveField(5)
  String? selectedClass;

  @HiveField(6)
  String? subject;

  @HiveField(7)
  String? selectedUnit;

  Question({
    String? id,
    required this.questionText,
    this.options,
    this.correctAnswer,
    this.answer,
    this.selectedClass,
    this.subject,
    this.selectedUnit,
  }) : id = id ?? const Uuid().v4();
}
