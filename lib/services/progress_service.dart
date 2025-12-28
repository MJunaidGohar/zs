// lib/services/progress_service.dart
import 'package:hive/hive.dart';

class ProgressService {
  static const String _boxName = 'progress'; // unified name

  Future<Box> _openBox() async {
    return Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
  }

  // -------------------------------
  // 🔹 UNIT LEVEL PROGRESS
  // -------------------------------

  Future<void> saveUnitProgress(String unitId, bool completed) async {
    final box = await _openBox();
    await box.put('unit_${unitId.toLowerCase()}', completed);
    if (completed) {
      await box.put('unit_${unitId.toLowerCase()}_ts', DateTime.now().toIso8601String());
    } else {
      await box.delete('unit_${unitId.toLowerCase()}_ts');
    }
  }

  Future<bool> loadUnitProgress(String unitId) async {
    final box = await _openBox();
    return box.get('unit_${unitId.toLowerCase()}', defaultValue: false) ?? false;
  }

  /// 🔹 Load timestamp for a completed unit
  Future<DateTime?> loadUnitTimestamp(String unitId) async {
    final box = await _openBox();
    final tsString = box.get('unit_${unitId.toLowerCase()}_ts');
    if (tsString == null) return null;
    return DateTime.tryParse(tsString);
  }

  Future<List<String>> getCompletedUnitIds() async {
    final box = await _openBox();
    final completed = <String>[];

    for (final key in box.keys) {
      if (key.toString().startsWith('unit_') && !key.toString().endsWith('_ts')) {
        final value = box.get(key) ?? false;
        if (value) completed.add(key.toString().substring(5)); // strip "unit_"
      }
    }
    return completed;
  }

  Future<Map<String, Map<String, List<String>>>> getCompletedUnitsGrouped() async {
    final completed = await getCompletedUnitIds();
    final Map<String, Map<String, List<String>>> grouped = {};

    for (final unitId in completed) {
      final tokens = unitId.split('_');
      if (tokens.length < 3) {
        grouped.putIfAbsent('unknown', () => {})
            .putIfAbsent('unknown', () => [])
            .add(unitId);
        continue;
      }

      final cls = tokens[0].toLowerCase();
      final subj = tokens[1].toLowerCase();
      final unit = tokens.sublist(2).join('_').toLowerCase();

      grouped.putIfAbsent(cls, () => {});
      grouped[cls]!.putIfAbsent(subj, () => []);
      grouped[cls]![subj]!.add(unit);
    }
    return grouped;
  }

  Future<int> countCompletedFor(String className, String subject) async {
    final grouped = await getCompletedUnitsGrouped();
    final clsMap = grouped[className.toLowerCase()];
    if (clsMap == null) return 0;
    final list = clsMap[subject.toLowerCase()];
    return list?.length ?? 0;
  }

  // -------------------------------
  // 🔹 QUESTION LEVEL PROGRESS
  // -------------------------------

  Future<void> saveQuestionProgress(String questionId, bool completed) async {
    final box = await _openBox();
    await box.put('q_${questionId.toLowerCase()}', completed);
  }

  Future<bool> loadQuestionProgress(String questionId) async {
    final box = await _openBox();
    return box.get('q_${questionId.toLowerCase()}', defaultValue: false) ?? false;
  }

  Future<List<String>> getCompletedQuestionIds() async {
    final box = await _openBox();
    return box.keys
        .where((k) => k.toString().startsWith('q_'))
        .where((k) => box.get(k) ?? false)
        .map((k) => k.toString().substring(2)) // strip "q_"
        .toList();
  }

  // -------------------------------
  // 🔹 CLEAR ALL
  // -------------------------------

  Future<void> clearAllProgress() async {
    final box = await _openBox();
    await box.clear();
  }
}

/// Singleton helpers
final ProgressService _progressService = ProgressService();

// Unit helpers
Future<void> saveUnitProgress(String unitId, bool completed) =>
    _progressService.saveUnitProgress(unitId, completed);
Future<bool> loadUnitProgress(String unitId) =>
    _progressService.loadUnitProgress(unitId);
Future<DateTime?> loadUnitTimestamp(String unitId) =>
    _progressService.loadUnitTimestamp(unitId);
Future<List<String>> getCompletedUnitIds() =>
    _progressService.getCompletedUnitIds();
Future<Map<String, Map<String, List<String>>>> getCompletedUnitsGrouped() =>
    _progressService.getCompletedUnitsGrouped();
Future<int> countCompletedFor(String className, String subject) =>
    _progressService.countCompletedFor(className, subject);

// Question helpers
Future<void> saveQuestionProgress(String questionId, bool completed) =>
    _progressService.saveQuestionProgress(questionId, completed);
Future<bool> loadQuestionProgress(String questionId) =>
    _progressService.loadQuestionProgress(questionId);
Future<List<String>> getCompletedQuestionIds() =>
    _progressService.getCompletedQuestionIds();

// Clear all
Future<void> clearAllProgress() => _progressService.clearAllProgress();
