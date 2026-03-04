import '../models/question.dart';
import 'package:hive/hive.dart';
import 'hive_service.dart';

class WrongQuestionsService {
  final Box<Question> _box = HiveService.wrongQuestionsBox;

  Future<List<Question>> getWrongQuestions() async {
    return _box.values.toList();
  }

  Future<void> saveWrongQuestions(List<Question> questions) async {
    // Get existing wrong questions
    final existing = _box.values.toList();
    final existingIds = existing.map((q) => q.id).toSet();
    
    // Filter out duplicates (questions that already exist)
    final newQuestions = questions.where((q) => !existingIds.contains(q.id)).toList();
    
    // Add only new wrong questions (append, don't clear)
    if (newQuestions.isNotEmpty) {
      await _box.addAll(newQuestions.map((q) => Question(
        id: q.id,
        questionText: q.questionText,
        options: q.options != null ? List<String>.from(q.options!) : null,
        correctAnswer: q.correctAnswer,
        answer: q.answer,
        topic: (q.topic ?? q.selectedClass)?.toLowerCase(),
        level: (q.level ?? q.subject)?.toLowerCase(),
        subtopic: (q.subtopic ?? q.selectedUnit)?.toLowerCase(),
      )));
    }
  }

  Future<void> clearWrongQuestions() async {
    await _box.clear();
  }

  Future<void> removeCorrectedQuestions(List<Question> corrected) async {
    if (corrected.isEmpty) return;

    final correctedIds = corrected.map((c) => c.id).toSet();

    final updated = _box.values.where((q) => !correctedIds.contains(q.id)).toList();

    await _box.clear();
    await _box.addAll(updated.map((q) => Question(
      id: q.id,
      questionText: q.questionText,
      options: q.options != null ? List<String>.from(q.options!) : null,
      correctAnswer: q.correctAnswer,
      answer: q.answer,
      topic: (q.topic ?? q.selectedClass)?.toLowerCase(),
      level: (q.level ?? q.subject)?.toLowerCase(),
      subtopic: (q.subtopic ?? q.selectedUnit)?.toLowerCase(),
    )));
  }
}
