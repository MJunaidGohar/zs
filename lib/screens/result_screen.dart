// result_screen.dart



import 'dart:io';

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/admob_service.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:confetti/confetti.dart';

import 'package:screenshot/screenshot.dart';

import 'package:share_plus/share_plus.dart';

import 'package:path_provider/path_provider.dart';

import 'package:image/image.dart' as img;

import 'package:provider/provider.dart';

import '../providers/user_provider.dart';

import '../widgets/top_bar_scaffold.dart';

import '../screens/main_selection_screen.dart';

import '../screens/test_screen.dart';

import '../utils/app_theme.dart';
import '../l10n/app_localizations.dart';



class ResultScreen extends StatefulWidget {

  final int score;

  final int total;

  final String selectedTopic;

  final String selectedLevel;

  final String selectedSubtopic;

  final String selectedCategory;

  final String selectedQuestionType;



  const ResultScreen({

    super.key,

    required this.score,

    required this.total,

    required this.selectedTopic,

    required this.selectedLevel,

    required this.selectedSubtopic,

    required this.selectedCategory,

    required this.selectedQuestionType,

  });



  @override

  State<ResultScreen> createState() => _ResultScreenState();

}



class _ResultScreenState extends State<ResultScreen>

    with SingleTickerProviderStateMixin {

  InterstitialAd? _interstitialAd;



  // Screenshot controller for capturing result

  final ScreenshotController _screenshotController = ScreenshotController();

  bool _isSharing = false;



  // Play Store link - app store listing

  static const String _playStoreUrl =

      'https://play.google.com/store/apps/details?id=com.jstudio.zarorisawal.zarori_sawal';



  late ConfettiController _confettiController;

  late AnimationController _animationController;

  late Animation<double> _scaleAnimation;

  late Animation<double> _cardBounceAnimation;



  @override

  void initState() {

    super.initState();



    _loadInterstitialAd();



    _confettiController =

        ConfettiController(duration: const Duration(seconds: 2));

    if (_percentage >= 50) _confettiController.play();



    _animationController = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 800),

    );



    // Scale animation for score number

    _scaleAnimation =

        CurvedAnimation(parent: _animationController, curve: Curves.elasticOut);



    // Bounce animation for card

    _cardBounceAnimation =

        Tween<double>(begin: 0.0, end: 8.0).chain(CurveTween(curve: Curves.easeOut))

            .animate(_animationController);



    _animationController.forward();

  }



  double get _percentage =>

      widget.total > 0 ? (widget.score / widget.total) * 100 : 0.0;



  void _loadInterstitialAd() {

    AdMobService.loadInterstitialAd(

      adUnitId: 'ca-app-pub-5721278995377651/6519657994',

      onAdLoaded: (ad) {

        _interstitialAd = ad;

        _interstitialAd!.show();

      },

      onAdFailedToLoad: (error) {

        debugPrint('Interstitial Ad failed to load: $error');

      },

    );

  }



  @override

  void dispose() {

    AdMobService.disposeInterstitialAd(_interstitialAd);

    _confettiController.dispose();

    _animationController.dispose();

    super.dispose();

  }



  /// Generates share text based on performance

  String _getShareMessage(bool isSuccess, double percentage, String userName) {

    final displayName = userName == 'Learner' ? 'I' : userName;

    final messages = [

      if (isSuccess) ...[

        "🎉 $displayName just scored ${widget.score}/${widget.total} (${percentage.toInt()}%) on Zarori Sawal! Can you beat this score? Download to check your ability $_playStoreUrl",

        "🔥 $displayName nailed it! ${percentage.toInt()}% correct in ${widget.selectedLevel}! Challenge yourself with Zaroori Sawal! $_playStoreUrl",

        "🏆 $displayName is on fire! ${widget.score} correct answers! Join on Zaroori Sawal - Learn & Play! $_playStoreUrl",

        "✨ Amazing result by $displayName! ${percentage.toInt()}% accuracy! Think you can do better? $_playStoreUrl",

        "🚀 $displayName is crushing learning goals with ${percentage.toInt()}%! Download Zarori Sawal and let's compete! $_playStoreUrl",

      ] else ...[

        "💪 $displayName is on a learning journey! Scored ${widget.score}/${widget.total} on Zarori Sawal. Let's learn together! $_playStoreUrl",

        "📚 Practice makes perfect! $displayName scored ${percentage.toInt()}% on ${widget.selectedLevel}. Join on Zarori Sawal! $_playStoreUrl",

        "🎯 Every attempt counts! $displayName got ${widget.score} correct this time. Learning with Zaroori Sawal! $_playStoreUrl",

        "🌟 $displayName is getting better every day! Try Zarori Sawal and track your progress too! $_playStoreUrl",

        "📝 Learning mode: ON for $displayName! Scored ${percentage.toInt()}% today. Download Zarori Sawal! $_playStoreUrl",

      ]

    ];

    // Use score + date as seed for consistent but varied selection

    return messages[widget.score % messages.length];

  }



  /// Captures screenshot and shares with Play Store link

  Future<void> _shareResult() async {

    if (_isSharing) return;



    setState(() => _isSharing = true);



    try {

      // Get user name from provider

      final userProvider = context.read<UserProvider>();

      final String userName = userProvider.userName?.trim() ?? 'Learner';



      // Capture screenshot

      final Uint8List? imageBytes = await _screenshotController.capture(

        delay: const Duration(milliseconds: 100),

      );



      if (imageBytes == null) {

        _showShareError('Failed to capture result image');

        return;

      }



      // Add Play Store watermark to image

      final processedImage = await _addPlayStoreWatermark(imageBytes);



      // Save to temporary file

      final tempDir = await getTemporaryDirectory();

      final fileName =

          'zaroori_sawal_result_${DateTime.now().millisecondsSinceEpoch}.png';

      final filePath = '${tempDir.path}/$fileName';

      final file = File(filePath);

      await file.writeAsBytes(processedImage);



      // Get share message

      final message = _getShareMessage(

        _percentage >= 50,

        _percentage,

        userName,

      );



      // Share file with message

      final xFile = XFile(filePath);

      await Share.shareXFiles(

        [xFile],

        text: message,

        subject: 'My Zarori Sawal Result!',

      );

    } catch (e) {

      _showShareError('Unable to share. Please try again.');

    } finally {

      if (mounted) {

        setState(() => _isSharing = false);

      }

    }

  }



  /// Adds Play Store link watermark to the bottom of the image

  Future<Uint8List> _addPlayStoreWatermark(Uint8List originalBytes) async {

    try {

      // Decode original image

      img.Image? original = img.decodePng(originalBytes);

      if (original == null) return originalBytes;



      // Create watermark section

      const watermarkHeight = 120;

      final newHeight = original.height + watermarkHeight;



      // Create new image with extra space

      img.Image newImage = img.Image(

        width: original.width,

        height: newHeight,

      );



      // Fill with dark background

      img.fill(newImage, color: img.ColorRgb8(45, 45, 45));



      // Copy original image to top

      img.compositeImage(newImage, original, dstX: 0, dstY: 0);



      // Add watermark text

      final textY = original.height + 20;



      // App name

      img.drawString(

        newImage,

        'Zarori Sawal - Learn & Play',

        font: img.arial24,

        x: (original.width ~/ 2) - 120,

        y: textY,

        color: img.ColorRgb8(255, 255, 255),

      );



      // Download message

      img.drawString(

        newImage,

        'Download the free app:',

        font: img.arial14,

        x: (original.width ~/ 2) - 70,

        y: textY + 35,

        color: img.ColorRgb8(200, 200, 200),

      );



      // Play Store URL

      img.drawString(

        newImage,

        _playStoreUrl,

        font: img.arial14,

        x: 20,

        y: textY + 60,

        color: img.ColorRgb8(66, 133, 244),

      );



      // Encode and return

      return Uint8List.fromList(img.encodePng(newImage));

    } catch (e) {

      // Return original if processing fails

      return originalBytes;

    }

  }



  void _showShareError(String message) {

    if (!mounted) return;



    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(message),

        backgroundColor: AppColors.error,

        behavior: SnackBarBehavior.floating,

        duration: const Duration(seconds: 3),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    final bool isSuccess = _percentage >= 50;

    

    // Get user name from provider

    final userProvider = context.watch<UserProvider>();

    final String userName = userProvider.userName?.trim() ?? 'Learner';



    // Motivational message & colors

    String message;

    Color accentColor;

    IconData resultIcon;

    

    if (isSuccess) {

      message = AppLocalizations.of(context).excellent;

      accentColor = AppColors.success;

      resultIcon = Icons.emoji_events;

    } else {

      message = AppLocalizations.of(context).dontGiveUp;

      accentColor = AppColors.primary;

      resultIcon = Icons.trending_up;

    }



    return TopBarScaffold(

      title: AppLocalizations.of(context).result,

      body: Stack(

        alignment: Alignment.center,

        children: [

          Center(

            child: AnimatedBuilder(

              animation: _cardBounceAnimation,

              builder: (context, child) {

                return Transform.translate(

                  offset: Offset(0, -_cardBounceAnimation.value),

                  child: child,

                );

              },

              child: Padding(

                padding: const EdgeInsets.all(AppSpacing.lg),

                child: Screenshot(

                  controller: _screenshotController,

                  child: Container(

                    decoration: BoxDecoration(

                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,

                      borderRadius: BorderRadius.circular(AppBorderRadius.xxl),

                      boxShadow: isDark ? AppShadows.cardDark : AppShadows.large,

                      border: Border.all(

                        color: accentColor.withValues(alpha: 0.3),

                        width: 2,

                      ),

                    ),

                    child: Padding(

                      padding: const EdgeInsets.all(AppSpacing.xxl),

                      child: Column(

                        mainAxisSize: MainAxisSize.min,

                        children: [

                          // User Name Display - Professional header

                          Container(

                            padding: const EdgeInsets.symmetric(

                              horizontal: AppSpacing.lg,

                              vertical: AppSpacing.sm,

                            ),

                            decoration: BoxDecoration(

                              gradient: LinearGradient(

                                colors: [

                                  accentColor.withValues(alpha: 0.2),

                                  accentColor.withValues(alpha: 0.05),

                                ],

                                begin: Alignment.topLeft,

                                end: Alignment.bottomRight,

                              ),

                              borderRadius: BorderRadius.circular(AppBorderRadius.xl),

                            ),

                            child: Row(

                              mainAxisSize: MainAxisSize.min,

                              children: [

                                Icon(

                                  Icons.person_outline,

                                  size: 18,

                                  color: accentColor,

                                ),

                                const SizedBox(width: AppSpacing.sm),

                                Text(

                                  userName,

                                  style: theme.textTheme.titleSmall?.copyWith(

                                    fontWeight: FontWeight.w600,

                                    color: accentColor,

                                  ),

                                ),

                              ],

                            ),

                          ),

                          const SizedBox(height: AppSpacing.lg),

                          

                          // Result Icon

                          Container(

                            width: 80,

                            height: 80,

                            decoration: BoxDecoration(

                              color: isSuccess ? AppColors.success : AppColors.primary,

                              borderRadius: BorderRadius.circular(AppBorderRadius.xxl),

                              boxShadow: [

                                BoxShadow(

                                  color: (isSuccess ? AppColors.success : AppColors.primary).withValues(alpha: 0.3),

                                  blurRadius: 12,

                                  spreadRadius: 2,

                                ),

                              ],

                            ),

                            child: Icon(

                              resultIcon,

                              size: 40,

                              color: Colors.white,

                            ),

                          ),

                          

                          const SizedBox(height: AppSpacing.xl),

                          

                          // Topic info

                          Container(

                            padding: const EdgeInsets.symmetric(

                              horizontal: AppSpacing.lg,

                              vertical: AppSpacing.sm,

                            ),

                            decoration: BoxDecoration(

                              color: accentColor.withValues(alpha: isDark ? 0.15 : 0.1),

                              borderRadius: BorderRadius.circular(AppBorderRadius.lg),

                            ),

                            child: Text(

                              "${widget.selectedLevel} - ${widget.selectedSubtopic}",

                              style: theme.textTheme.titleMedium?.copyWith(

                                fontWeight: FontWeight.w600,

                                color: accentColor,

                              ),

                            ),

                          ),

                          

                          const SizedBox(height: AppSpacing.xl),



                          // Score with pop animation

                          ScaleTransition(

                            scale: _scaleAnimation,

                            child: Text(

                              "${widget.score} / ${widget.total}",

                              style: theme.textTheme.displayMedium?.copyWith(

                                fontWeight: FontWeight.bold,

                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,

                              ),

                            ),

                          ),

                          const SizedBox(height: AppSpacing.sm),



                          // Animated percentage

                          TweenAnimationBuilder(

                            tween: Tween<double>(begin: 0, end: _percentage),

                            duration: const Duration(seconds: 1),

                            builder: (context, double value, child) {

                              return Text(

                                "${value.toStringAsFixed(0)}%",

                                style: theme.textTheme.headlineSmall?.copyWith(

                                  fontWeight: FontWeight.w600,

                                  color: accentColor,

                                ),

                              );

                            },

                          ),

                          const SizedBox(height: AppSpacing.lg),



                          // Correct / Wrong stats

                          Container(

                            padding: const EdgeInsets.all(AppSpacing.lg),

                            decoration: BoxDecoration(

                              color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,

                              borderRadius: BorderRadius.circular(AppBorderRadius.lg),

                            ),

                            child: Row(

                              mainAxisAlignment: MainAxisAlignment.center,

                              children: [

                                _buildStat(

                                  context,

                                  label: AppLocalizations.of(context).correct,

                                  value: "${widget.score}",

                                  color: AppColors.success,

                                  icon: Icons.check_circle,

                                ),

                                Container(

                                  height: 40,

                                  width: 1,

                                  color: isDark ? AppColors.dividerDark : AppColors.dividerLight,

                                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),

                                ),

                                _buildStat(

                                  context,

                                  label: AppLocalizations.of(context).wrong,

                                  value: "${widget.total - widget.score}",

                                  color: AppColors.error,

                                  icon: Icons.cancel,

                                ),

                              ],

                            ),

                          ),

                          const SizedBox(height: AppSpacing.lg),



                          // Motivational message

                          Text(

                            message,

                            textAlign: TextAlign.center,

                            style: theme.textTheme.titleMedium?.copyWith(

                              fontWeight: FontWeight.w600,

                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,

                            ),

                          ),

                          const SizedBox(height: AppSpacing.xxl),



                          // Buttons: Reattempt & Home

                          Row(

                            children: [

                              Expanded(

                                child: OutlinedButton.icon(

                                  onPressed: () {

                                    Navigator.pushReplacement(

                                      context,

                                      MaterialPageRoute(

                                        builder: (_) => TestScreen(

                                          selectedTopic: widget.selectedTopic,

                                          selectedLevel: widget.selectedLevel,

                                          selectedSubtopic: widget.selectedSubtopic,

                                          selectedCategory: widget.selectedCategory,

                                          selectedQuestionType: widget.selectedQuestionType,

                                        ),

                                      ),

                                    );

                                  },

                                  icon: const Icon(Icons.refresh, size: 18),

                                  label: Text(

                                    AppLocalizations.of(context).reattempt,

                                    softWrap: false,

                                    overflow: TextOverflow.ellipsis,

                                  ),

                                ),

                              ),

                              const SizedBox(width: AppSpacing.lg),

                              Expanded(

                                child: ElevatedButton.icon(

                                  onPressed: () {

                                    Navigator.pushAndRemoveUntil(

                                      context,

                                      MaterialPageRoute(

                                          builder: (_) =>

                                              const MainSelectionScreen()),

                                      (route) => false,

                                    );

                                  },

                                  icon: const Icon(Icons.home),

                                  label: Text(AppLocalizations.of(context).home),

                                ),

                              ),

                            ],

                          ),

                        ],

                      ),

                    ),

                  ),

                ),

              ),

            ),

          ),

          // Confetti

          if (isSuccess)

            Positioned.fill(

              child: ConfettiWidget(

                confettiController: _confettiController,

                blastDirectionality: BlastDirectionality.explosive,

                shouldLoop: false,

                colors: const [

                  AppColors.success,

                  AppColors.primary,

                  AppColors.secondary,

                  AppColors.info,

                  AppColors.primaryLight,

                ],

                numberOfParticles: 30,

                maxBlastForce: 25,

                minBlastForce: 5,

                emissionFrequency: 0.05,

              ),

            ),

          // Share Button - Floating Action Button style

          Positioned(

            bottom: 20,

            right: 20,

            child: AnimatedContainer(

              duration: const Duration(milliseconds: 200),

              child: FloatingActionButton.extended(

                onPressed: _isSharing ? null : _shareResult,

                backgroundColor: AppColors.primary,

                icon: _isSharing

                    ? const SizedBox(

                        width: 20,

                        height: 20,

                        child: CircularProgressIndicator(

                          strokeWidth: 2,

                          color: Colors.white,

                        ),

                      )

                    : const Icon(Icons.share, color: Colors.white),

                label: Text(

                  _isSharing ? AppLocalizations.of(context).sharing : AppLocalizations.of(context).shareResult,

                  style: const TextStyle(

                    color: Colors.white,

                    fontWeight: FontWeight.w600,

                  ),

                ),

              ),

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildStat(

    BuildContext context, {

    required String label,

    required String value,

    required Color color,

    required IconData icon,

  }) {

    final theme = Theme.of(context);

    

    return Column(

      children: [

        Icon(icon, color: color, size: 20),

        const SizedBox(height: AppSpacing.xs),

        Text(

          label,

          style: theme.textTheme.labelSmall?.copyWith(

            color: theme.colorScheme.outline,

          ),

        ),

        const SizedBox(height: AppSpacing.xs),

        Text(

          value,

          style: theme.textTheme.titleLarge?.copyWith(

            fontWeight: FontWeight.bold,

            color: color,

          ),

        ),

      ],

    );

  }

}

