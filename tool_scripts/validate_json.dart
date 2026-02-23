#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

/// JSON Content Validator
/// 
/// This validates your JSON content files for correctness before building.
/// 
/// Usage:
///   dart run tool_scripts/validate_json.dart
/// 
/// Checks:
/// - Valid JSON syntax
/// - Required fields (question, answer/topic/level/subtopic)
/// - No empty questions
/// - Proper data types
/// 
/// This is the SAFEST method: Edit JSON directly and validate before build.

const String contentDir = 'assets/content';

void main() {
  print('🔍 JSON Content Validator');
  print('=' * 50);

  final dir = Directory(contentDir);
  if (!dir.existsSync()) {
    print('❌ Content directory not found: $contentDir');
    exit(1);
  }

  final jsonFiles = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();

  if (jsonFiles.isEmpty) {
    print('⚠️  No JSON files found');
    return;
  }

  print('Found ${jsonFiles.length} JSON file(s)');
  print('');

  int errors = 0;
  int warnings = 0;
  int totalQuestions = 0;

  for (final file in jsonFiles) {
    final relativePath = file.path.replaceFirst(contentDir, '');
    print('📄 $relativePath');

    final result = validateFile(file);
    errors += result.errors;
    warnings += result.warnings;
    totalQuestions += result.questionCount;

    if (result.errors == 0 && result.warnings == 0) {
      print('   ✓ Valid (${result.questionCount} questions)');
    }
  }

  print('');
  print('=' * 50);
  print('📊 Summary:');
  print('   Files: ${jsonFiles.length}');
  print('   Questions: $totalQuestions');
  print('   Errors: $errors');
  print('   Warnings: $warnings');

  if (errors > 0) {
    print('');
    print('❌ Validation FAILED - Fix errors before building');
    exit(1);
  } else if (warnings > 0) {
    print('');
    print('⚠️  Validation passed with warnings');
  } else {
    print('');
    print('✅ All files valid - Ready to build');
  }
}

ValidationResult validateFile(File file) {
  int errors = 0;
  int warnings = 0;
  int questionCount = 0;

  try {
    final content = file.readAsStringSync();
    final jsonList = jsonDecode(content) as List<dynamic>;

    if (jsonList.isEmpty) {
      print('   ⚠️  File is empty (no questions)');
      warnings++;
      return ValidationResult(errors, warnings, 0);
    }

    for (var i = 0; i < jsonList.length; i++) {
      final item = jsonList[i] as Map<String, dynamic>;
      questionCount++;

      // Check required fields
      final questionText = item['question']?.toString() ?? '';
      if (questionText.isEmpty) {
        print('   ❌ Question ${i + 1}: Empty question text');
        errors++;
      }

      // Check answer or options
      final hasAnswer = item['answer']?.toString().isNotEmpty == true ||
                       item['explanation']?.toString().isNotEmpty == true;
      final hasOptions = item['option_a']?.toString().isNotEmpty == true;
      
      if (!hasAnswer && !hasOptions) {
        print('   ❌ Question ${i + 1}: Missing answer and options');
        errors++;
      }

      // Check metadata
      if (item['topic'] == null) {
        print('   ⚠️  Question ${i + 1}: Missing topic');
        warnings++;
      }
      if (item['level'] == null) {
        print('   ⚠️  Question ${i + 1}: Missing level');
        warnings++;
      }
      if (item['subtopic'] == null) {
        print('   ⚠️  Question ${i + 1}: Missing subtopic');
        warnings++;
      }

      // Check for test questions
      if (hasOptions) {
        final correctOption = item['correct_option']?.toString() ?? '';
        if (correctOption.isEmpty) {
          print('   ⚠️  Question ${i + 1}: Has options but no correct_option');
          warnings++;
        }
      }
    }
  } on FormatException catch (e) {
    print('   ❌ Invalid JSON: $e');
    errors++;
  } catch (e) {
    print('   ❌ Error reading file: $e');
    errors++;
  }

  return ValidationResult(errors, warnings, questionCount);
}

class ValidationResult {
  final int errors;
  final int warnings;
  final int questionCount;

  ValidationResult(this.errors, this.warnings, this.questionCount);
}
