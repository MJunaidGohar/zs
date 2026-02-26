import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/question.dart';
import '../models/attempt.dart';
import '../services/attempt_service.dart';
import '../services/wrong_questions_service.dart';
import '../screens/result_screen.dart';
import '../widgets/top_bar_scaffold.dart';
import '../services/question_service.dart';
import '../utils/app_theme.dart';


class TestScreen extends StatefulWidget {
  final String selectedTopic;
  final String selectedLevel;
  final String selectedSubtopic;
  final String selectedCategory;
  final String selectedQuestionType;
  final List<Question>? onlyWrongQuestions;

  const TestScreen({
    super.key,
    required this.selectedTopic,
    required this.selectedLevel,
    required this.selectedSubtopic,
    required this.selectedCategory,
    required this.selectedQuestionType,
    this.onlyWrongQuestions,
  });

  @override
  State<TestScreen> createState() => _TestScreenState();
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
    debugPrint('🔍 [TestScreen._loadQuestions] Starting...');
    debugPrint('🔍 onlyWrongQuestions: ${widget.onlyWrongQuestions?.length ?? 'null'}');
    
    final questionService = QuestionService();

    if (widget.onlyWrongQuestions != null && widget.onlyWrongQuestions!.isNotEmpty) {
      // ✅ Retry mode: use only wrong questions
      debugPrint('🔍 Processing ${widget.onlyWrongQuestions!.length} wrong questions...');
      
      final filtered = widget.onlyWrongQuestions!.where((q) {
        final hasOptions = q.options != null && q.options!.isNotEmpty;
        debugPrint('🔍 Question ${q.id}: options=${q.options}, hasOptions=$hasOptions');
        return hasOptions;
      }).toList();
      
      debugPrint('🔍 After filtering, ${filtered.length} questions remain');
      
      questions = filtered.map((q) {
        final newQ = Question(
          id: q.id,
          questionText: q.questionText,
          options: q.options != null ? List<String>.from(q.options!) : null,
          correctAnswer: q.correctAnswer,
          answer: q.answer,
          topic: q.topic ?? q.selectedClass,
          level: q.level ?? q.subject,
          subtopic: q.subtopic ?? q.selectedUnit,
        );
        debugPrint('🔍 Created Question: topic=${newQ.topic}, level=${newQ.level}, subtopic=${newQ.subtopic}');
        return newQ;
      }).toList();
      
      for (final q in questions) {
        q.options?.shuffle();
      }
      
      debugPrint('🔍 Final questions list: ${questions.length} questions');
    } else {
      // ✅ Load MCQs from JSON assets
      final mcqs = await questionService.loadTestQuestions(
        topic: widget.selectedTopic,
        level: widget.selectedLevel,
        subtopic: widget.selectedSubtopic,
      );

      // Deep copy so shuffling options does not mutate Hive-backed objects
      questions = mcqs
          .map((q) => Question(
                id: q.id,
                questionText: q.questionText,
                options: q.options != null ? List<String>.from(q.options!) : null,
                correctAnswer: q.correctAnswer,
                answer: q.answer,
                topic: q.topic ?? q.selectedClass,
                level: q.level ?? q.subject,
                subtopic: q.subtopic ?? q.selectedUnit,
              ))
          .toList();

      questions.shuffle();
      for (final q in questions) {
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
            topic: widget.selectedTopic,
            selectedCategory: widget.selectedCategory,
            level: widget.selectedLevel,
            subtopic: widget.selectedSubtopic,
            questionType: widget.selectedQuestionType,
            score: score,
            total: questions.length,
          );

          await _attemptService.saveOrUpdateAttempt(attempt);

          debugPrint('🔍 [TestScreen] Saving ${wrongQuestions.length} wrong questions...');
          if (wrongQuestions.isNotEmpty) {
            for (var q in wrongQuestions) {
              debugPrint('🔍 Saving wrong question: ${q.id}, topic=${q.topic}, level=${q.level}, subtopic=${q.subtopic}');
            }
            await _wrongService.saveWrongQuestions(wrongQuestions);
            debugPrint('🔍 Wrong questions saved successfully');
          }

          if (widget.onlyWrongQuestions != null) {
            debugPrint('🔍 [TestScreen] This was a retry attempt - removing corrected questions...');
            final corrected = widget.onlyWrongQuestions!
                .where((q) => !wrongQuestions.any((w) => w.id == q.id))
                .toList();
            debugPrint('🔍 Corrected questions: ${corrected.length}');
            if (corrected.isNotEmpty) {
              await _wrongService.removeCorrectedQuestions(corrected);
              debugPrint('🔍 Removed corrected questions from storage');
            }
          }
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
            selectedTopic: widget.selectedTopic,
            selectedCategory: widget.selectedCategory,
            selectedLevel: widget.selectedLevel,
            selectedQuestionType: widget.selectedQuestionType,
            selectedSubtopic: widget.selectedSubtopic,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (questions.isEmpty) {
      return TopBarScaffold(
        title: 'Test Mode',
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.backgroundDark, Color(0xFF1E1B4B)],
                  )
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.backgroundLight, Color(0xFFE0E7FF)],
                  ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark.withValues(alpha: 0.5)
                        : AppColors.surfaceLight.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.medium,
                  ),
                  child: Icon(
                    Icons.quiz_outlined,
                    size: 64,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'No questions available',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Check back later for new content',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = questions[currentIndex];
    final double progressValue = (currentIndex + 1) / questions.length;
    final String progressPercent = (progressValue * 100).toStringAsFixed(0);

    return TopBarScaffold(
      title: '${widget.selectedLevel} - ${widget.selectedSubtopic}',
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.backgroundDark, Color(0xFF1E1B4B)],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.backgroundLight, Color(0xFFE0E7FF)],
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Enhanced Question Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? const [Color(0xFF312E81), Color(0xFF4C1D95)]
                              : AppColors.gradientLightHeader,
                        ),
                        borderRadius: BorderRadius.circular(AppBorderRadius.circular),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.help_outline,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            "${currentIndex + 1}/${questions.length}",
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accentYellow.withValues(alpha: 0.3),
                            AppColors.accentOrange.withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppBorderRadius.circular),
                        border: Border.all(
                          color: AppColors.accentYellow.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.stars,
                            size: 16,
                            color: AppColors.accentYellow,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            "$score",
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.accentYellow,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Enhanced Progress Bar
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark.withValues(alpha: 0.5)
                        : AppColors.surfaceLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppBorderRadius.circular),
                        child: LinearProgressIndicator(
                          value: progressValue,
                          backgroundColor: isDark 
                              ? AppColors.dividerDark.withValues(alpha: 0.5)
                              : AppColors.dividerLight.withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? AppColors.primaryLight : AppColors.primary,
                          ),
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        "$progressPercent% completed",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Enhanced Question Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? LinearGradient(
                            colors: [
                              AppColors.surfaceDark,
                              AppColors.surfaceDark.withValues(alpha: 0.9),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isDark ? null : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1),
                        blurRadius: 12,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: AppColors.accentPurple.withValues(alpha: isDark ? 0.3 : 0.2),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accentPurple.withValues(alpha: 0.3),
                              AppColors.accentPurple.withValues(alpha: 0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppBorderRadius.md),
                        ),
                        child: Text(
                          'Question ${currentIndex + 1}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.accentPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        question.questionText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Enhanced Options
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: question.options?.length ?? 0,
                    itemBuilder: (context, index) {
                      final option = question.options![index];
                      final isSelected = selectedAnswer == option;
                      final isCorrect = option == question.correctAnswer;

                      return _buildOptionItem(
                        context,
                        option,
                        isSelected,
                        isCorrect,
                        selectedAnswer,
                        index,
                        isDark,
                        theme,
                      );
                    },
                  ),
                ),

                // Enhanced Next / Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: selectedAnswer != null
                        ? () {
                            HapticFeedback.mediumImpact();
                            nextQuestion();
                          }
                        : null,
                    icon: Icon(
                      currentIndex == questions.length - 1 
                          ? Icons.check_circle
                          : Icons.arrow_forward,
                    ),
                    label: Text(
                      currentIndex == questions.length - 1 ? "Submit Test" : "Next Question",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl, 
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                      ),
                      elevation: selectedAnswer != null ? 4 : 0,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionItem(
    BuildContext context,
    String option,
    bool isSelected,
    bool isCorrect,
    String? selectedAnswer,
    int index,
    bool isDark,
    ThemeData theme,
  ) {
    Color optionColor;
    Color textColor;
    IconData? iconData;
    Gradient? gradient;
    
    if (selectedAnswer != null) {
      if (isSelected && isCorrect) {
        optionColor = AppColors.success;
        textColor = Colors.white;
        iconData = Icons.check_circle;
        gradient = LinearGradient(
          colors: [
            AppColors.success,
            AppColors.accentGreen.withValues(alpha: 0.9),
          ],
        );
      } else if (isSelected && !isCorrect) {
        optionColor = AppColors.error;
        textColor = Colors.white;
        iconData = Icons.cancel;
        gradient = LinearGradient(
          colors: [
            AppColors.error,
            AppColors.error.withValues(alpha: 0.9),
          ],
        );
      } else if (isCorrect) {
        optionColor = AppColors.success.withValues(alpha: 0.3);
        textColor = AppColors.success;
        iconData = Icons.check_circle_outline;
        gradient = LinearGradient(
          colors: [
            AppColors.success.withValues(alpha: 0.2),
            AppColors.success.withValues(alpha: 0.1),
          ],
        );
      } else {
        optionColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
        textColor = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
        iconData = null;
        gradient = null;
      }
    } else {
      optionColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
      textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
      iconData = null;
      gradient = null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GestureDetector(
        onTap: selectedAnswer == null
            ? () {
                HapticFeedback.lightImpact();
                selectAnswer(option);
              }
            : null,
        child: AnimatedContainer(
          duration: AppDurations.normal,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? optionColor : null,
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(
              color: isSelected 
                  ? (isCorrect ? AppColors.success : AppColors.error)
                  : (isDark ? AppColors.dividerDark.withValues(alpha: 0.5) : AppColors.dividerLight.withValues(alpha: 0.5)),
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (isCorrect ? AppColors.success : AppColors.error).withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.accentPurple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + index),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isSelected
                          ? Colors.white
                          : AppColors.accentPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  option,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (iconData != null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconData,
                    color: textColor,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
