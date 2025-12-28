import 'package:hive/hive.dart';
import '../models/question.dart';
import 'hive_service.dart';
import '../utils/string_extensions.dart';
import '../data/sample_question.dart'; // 🔹 bring in your full sample data

class QuestionService {
  final Box<Question> _box = HiveService.questionsBox;

  /// -------------------------------
  /// CRUD Operations
  /// -------------------------------
  Future<List<Question>> getQuestions() async {
    return _box.values.toList();
  }

  Future<void> addQuestion(Question question) async {
    // Check for duplicate id
    bool exists = _box.values.any((q) => q.id == question.id);
    if (!exists) {
      await _box.add(question);
    }
  }

  Future<void> addQuestions(List<Question> questions) async {
    for (var q in questions) {
      await addQuestion(q); // ensures no duplicate ids
    }
  }

  Future<void> updateQuestion(int key, Question updated) async {
    if (_box.containsKey(key)) {
      await _box.put(key, updated);
    }
  }

  Future<void> deleteQuestion(int key) async {
    if (_box.containsKey(key)) {
      await _box.delete(key);
    }
  }

  Future<void> clearQuestions() async {
    await _box.clear();
  }

  Future<Question?> getQuestionById(String id) async {
    try {
      return _box.values.firstWhere((q) => q.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> removeQuestionById(String id) async {
    final key = _box.keys.cast<int?>().firstWhere(
          (k) => _box.get(k)?.id == id,
      orElse: () => null,
    );
    if (key != null) {
      await _box.delete(key);
    }
  }

  /// -------------------------------
  /// Query Helpers
  /// -------------------------------
  Future<List<Question>> getMCQs({
    required String className,
    required String subject,
    required String unit,
  }) async {
    return _box.values.where((q) =>
    q.selectedClass.equalsIgnoreCase(className) &&
        q.subject.equalsIgnoreCase(subject) &&
        q.selectedUnit.equalsIgnoreCase(unit) &&
        q.options != null &&
        q.options!.isNotEmpty &&
        q.correctAnswer != null).toList();
  }

  Future<List<Question>> getShortQuestions({
    required String className,
    required String subject,
    required String unit,
  }) async {
    return _box.values.where((q) =>
    q.selectedClass.equalsIgnoreCase(className) &&
        q.subject.equalsIgnoreCase(subject) &&
        q.selectedUnit.equalsIgnoreCase(unit) &&
        (q.options == null || q.options!.isEmpty) &&
        q.answer != null).toList();
  }

  Future<List<Question>> getUnitQuestions({
    required String className,
    required String subject,
    required String unit,
  }) async {
    return _box.values.where((q) =>
    q.selectedClass.equalsIgnoreCase(className) &&
        q.subject.equalsIgnoreCase(subject) &&
        q.selectedUnit.equalsIgnoreCase(unit)).toList();
  }

  /// -------------------------------
  /// Seed Questions (from sample_question.dart, only once)
  /// -------------------------------
  Future<void> seedQuestions() async {
    if (_box.isNotEmpty) return; // Prevent duplicate seeding

    for (final classEntry in questionsData.entries) {
      for (final subjectEntry in classEntry.value.entries) {
        final units = subjectEntry.value as Map<String, List<Question>>;
        for (final unitEntry in units.entries) {
          for (final q in unitEntry.value) {
            await addQuestion(q);
          }
        }
      }
    }
  }

  /// -------------------------------
  /// Add new questions on app update
  /// -------------------------------
  Future<void> addNewQuestions() async {
    // Loop through all questions in sample_question.dart
    for (final classEntry in questionsData.entries) {
      for (final subjectEntry in classEntry.value.entries) {
        final units = subjectEntry.value as Map<String, List<Question>>;
        for (final unitEntry in units.entries) {
          for (final q in unitEntry.value) {
            // Only add if question with same id doesn't exist
            await addQuestion(q);
          }
        }
      }
    }
  }
}
