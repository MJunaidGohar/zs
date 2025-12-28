import 'package:hive/hive.dart';
import '../models/attempt.dart';
import '../models/question.dart';

class HiveService {
  static final HiveService _instance = HiveService._internal();

  HiveService._internal();

  factory HiveService() => _instance;

  static late Box<Attempt> _attemptsBox;
  static late Box<Question> _wrongQuestionsBox;
  static late Box<int> _pointsBox;
  static late Box<Question> _questionsBox;
  static late Box _settingsBox;
  static late Box _progressBox;

  static Box<Attempt> get attemptsBox => _attemptsBox;
  static Box<Question> get wrongQuestionsBox => _wrongQuestionsBox;
  static Box<int> get pointsBox => _pointsBox;
  static Box<Question> get questionsBox => _questionsBox;
  static Box get settingsBox => _settingsBox;
  static Box get progressBox => _progressBox;

  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(AttemptAdapter().typeId)) {
      Hive.registerAdapter(AttemptAdapter());
    }
    if (!Hive.isAdapterRegistered(QuestionAdapter().typeId)) {
      Hive.registerAdapter(QuestionAdapter());
    }

    // Open boxes only if not already open
    _attemptsBox = Hive.isBoxOpen('attemptsBox')
        ? Hive.box<Attempt>('attemptsBox')
        : await Hive.openBox<Attempt>('attemptsBox');

    _wrongQuestionsBox = Hive.isBoxOpen('wrongQuestionsBox')
        ? Hive.box<Question>('wrongQuestionsBox')
        : await Hive.openBox<Question>('wrongQuestionsBox');

    _pointsBox = Hive.isBoxOpen('pointsBox')
        ? Hive.box<int>('pointsBox')
        : await Hive.openBox<int>('pointsBox');

    _questionsBox = Hive.isBoxOpen('questions')
        ? Hive.box<Question>('questions')
        : await Hive.openBox<Question>('questions');

    _settingsBox = Hive.isBoxOpen('settings')
        ? Hive.box('settings')
        : await Hive.openBox('settings');

    _progressBox = Hive.isBoxOpen('progress')
        ? Hive.box('progress')
        : await Hive.openBox('progress');
  }

  /// 🔹 Clear all user history: attempts, wrong questions, progress, points, and user profile
  static Future<void> clearHistory() async {
    try {
      await _attemptsBox.clear();        // All test attempts
      await _wrongQuestionsBox.clear();  // Wrong questions history
      await _progressBox.clear();        // Unit & question progress
      await _pointsBox.clear();          // Points/score

      // If you also store user profile separately
      if (Hive.isBoxOpen('user')) {
        await Hive.box('user').clear();
      } else {
        final userBox = await Hive.openBox('user');
        await userBox.clear();
      }
    } catch (e) {
      print("❌ Error clearing history: $e");
    }
  }
}
