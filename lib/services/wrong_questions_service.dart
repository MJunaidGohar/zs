import '../models/question.dart';
import 'package:hive/hive.dart';
import 'hive_service.dart';

class WrongQuestionsService {
  final Box<Question> _box = HiveService.wrongQuestionsBox;

  Future<List<Question>> getWrongQuestions() async {
    return _box.values.toList();
  }

  Future<void> saveWrongQuestions(List<Question> questions) async {
    await _box.clear();
    await _box.addAll(questions.map((q) => Question(
      id: q.id,
      questionText: q.questionText,
      options: q.options != null ? List<String>.from(q.options!) : null,
      correctAnswer: q.correctAnswer,
      answer: q.answer,
      selectedClass: q.selectedClass,
      subject: q.subject,
      selectedUnit: q.selectedUnit,
    )));
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
      selectedClass: q.selectedClass?.toLowerCase(),
      subject: q.subject?.toLowerCase(),
      selectedUnit: q.selectedUnit?.toLowerCase(),
    )));
  }
}
