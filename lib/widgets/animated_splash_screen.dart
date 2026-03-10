import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Professional Splash Screen with elegant fade in/out animation
/// Displays during app initialization while services are loading
class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _animationsComplete = false;

  @override
  void initState() {
    super.initState();

    // Fade animation controller: 2.5 seconds total
    // Fade in: 0-800ms, Hold: 800ms-1700ms, Fade out: 1700ms-2500ms
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Scale animation for subtle pulse effect
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Fade animation with curve for smooth transitions
    _fadeAnimation = TweenSequence<double>([
      // Fade in phase
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 32, // 0-800ms
      ),
      // Hold phase (visible)
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 36, // 800ms-1700ms
      ),
      // Fade out phase
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(
          CurveTween(curve: Curves.easeInCubic),
        ),
        weight: 32, // 1700ms-2500ms
      ),
    ]).animate(_fadeController);

    // Subtle scale pulse: 0.85 -> 1.0 -> 0.95
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.85, end: 1.0).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.95).chain(
          CurveTween(curve: Curves.easeInOutSine),
        ),
        weight: 60,
      ),
    ]).animate(_scaleController);

    // Start animations
    _fadeController.forward();
    _scaleController.forward();

    // Listen for animation completion
    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _animationsComplete = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.3),
                blurRadius: 60,
                spreadRadius: 10,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/js_logo/js_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Error loading logo: $error');
                return Container(
                  color: const Color(0xFF6366F1),
                  child: const Icon(
                    Icons.school,
                    size: 80,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
