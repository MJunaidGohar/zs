import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/user_provider.dart';
import '../services/attempt_service.dart';
import '../services/progress_service.dart';
import '../services/wrong_questions_service.dart';
import '../services/hive_service.dart';
import '../models/attempt.dart';
import '../widgets/avatar_display.dart';
import '../screens/test_screen.dart';
import '../screens/game.dart';
import '../screens/learning_videos_screen.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AttemptService _attemptService = AttemptService();
  final WrongQuestionsService _wrongService = WrongQuestionsService();

  Map<String, Map<String, List<Attempt>>> testMap = {};
  Map<String, Map<String, List<bool>>> learningMap = {};
  Map<String, Map<String, List<DateTime>>> learningTimestampMap = {};
  Map<String, Map<String, List<String>>> learningUnitKeys = {};
  List<Attempt> wrongAttempts = [];

  Map<String, Map<String, List<Attempt>>> wrongAttemptsMap = {};

  bool _loading = true;
  bool _notificationPermissionGranted = true;

  TimeOfDay _reminderTime = const TimeOfDay(hour: 21, minute: 0);

  int totalPoints = 0;

  @override
  void initState() {
    super.initState();
    Provider.of<UserProvider>(context, listen: false).loadUserData();
    _loadProfileData();
    _loadReminderTime();
  }

  Future<void> _loadReminderTime() async {
    final saved = await NotificationService.loadReminderTime();
    // Check permission status to show warning indicator if needed
    final hasPermission = await NotificationService.hasNotificationPermission();
    if (mounted) {
      setState(() {
        _reminderTime = saved ?? const TimeOfDay(hour: 21, minute: 0);
        _notificationPermissionGranted = hasPermission;
      });
    }
  }

  Future<void> _loadProfileData() async {
    setState(() => _loading = true);
    try {
      final attempts = await _attemptService.getAttempts();
      final completedUnits = await ProgressService().getCompletedUnitIds();
      await _wrongService.getWrongQuestions();

      Map<String, bool> learningProgress = {};
      Map<String, DateTime> learningTimestamp = {};

      for (var unitId in completedUnits) {
        learningProgress[unitId] = true;
        final saved = await ProgressService().loadUnitTimestamp(unitId);
        learningTimestamp[unitId] = saved ?? DateTime.now();
      }

      Map<String, Map<String, List<Attempt>>> map = {};
      for (var a in attempts) {
        final topicKey = a.displayTopic;
        final levelKey = a.displayLevel;
        map[topicKey] ??= {};
        map[topicKey]![levelKey] ??= [];
        map[topicKey]![levelKey]!.add(a);
      }

      wrongAttempts = attempts.where((a) => a.total > 0 && a.score < a.total).toList();

      Map<String, Map<String, List<Attempt>>> wMap = {};
      for (var a in wrongAttempts) {
        final topicKey = a.displayTopic;
        final levelKey = a.displayLevel;
        wMap[topicKey] ??= {};
        wMap[topicKey]![levelKey] ??= [];
        wMap[topicKey]![levelKey]!.add(a);
      }

      Map<String, Map<String, List<bool>>> lMap = {};
      Map<String, Map<String, List<DateTime>>> lTimeMap = {};
      Map<String, Map<String, List<String>>> lKeys = {};

      learningProgress.forEach((unitKey, completed) {
        final parts = unitKey.split('_');
        if (parts.length < 3) return;
        final topic = parts[0], level = parts[1];

        lMap[topic] ??= {};
        lMap[topic]![level] ??= [];
        lMap[topic]![level]!.add(completed);

        lTimeMap[topic] ??= {};
        lTimeMap[topic]![level] ??= [];
        lTimeMap[topic]![level]!.add(learningTimestamp[unitKey]!);

        lKeys[topic] ??= {};
        lKeys[topic]![level] ??= [];
        lKeys[topic]![level]!.add(unitKey);
      });

      final totalPointsLocal = map.values
          .expand((e) => e.values.expand((l) => l))
          .fold<int>(0, (prev, a) => prev + a.score);

      if (mounted) {
        setState(() {
          testMap = map;
          learningMap = lMap;
          learningTimestampMap = lTimeMap;
          learningUnitKeys = lKeys;
          wrongAttemptsMap = wMap;
          totalPoints = totalPointsLocal;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retryAttempt(Attempt attempt) async {
    debugPrint('🔍 _retryAttempt called for: ${attempt.displayTopic}/${attempt.displayLevel}/${attempt.displaySubtopic}');
    
    final wrongService = WrongQuestionsService();
    final allWrongQuestions = await wrongService.getWrongQuestions();
    debugPrint('🔍 Total wrong questions in storage: ${allWrongQuestions.length}');
    
    // Filter wrong questions for this specific topic/level/subtopic
    final topicKey = attempt.displayTopic.toLowerCase().trim();
    final levelKey = attempt.displayLevel.toLowerCase().trim();
    final subtopicKey = attempt.displaySubtopic.toLowerCase().trim();
    
    final filteredWrongQuestions = allWrongQuestions.where((q) {
      final qTopic = (q.topic ?? q.selectedClass ?? '').toLowerCase().trim();
      final qLevel = (q.level ?? q.subject ?? '').toLowerCase().trim();
      final qSubtopic = (q.subtopic ?? q.selectedUnit ?? '').toLowerCase().trim();
      
      final matches = qTopic == topicKey && 
             qLevel == levelKey && 
             qSubtopic == subtopicKey;
      
      debugPrint('🔍 Question: topic=$qTopic, level=$qLevel, subtopic=$qSubtopic, matches=$matches');
      return matches;
    }).toList();
    
    debugPrint('🔍 Filtered wrong questions: ${filteredWrongQuestions.length}');

    if (!mounted) return;

    if (filteredWrongQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No wrong questions found to retry for this topic.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TestScreen(
          selectedTopic: attempt.displayTopic,
          selectedLevel: attempt.displayLevel,
          selectedSubtopic: attempt.displaySubtopic,
          selectedCategory: attempt.selectedCategory,
          selectedQuestionType: attempt.questionType,
          onlyWrongQuestions: filteredWrongQuestions,
        ),
      ),
    ).then((_) => _loadProfileData());
  }

  void _showBottomSheet(String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            Widget content;

            if (type == 'learning') {
              if (learningMap.isEmpty) {
                content = Center(child: Text('No study progress found', style: theme.textTheme.bodyLarge));
              } else {
                content = ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...learningMap.entries.map((classEntry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Topic ${classEntry.key}", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...classEntry.value.entries.map((subjectEntry) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(subjectEntry.key, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                ...subjectEntry.value
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  final completed = entry.value;
                                  final timestamp = learningTimestampMap[classEntry.key]?[subjectEntry.key]?[entry.key] ?? DateTime.now();

                                  final unitKey = learningUnitKeys[classEntry.key]![subjectEntry.key]![entry.key];
                                  final unitParts = unitKey.split('_');
                                  final actualUnit = unitParts.sublist(2).join('_');

                                  return Card(
                                    color: isDark ? Colors.grey[850] : theme.colorScheme.surface,
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    child: ListTile(
                                      title: Text(actualUnit),
                                      trailing: Icon(
                                        completed ? Icons.check_circle : Icons.circle_outlined,
                                        color: completed ? Colors.green : Colors.grey,
                                      ),
                                      subtitle: Text("Completed on ${dateFormatter.format(timestamp)}"),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 12),
                              ],
                            );
                          }),
                          const SizedBox(height: 16),
                        ],
                      );
                    }),
                  ],
                );
              }
            } else if (type == 'test') {
              if (testMap.isEmpty) {
                content = Center(child: Text('No test progress found', style: theme.textTheme.bodyLarge));
              } else {
                content = ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...testMap.entries.map((classEntry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Topic ${classEntry.key}", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...classEntry.value.entries.map((subjectEntry) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...subjectEntry.value.map((a) {
                                  final percent = a.total > 0 ? a.score / a.total : 0.0;
                                  return Card(
                                    color: isDark ? Colors.grey[850] : theme.colorScheme.surface,
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(a.displaySubtopic, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 6),
                                          LinearProgressIndicator(
                                            value: percent,
                                            minHeight: 8,
                                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                            valueColor: AlwaysStoppedAnimation(percent == 1 ? Colors.green : theme.colorScheme.primary),
                                          ),
                                          const SizedBox(height: 4),
                                          Text("${a.score} / ${a.total}", style: theme.textTheme.bodySmall),
                                          const SizedBox(height: 4),
                                          Text("Taken on: ${DateFormat('dd MMM yyyy, hh:mm a').format(a.timestamp.toLocal())}",
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 12),
                              ],
                            );
                          }),
                          const SizedBox(height: 16),
                        ],
                      );
                    }),
                  ],
                );
              }
            } else {
              if (wrongAttemptsMap.isEmpty) {
                content = Center(child: Text('No wrong attempts to retry', style: theme.textTheme.bodyLarge));
              } else {
                content = ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...wrongAttemptsMap.entries.map((classEntry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Topic ${classEntry.key}", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...classEntry.value.entries.map((subjectEntry) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(subjectEntry.key, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                ...subjectEntry.value.map((a) {
                                  return Card(
                                    color: isDark ? Colors.grey[850] : theme.colorScheme.surface,
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      title: Text(a.displaySubtopic),
                                      subtitle: Text(
                                        "Score: ${a.score}/${a.total}\n"
                                            "Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(a.timestamp.toLocal())}",
                                      ),
                                      trailing: SizedBox(
                                        width: 80,
                                        child: ElevatedButton(
                                          onPressed: () => _retryAttempt(a),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            minimumSize: const Size(80, 36),
                                          ),
                                          child: const Text("Retry", style: TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 12),
                              ],
                            );
                          }),
                          const SizedBox(height: 16),
                        ],
                      );
                    }),
                  ],
                );
              }
            }

            return content;
          },
        );
      },
    );
  }

  Future<void> _pickReminderTime() async {
    debugPrint('⏰ _pickReminderTime called');
    
    // Check if this is the first time user is setting a reminder
    final hasExistingTime = await NotificationService.hasReminderTimeSet();
    final isFirstTime = !hasExistingTime;
    debugPrint('⏰ isFirstTime: $isFirstTime (hasExistingTime: $hasExistingTime)');
    
    // If first time, request notification permission before showing picker
    if (isFirstTime) {
      debugPrint('⏰ Requesting permission for first time...');
      final permissionGranted = await NotificationService.requestNotificationPermissions();
      debugPrint('⏰ permissionGranted: $permissionGranted');
      
      if (!mounted) return;
      
      if (!permissionGranted) {
        // Show permission denied message with option to open settings
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Notification Permission Required"),
            content: const Text(
              "To receive daily study reminders, please enable notification permission for this app in system settings."
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Open Settings"),
              ),
            ],
          ),
        );
        
        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
        return; // Don't show time picker if permission denied
      }
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (!mounted) return;
    if (picked == null) return;

    setState(() => _reminderTime = picked);
    
    // Save and schedule notification
    final scheduled = await NotificationService.saveReminderTime(_reminderTime);
    if (!mounted) return;

    if (scheduled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Reminder set for ${_reminderTime.format(context)}"),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("⚠️ Could not schedule reminder. Please check notification permissions."),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => NotificationService.openExactAlarmSettings(),
          ),
        ),
      );
    }
    
    // Check exact alarm permission for Android 12+ and show dialog if needed
    final canExact = await NotificationService.canScheduleExactAlarms();
    
    if (!canExact && mounted && scheduled) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Exact Alarm Permission Needed"),
          content: const Text(
            "For reliable daily reminders at your chosen time, please enable 'Exact Alarms' permission in system settings.\n\n"
            "Without this, reminders may be delayed by a few minutes."
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Later"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                NotificationService.openExactAlarmSettings();
              },
              child: const Text("Open Settings"),
            ),
          ],
        ),
      );
    }
  }

  double _computeLearningProgress() {
    final units = learningMap.values.expand((sub) => sub.values.expand((u) => u)).toList();
    if (units.isEmpty) return 0.0;
    final completed = units.where((c) => c == true).length;
    return completed / units.length;
  }

  double _computeTestProgress() {
    final attempts = testMap.values.expand((sub) => sub.values.expand((a) => a)).toList();
    if (attempts.isEmpty) return 0.0;
    final sumPercent = attempts.fold<double>(
      0.0,
          (prev, a) => prev + (a.total > 0 ? (a.score / a.total) : 0.0),
    );
    return sumPercent / attempts.length;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Personal Profile"),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF667EEA), Color(0xFF764BA2)]
                    : const [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
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
                  'Loading profile...',
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Personal Profile"),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF667EEA), Color(0xFF764BA2)]
                  : const [Color(0xFF4FACFE), Color(0xFF00F2FE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              // Enhanced Profile Header Card with Animation
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
                child: _buildEnhancedProfileHeader(context, userProvider, theme, isDark),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Progress Cards with Staggered Animation
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 700),
                tween: Tween(begin: 0, end: 1),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  final delayedValue = ((value * 1000 - 100) / 900).clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - delayedValue)),
                    child: Opacity(
                      opacity: delayedValue,
                      child: child,
                    ),
                  );
                },
                child: Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedProgressCard(
                        context,
                        title: 'Study Progress',
                        icon: Icons.menu_book,
                        color: AppColors.accentBlue,
                        progress: _computeLearningProgress(),
                        onTap: () => _showBottomSheet('learning'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: _buildEnhancedProgressCard(
                        context,
                        title: 'Test Progress',
                        icon: Icons.quiz,
                        color: AppColors.accentPurple,
                        progress: _computeTestProgress(),
                        onTap: () => _showBottomSheet('test'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Retry Wrong Tests Card
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0, end: 1),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  final delayedValue = ((value * 1000 - 200) / 800).clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - delayedValue)),
                    child: Opacity(
                      opacity: delayedValue,
                      child: child,
                    ),
                  );
                },
                child: _buildEnhancedActionCard(
                  context,
                  title: 'Retry Wrong Tests',
                  subtitle: 'Practice questions you got wrong',
                  icon: Icons.refresh,
                  color: AppColors.accentOrange,
                  onTap: () => _showBottomSheet('retry'),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Game Time & Watch Videos Cards
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 900),
                tween: Tween(begin: 0, end: 1),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  final delayedValue = ((value * 1000 - 300) / 700).clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - delayedValue)),
                    child: Opacity(
                      opacity: delayedValue,
                      child: child,
                    ),
                  );
                },
                child: Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedSquareCard(
                        context,
                        title: 'Game Time',
                        icon: Icons.videogame_asset,
                        color: AppColors.accentPink,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const GameScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: _buildEnhancedSquareCard(
                        context,
                        title: 'Watch Videos',
                        icon: Icons.play_circle_fill,
                        color: AppColors.accentBlue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LearningVideosScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Clear History Button
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1000),
                tween: Tween(begin: 0, end: 1),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  final delayedValue = ((value * 1000 - 400) / 600).clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - delayedValue)),
                    child: Opacity(
                      opacity: delayedValue,
                      child: child,
                    ),
                  );
                },
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text("Clear History", style: TextStyle(fontSize: 16)),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                          ),
                          title: const Text("Clear History"),
                          content: const Text("Are you sure you want to delete everything?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                              child: const Text("Clear"),
                            ),
                          ],
                        ),
                      );

                      if (!mounted) return;

                      if (confirm == true) {
                        await HiveService.clearHistory();
                        await NotificationService.cancelAll();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(content: Text("All history and points cleared.")),
                        );
                        _loadProfileData();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedProfileHeader(BuildContext context, UserProvider userProvider, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF312E81), Color(0xFF4C1D95)]
              : AppColors.gradientLightHeader,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
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
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with glow effect
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: AvatarDisplay(size: AppSpacing.avatarSizeLarge + 8),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userProvider.userName ?? 'Guest',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
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
                          Icon(Icons.stars, size: 16, color: AppColors.accentYellow),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            "$totalPoints Points",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Reminder Time Badge
          GestureDetector(
            onTap: _pickReminderTime,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: _notificationPermissionGranted 
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                border: Border.all(
                  color: _notificationPermissionGranted
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _notificationPermissionGranted 
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                    color: _notificationPermissionGranted
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.orange.shade200,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Daily Reminder: ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    _reminderTime.format(context),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.edit,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedProgressCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required double progress,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  colors: [
                    AppColors.surfaceDark,
                    AppColors.surfaceDark.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isDark ? null : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.15 : 0.1),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.3 : 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.3),
                        color.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                  ),
                  child: Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppBorderRadius.circular),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: isDark
                    ? AppColors.dividerDark.withValues(alpha: 0.5)
                    : AppColors.dividerLight.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 2,
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
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withValues(alpha: 0.9),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedSquareCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 36),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required double progress,
    required VoidCallback onTap,
  }) {
    return _buildEnhancedProgressCard(
      context,
      title: title,
      icon: icon,
      color: color,
      progress: progress,
      onTap: onTap,
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _buildEnhancedActionCard(
      context,
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      onTap: onTap,
    );
  }

  Widget _buildSquareCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _buildEnhancedSquareCard(
      context,
      title: title,
      icon: icon,
      color: color,
      onTap: onTap,
    );
  }
}
