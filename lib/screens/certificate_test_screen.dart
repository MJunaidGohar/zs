import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/question.dart';
import '../services/google_sheets_content_service.dart';
import '../utils/app_theme.dart';
import '../utils/text_direction_helper.dart';
import 'certificate_result_screen.dart';

/// Certificate Test Screen - Comprehensive test for a topic
/// Loads all MCQs from all levels and subtopics for the selected topic
class CertificateTestScreen extends StatefulWidget {
  final String selectedTopic;

  const CertificateTestScreen({
    super.key,
    required this.selectedTopic,
  });

  @override
  State<CertificateTestScreen> createState() => _CertificateTestScreenState();
}

class _CertificateTestScreenState extends State<CertificateTestScreen> {
  final GoogleSheetsContentService _sheetsService = GoogleSheetsContentService();
  
  List<Question> _questions = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  int _currentQuestionIndex = 0;
  int _score = 0;
  int _correctAnswers = 0;
  int _wrongAnswers = 0;
  String? _selectedAnswer;
  bool _hasAnswered = false;
  Map<int, String> _userAnswers = {}; // questionIndex -> selectedAnswer

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      // Ensure service is initialized
      if (!_sheetsService.isInitialized) {
        await _sheetsService.initialize();
      }

      // Load all questions for this topic across all levels
      final allQuestions = await _sheetsService.loadAllTestQuestionsForTopic(widget.selectedTopic);

      // Shuffle and limit to manageable number (max 50 questions)
      allQuestions.shuffle();
      final limitedQuestions = allQuestions.take(50).toList();

      // Shuffle options for each question
      for (final question in limitedQuestions) {
        question.options?.shuffle();
      }

      if (mounted) {
        setState(() {
          _questions = limitedQuestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load questions: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _showExitConfirmation,
        ),
        title: Column(
          children: [
            Text(
              '${widget.selectedTopic} Certificate',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (!_isLoading && _questions.isNotEmpty)
              Text(
                'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.gradientHeader,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _buildContent(isDark, theme),
    );
  }

  Widget _buildContent(bool isDark, ThemeData theme) {
    if (_isLoading) {
      return _buildLoadingState(isDark, theme);
    }

    if (_errorMessage != null) {
      return _buildErrorState(isDark, theme);
    }

    if (_questions.isEmpty) {
      return _buildEmptyState(isDark, theme);
    }

    if (_currentQuestionIndex >= _questions.length) {
      // Test completed, navigate to result
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToResult();
      });
      return const SizedBox.shrink();
    }

    return _buildQuestionView(isDark, theme);
  }

  Widget _buildLoadingState(bool isDark, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Loading certificate test questions...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This may take a moment',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadQuestions();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No questions available for this topic.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionView(bool isDark, ThemeData theme) {
    final question = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Question Card
          Expanded(
            child: SingleChildScrollView(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  side: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question Number Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.gradientHeader,
                          ),
                          borderRadius: BorderRadius.circular(AppBorderRadius.md),
                        ),
                        child: Text(
                          'Q${_currentQuestionIndex + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      // Question Text
                      Text(
                        question.questionText,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                        textDirection: TextDirectionHelper.getTextDirection(question.questionText),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      // Options
                      if (question.options != null && question.options!.isNotEmpty)
                        ...question.options!.asMap().entries.map((entry) {
                          final index = entry.key;
                          final option = entry.value;
                          return _buildOptionCard(option, index, isDark, theme);
                        }),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Next Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _hasAnswered ? _nextQuestion : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                ),
                disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
              ),
              child: Text(
                _currentQuestionIndex < _questions.length - 1 ? 'Next Question' : 'View Results',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(String option, int index, bool isDark, ThemeData theme) {
    final isSelected = _selectedAnswer == option;
    final isCorrect = option == _questions[_currentQuestionIndex].correctAnswer;
    final showCorrect = _hasAnswered && isCorrect;
    final showWrong = _hasAnswered && isSelected && !isCorrect;

    Color borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    Color backgroundColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    Color textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    if (showCorrect) {
      borderColor = AppColors.success;
      backgroundColor = AppColors.success.withValues(alpha: isDark ? 0.2 : 0.1);
    } else if (showWrong) {
      borderColor = AppColors.error;
      backgroundColor = AppColors.error.withValues(alpha: isDark ? 0.2 : 0.1);
    } else if (isSelected && !_hasAnswered) {
      borderColor = AppColors.primary;
      backgroundColor = AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: _hasAnswered ? null : () => _selectAnswer(option),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            border: Border.all(
              color: borderColor,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: showCorrect
                      ? AppColors.success
                      : showWrong
                          ? AppColors.error
                          : isSelected
                              ? AppColors.primary
                              : isDark
                                  ? Colors.grey[700]
                                  : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + index), // A, B, C, D
                    style: TextStyle(
                      color: (isSelected || showCorrect || showWrong)
                          ? Colors.white
                          : isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.bold,
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
                  textDirection: TextDirectionHelper.getTextDirection(option),
                ),
              ),
              if (showCorrect)
                const Icon(Icons.check_circle, color: AppColors.success)
              else if (showWrong)
                const Icon(Icons.cancel, color: AppColors.error),
            ],
          ),
        ),
      ),
    );
  }

  void _selectAnswer(String answer) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedAnswer = answer;
      _hasAnswered = true;
      _userAnswers[_currentQuestionIndex] = answer;
      
      if (answer == _questions[_currentQuestionIndex].correctAnswer) {
        _correctAnswers++;
        _score++;
      } else {
        _wrongAnswers++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _hasAnswered = false;
      });
    } else {
      _navigateToResult();
    }
  }

  void _navigateToResult() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CertificateResultScreen(
          topic: widget.selectedTopic,
          totalQuestions: _questions.length,
          correctAnswers: _correctAnswers,
          wrongAnswers: _wrongAnswers,
          score: _score,
          questions: _questions,
          userAnswers: _userAnswers,
        ),
      ),
    );
  }

  void _showExitConfirmation() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        ),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        title: Text(
          'Exit Test?',
          style: TextStyle(
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        content: Text(
          'Your progress will be lost. Are you sure you want to exit?',
          style: TextStyle(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
