// main_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/top_bar_scaffold.dart';
import '../screens/test_screen.dart';
import '../screens/learn_screen.dart';
import '../services/question_service.dart';
import '../services/google_sheets_content_service.dart';
import '../services/progress_service.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';

/// ------------------------------------------------------
/// MainSelectionScreen
/// - User selects Topic -> Level -> Subtopic
/// - Then chooses Test or Learn mode
/// - Subtopics are highlighted if completed
/// ------------------------------------------------------
class MainSelectionScreen extends StatefulWidget {
  const MainSelectionScreen({super.key});

  @override
  State<MainSelectionScreen> createState() => _MainSelectionScreenState();
}

class _MainSelectionScreenState extends State<MainSelectionScreen>
    with SingleTickerProviderStateMixin {
  String? selectedTopic;
  String? selectedLevel;
  String? selectedSubtopic;

  /// Store completion status of subtopics
  Map<String, bool> subtopicCompletion = {};

  final GoogleSheetsContentService _contentService = GoogleSheetsContentService();
  bool _isLoading = true;
  List<String> _availableTopics = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _initializeContent();
    
    // Check notification permission from screen context
    Future.delayed(const Duration(milliseconds: 1000), () {
      NotificationService.checkPermissionFromScreen();
    });
  }

  bool _isFreshDataLoaded = false;
  bool _isUsingCachedData = false;

  Future<void> _initializeContent() async {
    try {
      final freshLoaded = await _contentService.initialize();
      setState(() {
        _availableTopics = _contentService.getAvailableTopics();
        _isLoading = false;
        _isFreshDataLoaded = freshLoaded;
        _isUsingCachedData = _contentService.isUsingCachedData;
      });
      debugPrint('Content initialized. Available topics: $_availableTopics');
      debugPrint('Fresh data loaded: $freshLoaded, Using cached: $_isUsingCachedData');
      
      // Request notification permission after content loads (with proper context)
      _requestNotificationPermissionIfNeeded();
    } catch (e) {
      debugPrint('Error initializing content: $e');
      setState(() {
        _isLoading = false;
      });
    }
    _animationController.forward();
  }

  /// Request notification permission if not already granted
  Future<void> _requestNotificationPermissionIfNeeded() async {
    try {
      debugPrint('🔔 MainScreen: Checking notification permission...');
      final hasPermission = await NotificationService.hasNotificationPermission();
      debugPrint('🔔 MainScreen: Has permission: $hasPermission');
      
      if (!hasPermission) {
        debugPrint('🔔 MainScreen: Requesting permission...');
        // Small delay to ensure UI is ready
        await Future.delayed(const Duration(milliseconds: 500));
        final result = await NotificationService.requestNotificationPermissions();
        debugPrint('🔔 MainScreen: Permission result: $result');
      }
    } catch (e) {
      debugPrint('🔔 MainScreen: Error requesting permission: $e');
    }
  }

  /// Manually refresh data when back online
  Future<void> _refreshData() async {
    if (_contentService.isOnline == false) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await _contentService.refreshData();
      if (success) {
        setState(() {
          _availableTopics = _contentService.getAvailableTopics();
          _isFreshDataLoaded = true;
          _isUsingCachedData = false;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Build a unique key (topic+level+subtopic)
  String _subtopicKey(String subtopic) =>
      "${selectedTopic}_${selectedLevel}_$subtopic";

  /// Get available levels for selected topic (filtered by content availability)
  List<String> getLevelsForTopic() {
    if (selectedTopic == null) return [];
    return _contentService.getAvailableLevelsForTopic(selectedTopic!);
  }

  /// Get available subtopics for selected topic + level (filtered by content availability)
  List<String> getSubtopicsForLevel() {
    if (selectedTopic == null || selectedLevel == null) return [];
    return _contentService.getAvailableSubtopics(selectedTopic!, selectedLevel!);
  }

  /// Load subtopic progress for currently selected topic + level
  Future<void> _loadSubtopicProgress() async {
    if (selectedTopic == null || selectedLevel == null) return;

    final subtopics = getSubtopicsForLevel();
    Map<String, bool> newCompletion = {};

    for (String subtopic in subtopics) {
      bool completed = await loadUnitProgress(_subtopicKey(subtopic));
      newCompletion[subtopic] = completed;
    }

    setState(() {
      subtopicCompletion = newCompletion;
    });
  }

  /// Navigate to Test Screen
  void goToTest() {
    if (selectedTopic != null &&
        selectedLevel != null &&
        selectedSubtopic != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TestScreen(
            selectedTopic: selectedTopic!,
            selectedLevel: selectedLevel!,
            selectedSubtopic: selectedSubtopic!,
            selectedCategory: "MCQ",
            selectedQuestionType: "MCQs",
          ),
        ),
      ).then((_) {
        _loadSubtopicProgress();
      });
    }
  }

  /// Navigate to Learn Screen
  void goToLearn() {
    if (selectedTopic != null &&
        selectedLevel != null &&
        selectedSubtopic != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LearnScreen(
            selectedTopic: selectedTopic!,
            selectedLevel: selectedLevel!,
            selectedSubtopic: selectedSubtopic!,
            selectedCategory: "Learn",
          ),
        ),
      ).then((_) {
        _loadSubtopicProgress();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return TopBarScaffold(
        title: 'Select Learning Path',
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.backgroundDark,
                      Color(0xFF1E1B4B),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.backgroundLight,
                      Color(0xFFE0E7FF),
                    ],
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
                  'Loading available content...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 120,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark.withValues(alpha: 0.3)
                        : AppColors.surfaceLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppBorderRadius.circular),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeInOut,
                    width: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [AppColors.primaryLight, AppColors.accentPurple]
                            : [AppColors.primary, AppColors.accentPurple],
                      ),
                      borderRadius: BorderRadius.circular(AppBorderRadius.circular),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return TopBarScaffold(
      title: 'Select Learning Path',
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.backgroundDark,
                    Color(0xFF1E1B4B),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.backgroundLight,
                    Color(0xFFE0E7FF),
                  ],
                ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced Welcome Card with Pulse Animation
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween(begin: 0, end: 1),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, -20 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
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
                      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 20,
                          spreadRadius: 4,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.1),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lightbulb_outline,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Learning Path',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  if (_isUsingCachedData)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.orange.withValues(alpha: 0.4),
                                            Colors.deepOrange.withValues(alpha: 0.3),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                                        border: Border.all(
                                          color: Colors.orange.withValues(alpha: 0.6),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.wifi_off,
                                            size: 12,
                                            color: Colors.orange.shade200,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'OFFLINE',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade100,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Choose your journey',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                              if (_isUsingCachedData)
                                const SizedBox(height: AppSpacing.xs),
                              if (_isUsingCachedData)
                                Text(
                                  'Using saved content. Connect to update.',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.orange.shade200,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Enhanced Selection Cards - Staggered Animation
                Expanded(
                  child: Column(
                    children: [
                      _buildAnimatedSelectionCard(
                        delay: 0,
                        context: context,
                        title: 'Topic',
                        icon: Icons.topic,
                        color: AppColors.accentPurple,
                        value: selectedTopic,
                        hint: _availableTopics.isEmpty 
                            ? 'Check internet connection'
                            : 'Select a topic to learn',
                        items: _availableTopics,
                        onChanged: (val) {
                          setState(() {
                            selectedTopic = val;
                            selectedLevel = null;
                            selectedSubtopic = null;
                            subtopicCompletion.clear();
                          });
                        },
                        isEnabled: _availableTopics.isNotEmpty,
                      ),
                      
                      const SizedBox(height: AppSpacing.lg),
                      
                      _buildAnimatedSelectionCard(
                        delay: 100,
                        context: context,
                        title: 'Level',
                        icon: Icons.trending_up,
                        color: AppColors.accentBlue,
                        value: selectedLevel,
                        hint: selectedTopic == null 
                            ? 'Select topic first' 
                            : (getLevelsForTopic().isEmpty 
                                ? 'No levels available for this topic'
                                : 'Select difficulty level'),
                        items: selectedTopic == null ? [] : getLevelsForTopic(),
                        onChanged: (val) {
                          if (selectedTopic == null || getLevelsForTopic().isEmpty) return;
                          setState(() {
                            selectedLevel = val;
                            selectedSubtopic = null;
                            subtopicCompletion.clear();
                          });
                          _loadSubtopicProgress();
                        },
                        isEnabled: selectedTopic != null && getLevelsForTopic().isNotEmpty,
                      ),
                      
                      const SizedBox(height: AppSpacing.lg),
                      
                      _buildAnimatedSelectionCard(
                        delay: 200,
                        context: context,
                        title: 'Subtopic',
                        icon: Icons.menu_book,
                        color: AppColors.accentGreen,
                        value: selectedSubtopic,
                        hint: selectedLevel == null 
                            ? 'Select level first' 
                            : (getSubtopicsForLevel().isEmpty 
                                ? 'No subtopics available for this level'
                                : 'Select specific area'),
                        items: selectedLevel == null ? [] : getSubtopicsForLevel(),
                        itemBuilder: (subtopic) {
                          bool completed = subtopicCompletion[subtopic] ?? false;
                          return DropdownMenuItem(
                            value: subtopic,
                            child: Row(
                              children: [
                                Icon(
                                  completed ? Icons.check_circle : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: completed ? AppColors.success : theme.colorScheme.outline,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    subtopic,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: completed ? AppColors.success : null,
                                      fontWeight: completed ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (completed)
                                  Container(
                                    margin: const EdgeInsets.only(left: AppSpacing.xs),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                                    ),
                                    child: Text(
                                      'Done',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                        onChanged: (val) {
                          if (selectedLevel == null || getSubtopicsForLevel().isEmpty) return;
                          setState(() {
                            selectedSubtopic = val;
                          });
                        },
                        isEnabled: selectedLevel != null && getSubtopicsForLevel().isNotEmpty,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                // Enhanced Action Buttons with Scale Effect
                Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedActionButton(
                        context,
                        title: 'Test Mode',
                        subtitle: 'Challenge yourself',
                        icon: Icons.quiz,
                        color: AppColors.accentOrange,
                        onPressed: (selectedTopic != null &&
                                selectedLevel != null &&
                                selectedSubtopic != null &&
                                _contentService.hasTestContent(
                                  selectedTopic!,
                                  selectedLevel!,
                                  selectedSubtopic!,
                                ))
                            ? () {
                                HapticFeedback.mediumImpact();
                                goToTest();
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _buildEnhancedActionButton(
                        context,
                        title: 'Study Mode',
                        subtitle: 'Learn at your pace',
                        icon: Icons.school,
                        color: AppColors.secondary,
                        onPressed: (selectedTopic != null &&
                                selectedLevel != null &&
                                selectedSubtopic != null &&
                                _contentService.hasStudyContent(
                                  selectedTopic!,
                                  selectedLevel!,
                                  selectedSubtopic!,
                                ))
                            ? () {
                                HapticFeedback.mediumImpact();
                                goToLearn();
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                // Enhanced Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? AppColors.surfaceDark.withValues(alpha: 0.6)
                        : AppColors.surfaceLight.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    border: Border.all(
                      color: isDark
                          ? AppColors.dividerDark.withValues(alpha: 0.5)
                          : AppColors.dividerLight.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    boxShadow: AppShadows.small,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.support_agent,
                          size: 16,
                          color: isDark ? AppColors.primaryLight : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'For Consultation: +92-307-776-319-5',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedSelectionCard({
    required int delay,
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required String? value,
    required String hint,
    required List<String> items,
    Widget Function(String)? itemBuilder,
    required Function(String?)? onChanged,
    required bool isEnabled,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 600 + delay),
        tween: Tween(begin: 0, end: 1),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          final delayedValue = delay > 0 ? ((value * 1000 - delay) / (1000 - delay)).clamp(0.0, 1.0) : value;
          return Transform.translate(
            offset: Offset(0, 30 * (1 - delayedValue)),
            child: Opacity(
              opacity: delayedValue,
              child: child,
            ),
          );
        },
        child: _SelectionCardContent(
          title: title,
          icon: icon,
          color: color,
          value: value,
          hint: hint,
          items: items,
          itemBuilder: itemBuilder,
          onChanged: onChanged,
          isEnabled: isEnabled,
          isDark: isDark,
        ),
      ),
    );
  }

  Widget _buildEnhancedActionButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = onPressed != null;

    return _ActionButton(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      isEnabled: isEnabled,
      isDark: isDark,
      onPressed: onPressed,
    );
  }
}

// Extracted selection card widget for better performance
class _SelectionCardContent extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String? value;
  final String hint;
  final List<String> items;
  final Widget Function(String)? itemBuilder;
  final Function(String?)? onChanged;
  final bool isEnabled;
  final bool isDark;

  const _SelectionCardContent({
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    required this.hint,
    required this.items,
    this.itemBuilder,
    required this.onChanged,
    required this.isEnabled,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        gradient: isEnabled && isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surfaceDark,
                  AppColors.surfaceDark.withValues(alpha: 0.8),
                ],
              )
            : null,
        color: isEnabled && !isDark ? null : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: color.withValues(alpha: isDark ? 0.15 : 0.1),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ]
            : AppShadows.small,
        border: Border.all(
          color: isEnabled
              ? color.withValues(alpha: isDark ? 0.3 : 0.25)
              : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
          width: isEnabled ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Header with Gradient Accent
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                gradient: isEnabled
                    ? LinearGradient(
                        colors: [
                          color.withValues(alpha: isDark ? 0.2 : 0.12),
                          color.withValues(alpha: isDark ? 0.1 : 0.05),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: isEnabled ? null : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      gradient: isEnabled
                          ? LinearGradient(
                              colors: [
                                color.withValues(alpha: 0.3),
                                color.withValues(alpha: 0.15),
                              ],
                            )
                          : null,
                      color: isEnabled ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                    ),
                    child: Icon(
                      icon,
                      color: isEnabled ? color : theme.colorScheme.outline,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isEnabled
                          ? (isDark ? Colors.white : color)
                          : theme.colorScheme.outline,
                    ),
                  ),
                  if (value != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Enhanced Dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: value,
                hint: Text(
                  hint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    borderSide: BorderSide(
                      color: isEnabled ? color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  isDense: true,
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  size: 22,
                  color: isEnabled && items.isNotEmpty ? color : theme.colorScheme.outline,
                ),
                items: items.isEmpty
                    ? []
                    : items.map((item) {
                        if (itemBuilder != null) {
                          return itemBuilder!(item) as DropdownMenuItem<String>;
                        }
                        return DropdownMenuItem(
                          value: item,
                          child: Text(item, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                onChanged: isEnabled && items.isNotEmpty ? onChanged : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Extracted action button for better performance and isolated rebuilds
class _ActionButton extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isEnabled;
  final bool isDark;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isEnabled,
    required this.isDark,
    required this.onPressed,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      onEnter: widget.isEnabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: widget.isEnabled ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: AppDurations.normal,
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..scale(_isHovered && widget.isEnabled ? 1.03 : 1.0),
          decoration: BoxDecoration(
            gradient: widget.isEnabled
                ? LinearGradient(
                    colors: [
                      widget.color,
                      widget.color.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.isEnabled ? null : (widget.isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            boxShadow: widget.isEnabled
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: widget.isDark ? 0.4 : 0.3),
                      blurRadius: _isHovered ? 20 : 12,
                      spreadRadius: _isHovered ? 4 : 2,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : AppShadows.small,
            border: widget.isEnabled
                ? null
                : Border.all(
                    color: widget.isDark ? AppColors.dividerDark : AppColors.dividerLight,
                    width: 1,
                  ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: widget.isEnabled
                          ? Colors.white.withValues(alpha: 0.2)
                          : widget.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                      border: widget.isEnabled
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.isEnabled ? Colors.white : widget.color.withValues(alpha: 0.5),
                      size: 24,
                    ),
                  ),
                  if (widget.isEnabled) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                      ),
                      child: Icon(
                        Icons.arrow_forward,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 14,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.isEnabled ? Colors.white : theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.subtitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: widget.isEnabled ? Colors.white.withValues(alpha: 0.85) : theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
