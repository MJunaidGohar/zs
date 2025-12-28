import 'package:hive/hive.dart';
import '../models/question.dart';
import 'hive_service.dart';

class HiveDataService {
  static const String _boxName = 'questions';
  Box<Question>? _box;

  Future<Box<Question>> _getBox() async {
    if (_box != null) return _box!;
    _box = HiveService.questionsBox;
    return _box!;
  }

  Future<void> addQuestion(Question question) async {
    final box = await _getBox();
    bool exists = box.values.any((q) => q.id == question.id);
    if (!exists) {
      await box.add(question);
    }
  }

  Future<List<Question>> getAllQuestions() async {
    final box = await _getBox();
    return box.values.toList();
  }

  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }
}
