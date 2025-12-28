import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/user_provider.dart';
import '../services/attempt_service.dart';
import '../services/progress_service.dart';
import '../services/wrong_questions_service.dart';
import '../services/hive_service.dart';
import '../services/user_service.dart';
import '../models/attempt.dart';
import '../widgets/avatar_display.dart';
import '../screens/test_screen.dart';
import '../screens/game.dart'; // <-- import your game screen
import '../services/notification_service.dart';

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
    if (mounted) {
      setState(() {
        _reminderTime = saved ?? const TimeOfDay(hour: 21, minute: 0);
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
        map[a.selectedClass] ??= {};
        map[a.selectedClass]![a.subject] ??= [];
        map[a.selectedClass]![a.subject]!.add(a);
      }

      wrongAttempts = attempts.where((a) => a.total > 0 && a.score < a.total).toList();

      Map<String, Map<String, List<Attempt>>> wMap = {};
      for (var a in wrongAttempts) {
        wMap[a.selectedClass] ??= {};
        wMap[a.selectedClass]![a.subject] ??= [];
        wMap[a.selectedClass]![a.subject]!.add(a);
      }

      Map<String, Map<String, List<bool>>> lMap = {};
      Map<String, Map<String, List<DateTime>>> lTimeMap = {};
      Map<String, Map<String, List<String>>> lKeys = {};

      learningProgress.forEach((unitKey, completed) {
        final parts = unitKey.split('_');
        if (parts.length < 3) return;
        final cls = parts[0], sub = parts[1];

        lMap[cls] ??= {};
        lMap[cls]![sub] ??= [];
        lMap[cls]![sub]!.add(completed);

        lTimeMap[cls] ??= {};
        lTimeMap[cls]![sub] ??= [];
        lTimeMap[cls]![sub]!.add(learningTimestamp[unitKey]!);

        lKeys[cls] ??= {};
        lKeys[cls]![sub] ??= [];
        lKeys[cls]![sub]!.add(unitKey);
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

  void _retryAttempt(Attempt attempt) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TestScreen(
          selectedClass: attempt.selectedClass,
          selectedCategory: attempt.selectedCategory,
          selectedSubject: attempt.subject,
          selectedQuestionType: attempt.questionType,
          selectedUnit: attempt.selectedUnit,
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
                  children: learningMap.entries.map((classEntry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Class ${classEntry.key}", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                              }).toList(),
                              const SizedBox(height: 12),
                            ],
                          );
                        }).toList(),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                );
              }
            } else if (type == 'test') {
              if (testMap.isEmpty) {
                content = Center(child: Text('No test progress found', style: theme.textTheme.bodyLarge));
              } else {
                content = ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: testMap.entries.map((classEntry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Class ${classEntry.key}", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...classEntry.value.entries.map((subjectEntry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...(subjectEntry.value as List<Attempt>).map((a) {
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
                                        Text(a.selectedUnit, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 6),
                                        LinearProgressIndicator(
                                          value: percent,
                                          minHeight: 8,
                                          backgroundColor: theme.colorScheme.surfaceVariant,
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
                              }).toList(),
                              const SizedBox(height: 12),
                            ],
                          );
                        }).toList(),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                );
              }
            } else {
              if (wrongAttemptsMap.isEmpty) {
                content = Center(child: Text('No wrong attempts to retry', style: theme.textTheme.bodyLarge));
              } else {
                content = ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: wrongAttemptsMap.entries.map((classEntry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Class ${classEntry.key}", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                                    title: Text(a.selectedUnit),
                                    subtitle: Text(
                                      "Score: ${a.score}/${a.total}\n"
                                          "Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(a.timestamp.toLocal())}",
                                    ),
                                    trailing: ElevatedButton(
                                      onPressed: () => _retryAttempt(a),
                                      child: const Text("Retry"),
                                    ),
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 12),
                            ],
                          );
                        }).toList(),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
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
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
      await NotificationService.saveReminderTime(_reminderTime);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Reminder saved at ${_reminderTime.format(context)}"),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Personal Profile"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                AvatarDisplay(size: 80),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userProvider.userName ?? 'Guest', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text("Points: $totalPoints", style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _pickReminderTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active, color: Colors.orange, size: 20),
                        const SizedBox(width: 6),
                        Text("${_reminderTime.format(context)}", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _showBottomSheet('learning'),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Study Progress", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 17),
                                const SizedBox(height: 8),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0,
                                    end: _computeLearningProgress(),
                                  ),
                                  duration: const Duration(seconds: 1),
                                  builder: (context, value, _) => LinearProgressIndicator(
                                    value: value,
                                    minHeight: 10,
                                    backgroundColor: theme.colorScheme.surfaceVariant,
                                    valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _showBottomSheet('test'),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Test Progress", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 18),
                                const SizedBox(height: 8),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0,
                                    end: _computeTestProgress(),
                                  ),
                                  duration: const Duration(seconds: 1),
                                  builder: (context, value, _) => LinearProgressIndicator(
                                    value: value,
                                    minHeight: 10,
                                    backgroundColor: theme.colorScheme.surfaceVariant,
                                    valueColor: AlwaysStoppedAnimation(theme.colorScheme.secondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showBottomSheet('retry'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Retry Wrong Tests", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const Icon(Icons.refresh, color: Colors.redAccent, size: 28),
                        ],
                      ),
                    ),
                  ),
                ),

                // ---------------- Game Time Button ----------------
                const SizedBox(height: 12),
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(150, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 5,
                      shadowColor: Colors.deepPurple.withOpacity(0.5),
                    ),
                    icon: const Icon(Icons.videogame_asset, size: 20),
                    label: const Text(
                      "Game Time",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GameScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // ---------------- Clear History Button ----------------
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text("Clear History", style: TextStyle(fontSize: 16)),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Clear History"),
                        content: const Text("Are you sure you want to delete everything?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            child: const Text("Clear"),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await HiveService.clearHistory();
                      await NotificationService.cancelAll();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("✅ All history and points cleared.")),
                        );
                        _loadProfileData();
                      }
                    }
                  },
                ),

              ],
            ),
          ],
        ),
      ),
    );
  }
}
