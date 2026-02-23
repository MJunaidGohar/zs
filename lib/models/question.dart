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
  String? selectedClass; // DEPRECATED: use topic instead

  @HiveField(6)
  String? subject; // DEPRECATED: use level instead

  @HiveField(7)
  String? selectedUnit; // DEPRECATED: use subtopic instead

  @HiveField(8)
  String? topic; // NEW: replaces selectedClass

  @HiveField(9)
  String? level; // NEW: replaces subject

  @HiveField(10)
  String? subtopic; // NEW: replaces selectedUnit

  Question({
    String? id,
    required this.questionText,
    this.options,
    this.correctAnswer,
    this.answer,
    this.selectedClass,
    this.subject,
    this.selectedUnit,
    this.topic,
    this.level,
    this.subtopic,
  }) : id = id ?? const Uuid().v4();

  /// Get the category key for loading content
  /// Returns topic/level/subtopic if available, otherwise falls back to old fields
  String get categoryKey {
    final t = topic ?? selectedClass ?? 'unknown';
    final l = level ?? subject ?? 'basic';
    final s = subtopic ?? selectedUnit ?? 'general';
    return '${t.toLowerCase()}/${l.toLowerCase()}/${s.toLowerCase()}';
  }

  /// Create from JSON map (new format with topic/level/subtopic)
  factory Question.fromJson(Map<String, dynamic> json) {
    final options = json['option_a'] != null
        ? [
            json['option_a'] as String,
            json['option_b'] as String,
            json['option_c'] as String,
            json['option_d'] as String,
          ]
        : null;
    
    // Convert correct_option letter (A/B/C/D) to actual option text
    final correctOptionLetter = json['correct_option'] as String?;
    String? correctAnswerText;
    if (correctOptionLetter != null && options != null) {
      final letterIndex = correctOptionLetter.toUpperCase().codeUnitAt(0) - 'A'.codeUnitAt(0);
      if (letterIndex >= 0 && letterIndex < options.length) {
        correctAnswerText = options[letterIndex];
      }
    }

    return Question(
      id: json['id'] as String?,
      questionText: json['question'] as String? ?? '',
      options: options,
      correctAnswer: correctAnswerText,
      answer: json['answer'] as String? ?? json['explanation'] as String?,
      topic: json['topic'] as String?,
      level: json['level'] as String?,
      subtopic: json['subtopic'] as String?,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': questionText,
      'option_a': options != null && options!.isNotEmpty ? options![0] : null,
      'option_b': options != null && options!.length > 1 ? options![1] : null,
      'option_c': options != null && options!.length > 2 ? options![2] : null,
      'option_d': options != null && options!.length > 3 ? options![3] : null,
      'correct_option': correctAnswer != null && options != null
          ? String.fromCharCode('A'.codeUnitAt(0) + options!.indexOf(correctAnswer!))
          : null,
      'answer': answer,
      'topic': topic,
      'level': level,
      'subtopic': subtopic,
    };
  }
}
