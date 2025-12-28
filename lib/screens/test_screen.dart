import 'package:flutter/material.dart';
import '../models/question.dart';
import '../models/attempt.dart';
import '../services/attempt_service.dart';
import '../services/progress_service.dart';
import '../services/wrong_questions_service.dart';
import '../screens/result_screen.dart';
import '../widgets/top_bar_scaffold.dart';
import '../services/question_service.dart';
import '../utils/string_extensions.dart';


class TestScreen extends StatefulWidget {
  final String selectedClass;
  final String selectedCategory;
  final String selectedSubject;
  final String selectedQuestionType; // Always "MCQs"
  final String selectedUnit;
  final List<Question>? onlyWrongQuestions; // Optional: Retry wrong questions

  const TestScreen({
    super.key,
    required this.selectedClass,
    required this.selectedCategory,
    required this.selectedSubject,
    required this.selectedQuestionType,
    required this.selectedUnit,
    this.onlyWrongQuestions,
  });

  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> with SingleTickerProviderStateMixin {
  List<Question> questions = [];
  int currentIndex = 0;
  int score = 0;
  String? selectedAnswer;
  List<Question> wrongQuestions = [];
  final AttemptService _attemptService = AttemptService();
  final WrongQuestionsService _wrongService = WrongQuestionsService();

  bool _markedComplete = false;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    _loadQuestionsAsync();
  }

  Future<void> _loadQuestionsAsync() async {
    await _loadQuestions();
  }

  /// Loads questions either from wrong list or filters MCQs from all questions
  Future<void> _loadQuestions() async {
    final questionService = QuestionService();

    if (widget.onlyWrongQuestions != null && widget.onlyWrongQuestions!.isNotEmpty) {
      // ✅ Retry mode: use only wrong questions
      questions = widget.onlyWrongQuestions!
          .where((q) => q.options != null && q.options!.isNotEmpty)
          .toList();
      for (var q in questions) {
        q.options?.shuffle();
      }
    } else {
      // ✅ Load ALL questions from Hive
      final allQuestions = await questionService.getQuestions();

      // ✅ Filter only this class + subject + unit
      final unitQuestions = allQuestions.where((q) =>
      q.selectedClass.equalsIgnoreCase(widget.selectedClass) &&
          q.subject.equalsIgnoreCase(widget.selectedSubject) &&
          q.selectedUnit.equalsIgnoreCase(widget.selectedUnit)
      );

      // ✅ Then filter only MCQs (questions with options)
      questions = unitQuestions
          .where((q) => q.options != null && q.options!.isNotEmpty)
          .toList();

      questions.shuffle();
      for (var q in questions) {
        q.options?.shuffle();
      }
    }

    if (mounted) setState(() {});
  }

  void selectAnswer(String answer) {
    if (selectedAnswer != null) return;
    setState(() {
      selectedAnswer = answer;
    });

    final currentQ = questions[currentIndex];
    if (answer == currentQ.correctAnswer) {
      score++;
    } else {
      wrongQuestions.add(currentQ);
    }
  }

  Future<void> nextQuestion() async {
    if (selectedAnswer == null) return;

    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
        selectedAnswer = null;
      });
      _controller.forward(from: 0);
    } else {
      if (!_markedComplete) {
        _markedComplete = true;

        try {
          final attempt = Attempt(
            selectedClass: widget.selectedClass,
            selectedCategory: widget.selectedCategory,
            subject: widget.selectedSubject,
            selectedUnit: widget.selectedUnit,
            questionType: widget.selectedQuestionType,
            score: score,
            total: questions.length,
          );

          await _attemptService.saveOrUpdateAttempt(attempt);

          if (wrongQuestions.isNotEmpty) {
            await _wrongService.saveWrongQuestions(wrongQuestions);
          }

          if (widget.onlyWrongQuestions != null) {
            final corrected = widget.onlyWrongQuestions!
                .where((q) => !wrongQuestions.any((w) => w.id == q.id))
                .toList();
            if (corrected.isNotEmpty) {
              await _wrongService.removeCorrectedQuestions(corrected);
            }
          }

          final unitKey = "${widget.selectedClass}_${widget.selectedSubject}_${widget.selectedUnit}".toLowerCase();
          await ProgressService().saveUnitProgress(unitKey, true);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving results: $e')),
          );
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            score: score,
            total: questions.length,
            selectedClass: widget.selectedClass,
            selectedCategory: widget.selectedCategory,
            selectedSubject: widget.selectedSubject,
            selectedQuestionType: widget.selectedQuestionType,
            selectedUnit: widget.selectedUnit,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return TopBarScaffold(
        title: 'Test Mode',
        body: const Center(child: Text('No MCQs available for this unit.')),
      );
    }

    final question = questions[currentIndex];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final double progressValue = (currentIndex + 1) / questions.length;
    final String progressPercent = (progressValue * 100).toStringAsFixed(0);

    return TopBarScaffold(
      title: '${widget.selectedSubject} - ${widget.selectedUnit}',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ---------------- Question Header ----------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Q ${currentIndex + 1}/${questions.length}",
                      style: theme.textTheme.titleMedium),
                  Text("Marks: $score",
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary)),
                ],
              ),
              const SizedBox(height: 10),

              // ---------------- Progress Bar ----------------
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text("$progressPercent% completed",
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),

              // ---------------- Question Card ----------------
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                color: isDark ? Colors.grey[850] : theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    "Q${currentIndex + 1}. ${question.questionText}",
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ---------------- Options ----------------
              Expanded(
                child: ListView.builder(
                  itemCount: question.options?.length ?? 0,
                  itemBuilder: (context, index) {
                    final option = question.options![index];
                    final isSelected = selectedAnswer == option;
                    final isCorrect = option == question.correctAnswer;

                    Color optionColor;
                    if (selectedAnswer != null) {
                      if (isSelected && isCorrect) {
                        optionColor = Colors.green.shade400;
                      } else if (isSelected && !isCorrect) {
                        optionColor = Colors.red.shade400;
                      } else if (isCorrect) {
                        optionColor = Colors.green.shade200;
                      } else {
                        optionColor = theme.colorScheme.surface;
                      }
                    } else {
                      optionColor = theme.colorScheme.surface;
                    }

                    return GestureDetector(
                      onTap: () => selectAnswer(option),
                      child: AnimatedScale(
                        scale: isSelected ? 1.03 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: optionColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.dividerColor,
                                width: 2),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 5,
                                  offset: const Offset(2, 3))
                            ],
                          ),
                          child: Text(
                            option,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: (selectedAnswer != null &&
                                  (isCorrect || isSelected))
                                  ? Colors.white
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ---------------- Next / Submit Button ----------------
              ElevatedButton(
                onPressed: selectedAnswer != null ? nextQuestion : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 7,
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      currentIndex == questions.length - 1 ? "Submit" : "Next",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
