import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import '../models/question.dart';
import 'google_sheets_content_service.dart';

/// Service to load content from various sources
/// 
/// Supports:
/// 1. JSON assets (production) - fast, compiled into app
/// 2. CSV files (development) - easier to edit than JSON
/// 3. Google Sheets (runtime) - fetches fresh content from sheets
/// 
/// The app tries JSON first (fast), falls back to CSV, then to Google Sheets
class ContentLoaderService {
  static final ContentLoaderService _instance = ContentLoaderService._internal();
  factory ContentLoaderService() => _instance;
  ContentLoaderService._internal();

  /// Cache for loaded questions
  final Map<String, List<Question>> _cache = {};
  
  /// Google Sheets service for runtime fetching
  final GoogleSheetsContentService _sheetsService = GoogleSheetsContentService();

  /// Load study questions for a specific topic/level/subtopic
  Future<List<Question>> loadStudyQuestions({
    required String topic,
    required String level,
    required String subtopic,
  }) async {
    final cacheKey = '${topic}_${level}_${subtopic}_study';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final questions = await _loadQuestions(
      topic: topic,
      level: level,
      subtopic: subtopic,
      type: 'study',
    );
    
    _cache[cacheKey] = questions;
    return questions;
  }

  /// Load test/MCQ questions for a specific topic/level/subtopic
  Future<List<Question>> loadTestQuestions({
    required String topic,
    required String level,
    required String subtopic,
  }) async {
    final cacheKey = '${topic}_${level}_${subtopic}_test';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final questions = await _loadQuestions(
      topic: topic,
      level: level,
      subtopic: subtopic,
      type: 'test',
    );
    
    _cache[cacheKey] = questions;
    return questions;
  }

  /// Generic question loader with fallback logic
  Future<List<Question>> _loadQuestions({
    required String topic,
    required String level,
    required String subtopic,
    required String type,
  }) async {
    final normalizedTopic = topic.toLowerCase().replaceAll(' ', '_');
    final normalizedLevel = level.toLowerCase().replaceAll(' ', '_');
    final normalizedSubtopic = subtopic.toLowerCase().replaceAll(' ', '_');

    // Try JSON first (fastest, production format)
    final jsonPath = 'assets/content/$normalizedTopic/$normalizedLevel/$normalizedSubtopic/$type.json';
    final jsonQuestions = await _tryLoadJson(jsonPath);
    if (jsonQuestions != null && jsonQuestions.isNotEmpty) {
      return jsonQuestions;
    }

    // Fallback: try CSV format (development/editing format)
    final csvPath = 'assets/content/$normalizedTopic/$normalizedLevel/$normalizedSubtopic/$type.csv';
    final csvQuestions = await _tryLoadCsv(csvPath);
    if (csvQuestions != null && csvQuestions.isNotEmpty) {
      return csvQuestions;
    }

    // Fallback 2: Try Google Sheets at runtime
    if (type == 'study') {
      final sheetsQuestions = await _sheetsService.loadStudyQuestions(
        topic: topic,
        level: level,
        subtopic: subtopic,
      );
      if (sheetsQuestions.isNotEmpty) {
        return sheetsQuestions;
      }
    } else {
      final sheetsQuestions = await _sheetsService.loadTestQuestions(
        topic: topic,
        level: level,
        subtopic: subtopic,
      );
      if (sheetsQuestions.isNotEmpty) {
        return sheetsQuestions;
      }
    }

    // No content found
    return [];
  }

  /// Try to load questions from JSON asset
  Future<List<Question>?> _tryLoadJson(String assetPath) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => Question.fromJson(json as Map<String, dynamic>))
          .where((q) => q.questionText.isNotEmpty)
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Try to load questions from CSV asset
  Future<List<Question>?> _tryLoadCsv(String assetPath) async {
    try {
      final csvString = await rootBundle.loadString(assetPath);
      final lines = csvString.split('\n');
      if (lines.length < 2) return null;

      // Parse headers
      final headers = _parseCsvLine(lines.first);
      if (headers.isEmpty) return null;

      // Parse data rows
      final questions = <Question>[];
      for (var i = 1; i < lines.length; i++) {
        final row = _parseCsvLine(lines[i]);
        if (row.isEmpty || row.every((cell) => cell.isEmpty)) continue;

        final map = <String, String>{};
        for (var j = 0; j < headers.length; j++) {
          if (j < row.length) {
            map[headers[j].toLowerCase()] = row[j];
          }
        }

        final question = _questionFromMap(map);
        if (question.questionText.isNotEmpty) {
          questions.add(question);
        }
      }

      return questions;
    } catch (_) {
      return null;
    }
  }

  /// Parse a CSV line handling quoted values
  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Escaped quote
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    result.add(buffer.toString().trim());
    return result;
  }

  /// Create Question from map (CSV or JSON)
  Question _questionFromMap(Map<String, String> map) {
    // Extract options if present
    List<String>? options;
    if (map.containsKey('option_a') && map['option_a']?.isNotEmpty == true) {
      options = [
        map['option_a'] ?? '',
        map['option_b'] ?? '',
        map['option_c'] ?? '',
        map['option_d'] ?? '',
      ].where((o) => o.isNotEmpty).toList();
    }

    // Convert correct option letter to answer text
    String? correctAnswer;
    final correctOption = map['correct_option']?.toUpperCase();
    if (correctOption != null && options != null && options.isNotEmpty) {
      final index = correctOption.codeUnitAt(0) - 'A'.codeUnitAt(0);
      if (index >= 0 && index < options.length) {
        correctAnswer = options[index];
      }
    }

    return Question(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      questionText: map['question'] ?? '',
      options: options?.isNotEmpty == true ? options : null,
      correctAnswer: correctAnswer,
      answer: map['answer'] ?? map['explanation'] ?? '',
      topic: map['topic'],
      level: map['level'],
      subtopic: map['subtopic'],
    );
  }

  /// Clear cache (useful for hot reload or memory management)
  void clearCache() {
    _cache.clear();
  }

  /// Get cache stats for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_entries': _cache.length,
      'total_questions': _cache.values.fold(0, (sum, list) => sum + list.length),
    };
  }
}
