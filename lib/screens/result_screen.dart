// result_screen.dart

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:confetti/confetti.dart';
import '../widgets/top_bar_scaffold.dart';
import '../screens/main_selection_screen.dart';
import '../screens/test_screen.dart';
import 'dart:math';

class ResultScreen extends StatefulWidget {
  final int score;
  final int total;
  final String selectedClass;
  final String selectedCategory;
  final String selectedSubject;
  final String selectedQuestionType;
  final String selectedUnit;

  const ResultScreen({
    super.key,
    required this.score,
    required this.total,
    required this.selectedClass,
    required this.selectedCategory,
    required this.selectedSubject,
    required this.selectedQuestionType,
    required this.selectedUnit,
  });

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

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
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-5721278995377651/6519657994',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
          _interstitialAd!.show();
        },
        onAdFailedToLoad: (error) {
          _isAdLoaded = false;
          debugPrint('Interstitial Ad failed to load: $error');
        },
      ),
    );
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    String percentString = _percentage.toStringAsFixed(0);

    // Motivational message & card color
    String message;
    Color cardColor;
    if (_percentage >= 50) {
      message = "Excellent! 🎉 Keep it up!";
      cardColor = Colors.green.shade300;
    } else {
      message = "Don't give up 😓 You can do it!";
      cardColor = Colors.red.shade300;
    }

    return TopBarScaffold(
      title: "Result",
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
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: isDark ? Colors.grey[850] : cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 24, horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${widget.selectedSubject} - ${widget.selectedUnit}",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Score with pop animation
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: Text(
                            "${widget.score} / ${widget.total}",
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Animated percentage
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: _percentage),
                          duration: const Duration(seconds: 1),
                          builder: (context, double value, child) {
                            return Text(
                              "${value.toStringAsFixed(0)}%",
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color:
                                    isDark ? Colors.white70 : Colors.black54,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Correct / Wrong
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                Text(
                                  "Correct",
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${widget.score}",
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 32),
                            Column(
                              children: [
                                Text(
                                  "Wrong",
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${widget.total - widget.score}",
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Motivational message
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(height: 32),

                        // Buttons: Reattempt & Home
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TestScreen(
                                        selectedClass: widget.selectedClass,
                                        selectedCategory:
                                            widget.selectedCategory,
                                        selectedSubject:
                                            widget.selectedSubject,
                                        selectedQuestionType:
                                            widget.selectedQuestionType,
                                        selectedUnit: widget.selectedUnit,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                  elevation: 5,
                                  backgroundColor: Colors.transparent,
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        theme.colorScheme.primary,
                                        theme.colorScheme.secondary
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: const Text(
                                      "Reattempt",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 32),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const MainSelectionScreen()),
                                    (route) => false,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                  elevation: 5,
                                  backgroundColor: Colors.transparent,
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        theme.colorScheme.primary,
                                        theme.colorScheme.secondary
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: const Text(
                                      "Home",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Confetti
          if (_percentage >= 50)
            Positioned.fill(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple
                ],
                numberOfParticles: 30,
                maxBlastForce: 25,
                minBlastForce: 5,
                emissionFrequency: 0.05,
              ),
            ),
        ],
      ),
    );
  }
}
