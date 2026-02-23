import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../models/question.dart';
import 'hive_service.dart';
import 'content_loader_service.dart';
import '../utils/string_extensions.dart';

class QuestionService {
  final Box<Question> _box = HiveService.questionsBox;
  final ContentLoaderService _contentLoader = ContentLoaderService();

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
  /// Query Helpers (DEPRECATED - Use JSON loading instead)
  /// -------------------------------
  @Deprecated('Use loadStudyQuestions() or loadTestQuestions() instead')
  Future<List<Question>> getMCQs({
    required String className,
    required String subject,
    required String unit,
  }) async {
    return _box.values.where((q) =>
    (q.topic ?? q.selectedClass).equalsIgnoreCase(className) &&
        (q.level ?? q.subject).equalsIgnoreCase(subject) &&
        (q.subtopic ?? q.selectedUnit).equalsIgnoreCase(unit) &&
        q.options != null &&
        q.options!.isNotEmpty &&
        q.correctAnswer != null).toList();
  }

  @Deprecated('Use loadStudyQuestions() instead')
  Future<List<Question>> getShortQuestions({
    required String className,
    required String subject,
    required String unit,
  }) async {
    return _box.values.where((q) =>
    (q.topic ?? q.selectedClass).equalsIgnoreCase(className) &&
        (q.level ?? q.subject).equalsIgnoreCase(subject) &&
        (q.subtopic ?? q.selectedUnit).equalsIgnoreCase(unit) &&
        (q.options == null || q.options!.isEmpty) &&
        q.answer != null).toList();
  }

  @Deprecated('Use loadStudyQuestions() or loadTestQuestions() instead')
  Future<List<Question>> getUnitQuestions({
    required String className,
    required String subject,
    required String unit,
  }) async {
    return _box.values.where((q) =>
    (q.topic ?? q.selectedClass).equalsIgnoreCase(className) &&
        (q.level ?? q.subject).equalsIgnoreCase(subject) &&
        (q.subtopic ?? q.selectedUnit).equalsIgnoreCase(unit)).toList();
  }

  /// -------------------------------
  /// Seed Questions (from sample_question.dart, only once)
  /// -------------------------------
  /// Seed initial questions (deprecated - now using asset-based content)
  /// -------------------------------
  Future<void> seedQuestions() async {
    // No-op: Content is now loaded from assets via ContentLoaderService
    return;
  }

  /// -------------------------------
  /// Add new questions on app update (deprecated)
  /// -------------------------------
  Future<void> addNewQuestions() async {
    // No-op: Content is now loaded from assets via ContentLoaderService
    return;
  }

  // ====================
  // Content Loading (via ContentLoaderService)
  // ====================

  /// Load study questions from JSON/CSV assets
  Future<List<Question>> loadStudyQuestions({
    required String topic,
    required String level,
    required String subtopic,
  }) async {
    return _contentLoader.loadStudyQuestions(
      topic: topic,
      level: level,
      subtopic: subtopic,
    );
  }

  /// Load test/MCQ questions from JSON/CSV assets
  Future<List<Question>> loadTestQuestions({
    required String topic,
    required String level,
    required String subtopic,
  }) async {
    return _contentLoader.loadTestQuestions(
      topic: topic,
      level: level,
      subtopic: subtopic,
    );
  }

  // ====================
  // Data Configuration
  // ====================

  static const List<String> topics = ['English', 'YouTube', 'Computer', 'Digital Marketing', 'Web Development'];
  static const List<String> levels = ['Basic', 'Intermediate', 'Advanced', 'Pro Master'];

  static List<String> getSubtopics(String topic) {
    switch (topic) {
      case 'English': return ['Learning', 'Speaking', 'Writing', 'Listening'];
      case 'YouTube': return ['Shorts', 'Long Videos'];
      case 'Digital Marketing': return ['Google Ads', 'Meta Ads'];
      case 'Web Development': return ['Wix', 'Shopify', 'WordPress'];
      case 'Computer': return ['Basics', 'MS Office'];
      default: return [];
    }
  }
}

