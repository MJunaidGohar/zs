import 'package:flutter/material.dart';
import '../models/question.dart';
import '../services/question_service.dart';
import '../services/progress_service.dart';
import '../widgets/top_bar_scaffold.dart';
import 'dart:math';
import '../utils/string_extensions.dart';


// 🔹 Cache for shuffled unit questions (persists during app runtime)
final Map<String, List<Question>> _shuffledCache = {};

class LearnScreen extends StatefulWidget {
  final String selectedClass;
  final String selectedCategory;
  final String selectedSubject;
  final String selectedUnit;

  const LearnScreen({
    super.key,
    required this.selectedClass,
    required this.selectedCategory,
    required this.selectedSubject,
    required this.selectedUnit,
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
      "${widget.selectedClass}_${widget.selectedSubject}_${widget.selectedUnit}".toLowerCase();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollEnd);
    _loadQuestions(); // 🔹 Load from Hive
  }

  Future<void> _loadQuestions() async {
    final questionService = QuestionService();

    // 🔹 Use Hive to fetch short questions
    _shortQuestions = await questionService.getShortQuestions(
      className: widget.selectedClass,
      subject: widget.selectedSubject,
      unit: widget.selectedUnit,
    );

    // 🔹 Shuffle once and cache
    if (_shuffledCache.containsKey(_unitKey)) {
      _shortQuestions = _shuffledCache[_unitKey]!;
    } else {
      _shortQuestions.shuffle(Random(DateTime.now().microsecondsSinceEpoch));
      _shuffledCache[_unitKey] = _shortQuestions;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onScrollEnd() async {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      if (!_markedComplete) {
        _markedComplete = true;
        await ProgressService().saveUnitProgress(_unitKey, true);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unit is completed!')),
        );
      }
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
        title: '${widget.selectedSubject} - ${widget.selectedUnit}',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_shortQuestions.isEmpty) {
      return TopBarScaffold(
        title: 'Learn Mode',
        body: const Center(
          child: Text('No short questions available for this unit.'),
        ),
      );
    }

    return TopBarScaffold(
      title: '${widget.selectedSubject} - ${widget.selectedUnit}',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _shortQuestions.length,
          itemBuilder: (context, index) {
            final question = _shortQuestions[index];
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:
                    isDark ? Colors.black26 : Colors.grey.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Q${index + 1}. ${question.questionText}",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        if (isDark)
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 3),
                          )
                        else
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(1, 2),
                          ),
                      ],
                    ),
                    child: Text(
                      question.answer ?? "No answer available",
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
