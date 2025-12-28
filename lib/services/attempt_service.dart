import '../models/attempt.dart';
import 'hive_service.dart';
import '../utils/string_extensions.dart';

class AttemptService {
  final _box = HiveService.attemptsBox;

  Future<List<Attempt>> getAttempts() async {
    return _box.values.toList();
  }

  Future<void> saveOrUpdateAttempt(Attempt attempt) async {
    // Find existing attempt by matching key fields
    final index = _box.values.cast<Attempt>().toList().indexWhere((a) =>
    a.selectedClass.equalsIgnoreCase(attempt.selectedClass) &&
        a.selectedCategory.equalsIgnoreCase(attempt.selectedCategory) &&
        a.subject.equalsIgnoreCase(attempt.subject) &&
        a.selectedUnit.equalsIgnoreCase(attempt.selectedUnit) &&
        a.questionType == attempt.questionType);

    if (index != -1) {
      final key = _box.keyAt(index);
      await _box.put(key, attempt); // safer than putAt
    } else {
      await _box.add(attempt);
    }
  }

  Future<void> clearAttempts() async {
    await _box.clear();
  }
}
