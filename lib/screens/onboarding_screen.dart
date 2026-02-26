import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'avatar_selection_screen.dart';
import '../providers/user_provider.dart';
import '../utils/app_theme.dart';
import '../services/notification_service.dart';
import 'main_selection_screen.dart';

/// Enhanced Onboarding Screen
/// Features: Animated mascot, staggered animations, glassmorphism, engaging copy
/// Optimized for both light and dark themes
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedAvatar;
  bool _isNameValid = false;
  bool _isButtonPressed = false;

  // Animation controllers
  late AnimationController _mascotController;
  late AnimationController _staggerController;
  late AnimationController _floatController;
  
  // Animations
  late Animation<double> _mascotScale;
  late Animation<double> _mascotFloat;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  late Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
    
    // Check notification permission
    Future.delayed(const Duration(milliseconds: 1500), () {
      NotificationService.checkPermissionFromScreen();
    });

    // Listen for name changes
    _nameController.addListener(_onNameChanged);
  }

  void _initializeAnimations() {
    // Mascot breathing/floating animation
    _mascotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _mascotScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _mascotController,
        curve: Curves.elasticOut,
      ),
    );

    // Staggered entrance animations
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeIn = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideUp = Tween<Offset>(
      begin: const Offset(0, 40),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    // Floating animation for decorative elements
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _mascotFloat = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOutSine,
      ),
    );

    _glowPulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animations
    _mascotController.forward();
    _staggerController.forward();
  }

  void _onNameChanged() {
    final isValid = _nameController.text.trim().isNotEmpty &&
                   _nameController.text.trim().length >= 2;
    if (isValid != _isNameValid) {
      setState(() => _isNameValid = isValid);
    }
  }

  @override
  void dispose() {
    _mascotController.dispose();
    _staggerController.dispose();
    _floatController.dispose();
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    setState(() {
      _nameController.text = userProvider.userName ?? '';
      _selectedAvatar = userProvider.selectedAvatar;
      _isNameValid = _nameController.text.trim().isNotEmpty;
    });
  }

  Future<void> _saveNameAndProceed() async {
    if (!_isNameValid) {
      _showErrorSnackBar();
      return;
    }

    setState(() => _isButtonPressed = true);
    HapticFeedback.mediumImpact();

    final name = _nameController.text.trim();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.setUserName(name);

    if (!mounted) return;

    // Celebrate with animation then navigate
    await Future.delayed(const Duration(milliseconds: 300));
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const MainSelectionScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _showErrorSnackBar() {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _nameController.text.trim().isEmpty
                    ? 'Please enter your name to continue'
                    : 'Name should be at least 2 characters',
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _chooseAvatar() async {
    HapticFeedback.lightImpact();
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AvatarSelectionScreen()),
    );

    if (selected != null && mounted) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.setAvatar(selected);
      setState(() => _selectedAvatar = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient bubbles
            _buildBackgroundBubbles(isDark, size),
            
            // Main content
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Top avatar selector
                    _buildAvatarSelector(isDark),
                    
                    const SizedBox(height: 32),
                    
                    // Animated mascot
                    _buildAnimatedMascot(isDark),
                    
                    const SizedBox(height: 32),
                    
                    // Welcome content with staggered animation
                    FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideUp,
                        child: Column(
                          children: [
                            // Welcome badge
                            _buildWelcomeBadge(theme, isDark),
                            
                            const SizedBox(height: 24),
                            
                            // Main heading
                            Text(
                              'Begin Your\nLearning Journey!',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Subtitle
                            Text(
                              'Join thousands of learners mastering\nEnglish, Web Dev, Digital Marketing & more',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark 
                                    ? AppColors.textSecondaryDark 
                                    : AppColors.textSecondaryLight,
                                height: 1.5,
                              ),
                            ),
                            
                            const SizedBox(height: 40),
                            
                            // Name input card
                            _buildNameInputCard(theme, isDark),
                            
                            const SizedBox(height: 24),
                            
                            // Get started button
                            _buildGetStartedButton(theme, isDark),
                            
                            const SizedBox(height: 32),
                            
                            // Trust indicators
                            _buildTrustIndicators(theme, isDark),
                            
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundBubbles(bool isDark, Size size) {
    return Stack(
      children: [
        // Top right bubble
        Positioned(
          top: -size.height * 0.1,
          right: -size.width * 0.2,
          child: AnimatedBuilder(
            animation: _floatController,
            builder: (_, __) {
              return Transform.translate(
                offset: Offset(0, _mascotFloat.value * 0.5),
                child: Container(
                  width: size.width * 0.6,
                  height: size.width * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isDark ? AppColors.primaryLight : AppColors.primary)
                            .withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Bottom left bubble
        Positioned(
          bottom: size.height * 0.15,
          left: -size.width * 0.3,
          child: AnimatedBuilder(
            animation: _floatController,
            builder: (_, __) {
              return Transform.translate(
                offset: Offset(0, -_mascotFloat.value * 0.3),
                child: Container(
                  width: size.width * 0.5,
                  height: size.width * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isDark ? AppColors.secondaryLight : AppColors.secondary)
                            .withOpacity(0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarSelector(bool isDark) {
    return GestureDetector(
      onTap: _chooseAvatar,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppColors.primaryLight, AppColors.primary]
                    : [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 3,
              ),
            ),
            child: ClipOval(
              child: _selectedAvatar != null
                  ? Image.asset(_selectedAvatar!, fit: BoxFit.cover)
                  : const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 28,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)
                  .withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isDark ? AppColors.dividerDark : AppColors.dividerLight)
                    .withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit,
                  size: 14,
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Tap to customize',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedMascot(bool isDark) {
    return ScaleTransition(
      scale: _mascotScale,
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (_, __) {
          return Transform.translate(
            offset: Offset(0, _mascotFloat.value),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow effect
                AnimatedBuilder(
                  animation: _glowPulse,
                  builder: (_, __) {
                    return Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (isDark ? AppColors.primaryLight : AppColors.primary)
                                .withOpacity(0.2 * _glowPulse.value),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                // Main mascot container
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                          : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5))
                            .withOpacity(0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
                
                // Floating sparkles
                Positioned(
                  top: 0,
                  right: 0,
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Icon(
                      Icons.star,
                      size: 24,
                      color: Colors.amber.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeBadge(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.secondary.withOpacity(0.2), AppColors.primary.withOpacity(0.2)]
              : [AppColors.secondary.withOpacity(0.15), AppColors.primary.withOpacity(0.15)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.celebration,
            size: 18,
            color: isDark ? AppColors.primaryLight : AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Welcome to Zarori Sawal',
            style: theme.textTheme.labelLarge?.copyWith(
              color: isDark ? AppColors.primaryLight : AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameInputCard(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.surfaceDark.withOpacity(0.8),
                  AppColors.surfaceDark.withOpacity(0.6),
                ]
              : [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isDark ? AppColors.dividerDark : AppColors.dividerLight)
              .withOpacity(0.5),
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: -4,
                ),
              ]
            : AppShadows.cardLight,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label with icon
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 20,
                color: isDark ? AppColors.primaryLight : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'What should we call you?',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Choose a name that inspires you to learn',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Name input field
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
            decoration: InputDecoration(
              hintText: 'Enter your name...',
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: isDark 
                    ? AppColors.textTertiaryDark.withOpacity(0.5)
                    : AppColors.textTertiaryLight.withOpacity(0.6),
              ),
              prefixIcon: Icon(
                Icons.face,
                color: isDark ? AppColors.primaryLight : AppColors.primary,
              ),
              suffixIcon: _isNameValid
                  ? Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: isDark
                  ? AppColors.backgroundDark.withOpacity(0.5)
                  : AppColors.backgroundLight.withOpacity(0.7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: (isDark ? AppColors.dividerDark : AppColors.dividerLight)
                      .withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Character count hint
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${_nameController.text.length}/20 characters',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _nameController.text.length > 20
                      ? AppColors.error
                      : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGetStartedButton(ThemeData theme, bool isDark) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isButtonPressed = true),
      onTapUp: (_) => setState(() => _isButtonPressed = false),
      onTapCancel: () => setState(() => _isButtonPressed = false),
      onTap: _saveNameAndProceed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..scale(_isButtonPressed ? 0.95 : 1.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isNameValid
                  ? (isDark
                      ? [AppColors.primaryLight, const Color(0xFF8B5CF6)]
                      : [AppColors.primary, const Color(0xFF7C3AED)])
                  : (isDark
                      ? [AppColors.surfaceDark, AppColors.surfaceDark]
                      : [AppColors.surfaceLight, AppColors.surfaceLight]),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: _isNameValid
                ? [
                    BoxShadow(
                      color: (isDark ? AppColors.primaryLight : AppColors.primary)
                          .withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isNameValid ? 'Start Learning Journey' : 'Enter Your Name',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: _isNameValid
                      ? Colors.white
                      : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_isNameValid) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrustIndicators(ThemeData theme, bool isDark) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _buildTrustItem(
          icon: Icons.verified_user,
          label: 'Free Forever',
          isDark: isDark,
        ),
        _buildTrustItem(
          icon: Icons.offline_bolt,
          label: 'Learn Offline',
          isDark: isDark,
        ),
        _buildTrustItem(
          icon: Icons.emoji_events,
          label: 'Earn Rewards',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildTrustItem({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)
            .withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? AppColors.dividerDark : AppColors.dividerLight)
              .withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? AppColors.primaryLight : AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
