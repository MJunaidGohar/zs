import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/question.dart';
import '../providers/user_provider.dart';
import '../services/certificate_pdf_service.dart';
import '../utils/app_theme.dart';
import '../utils/text_direction_helper.dart';
import 'tools_screen.dart';

/// Certificate Result Screen - Displays test results and provides PDF download
class CertificateResultScreen extends StatefulWidget {
  final String topic;
  final int totalQuestions;
  final int correctAnswers;
  final int wrongAnswers;
  final int score;
  final List<Question> questions;
  final Map<int, String> userAnswers;

  const CertificateResultScreen({
    super.key,
    required this.topic,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.score,
    required this.questions,
    required this.userAnswers,
  });

  @override
  State<CertificateResultScreen> createState() => _CertificateResultScreenState();
}

class _CertificateResultScreenState extends State<CertificateResultScreen> {
  late ConfettiController _confettiController;
  bool _isGeneratingPdf = false;
  double _percentage = 0.0;
  bool _isPassed = false;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    _calculateResults();
    _loadUserName();
  }

  void _calculateResults() {
    _percentage = (widget.correctAnswers / widget.totalQuestions) * 100;
    _isPassed = _percentage >= 60; // 60% passing criteria
    
    if (_isPassed) {
      // Start confetti after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _confettiController.play();
      });
    }
  }

  Future<void> _loadUserName() async {
    final userProfile = await UserProvider.getUserProfile();
    if (mounted) {
      setState(() {
        _userName = userProfile?['name'] ?? 'Student';
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        _navigateToTools();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: _navigateToTools,
          ),
          title: const Text('Certificate Result'),
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
        body: Stack(
          children: [
            _buildContent(isDark, theme),
            // Confetti overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Result Card
          _buildResultCard(isDark, theme),
          const SizedBox(height: AppSpacing.lg),
          // Statistics
          _buildStatistics(isDark, theme),
          const SizedBox(height: AppSpacing.lg),
          // Actions
          if (_isPassed) _buildCertificateActions(isDark, theme),
          if (!_isPassed) _buildRetryAction(isDark, theme),
          const SizedBox(height: AppSpacing.lg),
          // Review Answers
          _buildReviewAnswers(isDark, theme),
        ],
      ),
    );
  }

  Widget _buildResultCard(bool isDark, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        side: BorderSide(
          color: _isPassed 
              ? AppColors.success.withValues(alpha: isDark ? 0.3 : 0.5)
              : AppColors.error.withValues(alpha: isDark ? 0.3 : 0.5),
          width: 2,
        ),
      ),
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            // Status Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isPassed
                    ? AppColors.success.withValues(alpha: isDark ? 0.2 : 0.1)
                    : AppColors.error.withValues(alpha: isDark ? 0.2 : 0.1),
                border: Border.all(
                  color: _isPassed ? AppColors.success : AppColors.error,
                  width: 3,
                ),
              ),
              child: Icon(
                _isPassed ? Icons.workspace_premium : Icons.cancel,
                size: 50,
                color: _isPassed ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Status Text
            Text(
              _isPassed ? 'Congratulations!' : 'Better Luck Next Time',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: _isPassed ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _isPassed
                  ? 'You have earned your certificate!'
                  : 'You did not meet the passing criteria.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Score
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.gradientHeader,
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              ),
              child: Column(
                children: [
                  Text(
                    '${_percentage.toStringAsFixed(1)}%',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${widget.correctAnswers}/${widget.totalQuestions} Correct',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Pass/Fail indicator
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: _isPassed
                    ? AppColors.success.withValues(alpha: isDark ? 0.2 : 0.1)
                    : AppColors.error.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
              child: Text(
                _isPassed ? 'PASSED (60% required)' : 'FAILED (60% required)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _isPassed ? AppColors.success : AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics(bool isDark, ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Correct',
            widget.correctAnswers.toString(),
            AppColors.success,
            Icons.check_circle,
            isDark,
            theme,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildStatCard(
            'Wrong',
            widget.wrongAnswers.toString(),
            AppColors.error,
            Icons.cancel,
            isDark,
            theme,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildStatCard(
            'Total',
            widget.totalQuestions.toString(),
            AppColors.accentBlue,
            Icons.quiz,
            isDark,
            theme,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
    bool isDark,
    ThemeData theme,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        side: BorderSide(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1.5,
        ),
      ),
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateActions(bool isDark, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Certificate',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Download Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isGeneratingPdf ? null : _downloadCertificate,
            icon: _isGeneratingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download),
            label: Text(_isGeneratingPdf ? 'Generating PDF...' : 'Download Certificate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Share Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isGeneratingPdf ? null : _shareCertificate,
            icon: const Icon(Icons.share),
            label: const Text('Share Certificate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRetryAction(bool isDark, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Try Again',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _navigateToTools,
            icon: const Icon(Icons.refresh),
            label: const Text('Retake Test'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewAnswers(bool isDark, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        side: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: ExpansionTile(
        title: Text(
          'Review Your Answers',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        children: widget.questions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          final userAnswer = widget.userAnswers[index];
          final isCorrect = userAnswer == question.correctAnswer;
          
          return ListTile(
            leading: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCorrect ? AppColors.success : AppColors.error,
              ),
              child: Icon(
                isCorrect ? Icons.check : Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
            title: Text(
              'Q${index + 1}: ${question.questionText}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              textDirection: TextDirectionHelper.getTextDirection(question.questionText),
            ),
            subtitle: Text(
              'Your answer: ${userAnswer ?? 'Not answered'}',
              style: TextStyle(
                fontSize: 12,
                color: isCorrect ? AppColors.success : AppColors.error,
              ),
              textDirection: TextDirectionHelper.getTextDirection(userAnswer ?? ''),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _downloadCertificate() async {
    if (_userName == null) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      // Request storage permission for Android
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission required to save certificate');
        }
      }

      final filePath = await CertificatePdfService.generateAndSaveCertificate(
        userName: _userName!,
        topic: widget.topic,
        date: DateTime.now(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Certificate saved to: $filePath'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Open',
              onPressed: () {
                // Open PDF
                // You can use url_launcher to open the PDF
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download certificate: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  Future<void> _shareCertificate() async {
    if (_userName == null) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      await CertificatePdfService.shareCertificate(
        userName: _userName!,
        topic: widget.topic,
        date: DateTime.now(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share certificate: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  void _navigateToTools() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ToolsScreen()),
      (route) => route.isFirst,
    );
  }
}
