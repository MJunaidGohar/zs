#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Google Sheets to JSON Converter
/// 
/// This is a PROVEN, production-safe method for content management.
/// 
/// Setup:
/// 1. Create a Google Sheet with your content
/// 2. File → Share → Anyone with link can VIEW
/// 3. Copy the Sheet ID from URL: .../d/{SHEET_ID}/...
/// 4. Add sheet ID below and run this script
/// 
/// Sheet Structure (column headers in row 1):
/// topic | level | subtopic | question | answer | option_a | option_b | option_c | option_d | correct_option
///
/// Usage:
///   dart run tool_scripts/gsheet_to_json.dart
/// 
/// This downloads the sheet as CSV and converts to JSON automatically.

/// Google Sheet IDs - Two separate sheets for Study and Test
const String studySheetId = '1zkYzx9K4xz8RXCrxbUEaFRG6IEnqyAs007-Zv_H-Blg';  // Study Data
const String testSheetId = '1EBd97At5nr1yKa6gBmZsUuOuoGTMGmJQq7vNSMA5-BI';   // Test Data (MCQs)

const String outputDir = 'assets/content';

void main() async {
  print('📊 Google Sheets to JSON Converter');
  print('   Study Sheet: $studySheetId');
  print('   Test Sheet: $testSheetId');
  print('=' * 50);

  // Clear previous data
  _questionsByPath.clear();

  // Process Study sheet
  print('\n📄 Processing Study Sheet...');
  try {
    await processStudySheet(studySheetId);
    print('   ✅ Study sheet processed');
  } catch (e) {
    print('   ❌ Error processing study sheet: $e');
  }

  // Process Test sheet (MCQs)
  print('\n📄 Processing Test Sheet (MCQs)...');
  try {
    await processTestSheet(testSheetId);
    print('   ✅ Test sheet processed');
  } catch (e) {
    print('   ❌ Error processing test sheet: $e');
  }

  // Save all questions
  await saveAllQuestions();

  print('');
  print('✅ Complete!');
  print('📁 Output: $outputDir');
}

Future<void> processStudySheet(String sheetId) async {
  final url = 'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv';
  await processSheetUrl(url, 'Study', isTest: false);
}

Future<void> processTestSheet(String sheetId) async {
  final url = 'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv';
  await processSheetUrl(url, 'Test', isTest: true);
}

Future<void> processSheetUrl(String url, String type, {required bool isTest}) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw Exception('Failed to fetch: HTTP ${response.statusCode}');
  }

  final csvContent = response.body;
  final lines = csvContent.split('\n');
  if (lines.length < 2) {
    print('   ⚠️  $type sheet is empty');
    return;
  }

  final headers = _parseCsvLine(lines.first);
  final questions = <Map<String, dynamic>>[];
  int skippedCount = 0;

  for (var i = 1; i < lines.length; i++) {
    final row = _parseCsvLine(lines[i]);
    if (row.isEmpty || row.every((c) => c.isEmpty)) continue;

    final map = <String, String>{};
    for (var j = 0; j < headers.length; j++) {
      if (j < row.length) {
        map[headers[j].toLowerCase().trim()] = row[j].trim();
      }
    }

    final topic = (map['topic'] ?? 'unknown').toLowerCase();
    final level = (map['level'] ?? 'basic').toLowerCase();
    final subtopic = (map['subtopic'] ?? 'general').toLowerCase().replaceAll(' ', '_');

    map['topic'] = map['topic'] ?? topic;
    map['level'] = map['level'] ?? level;
    map['subtopic'] = map['subtopic'] ?? subtopic.replaceAll('_', ' ');

    // VALIDATION: Test sheet must contain MCQ data (options)
    if (isTest) {
      final hasOptions = map['option_a']?.isNotEmpty == true || map['option_b']?.isNotEmpty == true;
      final hasCorrectOption = map['correct_option']?.isNotEmpty == true;

      if (!hasOptions || !hasCorrectOption) {
        skippedCount++;
        continue;
      }
    }

    questions.add(map);

    // Group questions by path
    final key = '$topic/$level/$subtopic';
    if (!_questionsByPath.containsKey(key)) {
      _questionsByPath[key] = {'study': [], 'test': []};
    }
    _questionsByPath[key]![type.toLowerCase()]!.add(map);
  }

  if (skippedCount > 0) {
    print('   ⚠️  $type: $skippedCount questions skipped (missing options)');
  }
  print('   ✓ $type: ${questions.length} valid questions');
}

Future<void> saveAllQuestions() async {
  if (_questionsByPath.isEmpty) {
    print('   ⚠️  No questions to save');
    return;
  }
  
  int filesCreated = 0;
  
  for (final entry in _questionsByPath.entries) {
    final key = entry.key;
    final data = entry.value;
    final parts = key.split('/');
    
    if (parts.length != 3) continue;
    
    final topic = parts[0];
    final level = parts[1];
    final subtopic = parts[2];
    
    // Save study.json
    final studyQuestions = data['study'] ?? [];
    if (studyQuestions.isNotEmpty) {
      final studyPath = path.join(
        outputDir,
        topic,
        level,
        subtopic,
        'study.json',
      );
      await _saveJson(studyPath, studyQuestions);
      print('   ✓ $key/study.json: ${studyQuestions.length} questions');
      filesCreated++;
    }
    
    // Save test.json
    final testQuestions = data['test'] ?? [];
    if (testQuestions.isNotEmpty) {
      final testPath = path.join(
        outputDir,
        topic,
        level,
        subtopic,
        'test.json',
      );
      await _saveJson(testPath, testQuestions);
      print('   ✓ $key/test.json: ${testQuestions.length} questions');
      filesCreated++;
    } else {
      print('   ⚠️  $key/test.json: NO VALID MCQs (Test tab missing options/correct_option)');
    }
  }
  
  print('   📁 Total files created: $filesCreated');
}

final Map<String, Map<String, List<Map<String, dynamic>>>> _questionsByPath = {};

Future<void> _saveJson(String filePath, List<dynamic> data) async {
  final file = File(filePath);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(data)
  );
}

List<String> _parseCsvLine(String line) {
  final result = <String>[];
  final buffer = StringBuffer();
  bool inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];

    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
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
