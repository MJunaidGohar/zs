import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/google_sheets_content_service.dart';
import '../utils/app_theme.dart';
import '../screens/certificate_test_screen.dart';

/// Dialog for selecting a topic to get certificate for
class TopicSelectionDialog extends StatefulWidget {
  const TopicSelectionDialog({super.key});

  @override
  State<TopicSelectionDialog> createState() => _TopicSelectionDialogState();
}

class _TopicSelectionDialogState extends State<TopicSelectionDialog> {
  final GoogleSheetsContentService _sheetsService = GoogleSheetsContentService();
  List<String> _topics = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    try {
      // Ensure service is initialized
      if (!GoogleSheetsContentService().isInitialized) {
        await _sheetsService.initialize();
      }

      final topics = _sheetsService.getAvailableTopics();
      
      // Filter topics that have certificate content
      final availableTopics = topics.where((topic) {
        return _sheetsService.hasCertificateContent(topic);
      }).toList();

      if (mounted) {
        setState(() {
          _topics = availableTopics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load topics: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
      ),
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.gradientHeader,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Select Topic for Certificate',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Choose a topic to take the comprehensive test and earn your certificate.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
            // Topics List
            Expanded(
              child: _buildContent(isDark, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark, ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadTopics();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_topics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_off,
              size: 48,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No certificate content available yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _topics.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final topic = _topics[index];
        return _buildTopicCard(topic, isDark, theme);
      },
    );
  }

  Widget _buildTopicCard(String topic, bool isDark, ThemeData theme) {
    // Get topic icon
    final IconData topicIcon = _getTopicIcon(topic);
    final Color topicColor = _getTopicColor(topic);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        side: BorderSide(
          color: topicColor.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1.5,
        ),
      ),
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.pop(context);
          _navigateToCertificateTest(topic);
        },
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: topicColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                ),
                child: Icon(
                  topicIcon,
                  color: topicColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Comprehensive test covering all levels',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTopicIcon(String topic) {
    switch (topic.toLowerCase()) {
      case 'english':
        return Icons.language;
      case 'computer':
        return Icons.computer;
      case 'digital marketing':
        return Icons.trending_up;
      case 'web development':
        return Icons.web;
      case 'youtube':
        return Icons.play_circle_filled;
      default:
        return Icons.school;
    }
  }

  Color _getTopicColor(String topic) {
    switch (topic.toLowerCase()) {
      case 'english':
        return AppColors.accentBlue;
      case 'computer':
        return AppColors.accentGreen;
      case 'digital marketing':
        return AppColors.accentOrange;
      case 'web development':
        return AppColors.accentPurple;
      case 'youtube':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  void _navigateToCertificateTest(String topic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CertificateTestScreen(selectedTopic: topic),
      ),
    );
  }
}
