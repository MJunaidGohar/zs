import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/question.dart';
import '../services/question_service.dart';
import '../services/progress_service.dart';
import '../widgets/top_bar_scaffold.dart';
import '../utils/app_theme.dart';
import '../utils/text_direction_helper.dart';
import '../l10n/app_localizations.dart';
import 'dart:math';


// 🔹 Cache for shuffled unit questions (persists during app runtime)
final Map<String, List<Question>> _shuffledCache = {};
const int _maxShuffledCacheEntries = 20;

class LearnScreen extends StatefulWidget {
  final String selectedTopic;
  final String selectedLevel;
  final String selectedSubtopic;
  final String selectedCategory;

  const LearnScreen({
    super.key,
    required this.selectedTopic,
    required this.selectedLevel,
    required this.selectedSubtopic,
    required this.selectedCategory,
  });

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _markedComplete = false;

  late List<Question> _shortQuestions;
  bool _isLoading = true;

  String get _unitKey =>
      "${widget.selectedTopic}_${widget.selectedLevel}_${widget.selectedSubtopic}".toLowerCase();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollEnd);
    _loadQuestions(); // 🔹 Load from Hive
  }

  Future<void> _loadQuestions() async {
    final questionService = QuestionService();

    // Load study questions from JSON assets
    _shortQuestions = await questionService.loadStudyQuestions(
      topic: widget.selectedTopic,
      level: widget.selectedLevel,
      subtopic: widget.selectedSubtopic,
    );

    // 🔹 Shuffle once and cache
    if (_shuffledCache.containsKey(_unitKey)) {
      _shortQuestions = _shuffledCache[_unitKey]!;
    } else {
      _shortQuestions.shuffle(Random(DateTime.now().microsecondsSinceEpoch));
      _shuffledCache[_unitKey] = _shortQuestions;

      if (_shuffledCache.length > _maxShuffledCacheEntries) {
        final oldestKey = _shuffledCache.keys.first;
        _shuffledCache.remove(oldestKey);
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _markCompleteIfNeeded() async {
    if (!_markedComplete) {
      _markedComplete = true;
      await ProgressService().saveUnitProgress(_unitKey, true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).unitCompleted)),
      );
    }
  }

  void _onScrollEnd() async {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      _markCompleteIfNeeded();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollEnd);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark.withValues(alpha: 0.5)
                        : AppColors.surfaceLight.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.medium,
                  ),
                  child: CircularProgressIndicator(
                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  AppLocalizations.of(context).loadingStudyMaterial,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_shortQuestions.isEmpty) {
      return TopBarScaffold(
        title: AppLocalizations.of(context).learnMode,
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
                    Icons.menu_book_outlined,
                    size: 64,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  AppLocalizations.of(context).noStudyMaterialAvailable,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppLocalizations.of(context).checkBackLater,
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
        child: ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: _shortQuestions.length,
          itemBuilder: (context, index) {
            final question = _shortQuestions[index];
            final bool isLast = index == _shortQuestions.length - 1;
            
            Widget questionCard = TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 400 + (index * 50)),
              tween: Tween(begin: 0, end: 1),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                final delayedValue = index > 0 
                    ? ((value * 1000 - (index * 50)) / (1000 - (index * 50))).clamp(0.0, 1.0)
                    : value;
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - delayedValue)),
                  child: Opacity(
                    opacity: delayedValue,
                    child: child,
                  ),
                );
              },
              child: _buildQuestionCard(context, question, index, isLast, isDark, theme),
            );

            // Wrap last question with VisibilityDetector for short lists
            if (isLast) {
              return VisibilityDetector(
                key: Key('last_question_$_unitKey'),
                onVisibilityChanged: (info) {
                  if (info.visibleFraction > 0.5) {
                    _markCompleteIfNeeded();
                  }
                },
                child: questionCard,
              );
            }
            
            return questionCard;
          },
        ),
      ),
    );
  }

  Widget _buildQuestionCard(
    BuildContext context,
    Question question,
    int index,
    bool isLast,
    bool isDark,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
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
          color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.15),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Question Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [
                        Color(0xFF312E81),
                        Color(0xFF4C1D95),
                      ]
                    : AppColors.gradientLightHeader,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppBorderRadius.xxl),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    "Q${index + 1}",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    question.questionText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: Colors.white,
                    ),
                    textDirection: TextDirectionHelper.getTextDirection(question.questionText),
                  ),
                ),
              ],
            ),
          ),
          
          // Enhanced Answer Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark 
                  ? AppColors.backgroundDark 
                  : AppColors.backgroundLight,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppBorderRadius.xxl),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accentYellow.withValues(alpha: 0.3),
                            AppColors.accentOrange.withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                      ),
                      child: Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: AppColors.accentYellow,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      AppLocalizations.of(context).answer,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark ? AppColors.accentYellow : AppColors.accentOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark.withValues(alpha: 0.5)
                        : AppColors.surfaceLight.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    border: Border.all(
                      color: isDark
                          ? AppColors.dividerDark.withValues(alpha: 0.5)
                          : AppColors.dividerLight.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    question.answer ?? AppLocalizations.of(context).noAnswerAvailable,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    textDirection: TextDirectionHelper.getTextDirection(question.answer ?? ''),
                  ),
                ),
              ],
            ),
          ),
          
          // Enhanced Completion indicator
          if (isLast)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.success.withValues(alpha: isDark ? 0.2 : 0.15),
                    AppColors.accentGreen.withValues(alpha: isDark ? 0.1 : 0.05),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppBorderRadius.xxl),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    AppLocalizations.of(context).endOfStudyMaterial,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
