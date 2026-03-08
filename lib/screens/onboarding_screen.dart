import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'avatar_selection_screen.dart';
import '../providers/user_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/app_theme.dart';
import '../services/notification_service.dart';
import '../services/avatar_image_service.dart';
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
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _nameController.text.trim().isEmpty
                    ? l10n.pleaseEnterYourName
                    : l10n.nameShouldBeAtLeast2Characters,
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
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Top avatar selector
                    _buildAvatarSelector(isDark),
                    
                    SizedBox(height: 32.h),
                    
                    // Animated mascot
                    _buildAnimatedMascot(isDark),
                    
                    SizedBox(height: 32.h),
                    
                    // Welcome content with staggered animation
                    FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideUp,
                        child: Column(
                          children: [
                            // Welcome badge
                            _buildWelcomeBadge(theme, isDark),
                            
                            SizedBox(height: 24.h),
                            
                            // Main heading
                            Text(
                              AppLocalizations.of(context).beginYourLearningJourney,
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
                              AppLocalizations.of(context).joinThousandsOfLearners,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark 
                                    ? AppColors.textSecondaryDark 
                                    : AppColors.textSecondaryLight,
                                height: 1.5,
                              ),
                            ),
                            
                            SizedBox(height: 40.h),
                            
                            // Name input card
                            _buildNameInputCard(theme, isDark),
                            
                            SizedBox(height: 24.h),
                            
                            // Get started button
                            _buildGetStartedButton(theme, isDark),
                            
                            SizedBox(height: 32.h),
                            
                            // Trust indicators
                            _buildTrustIndicators(theme, isDark),
                            
                            SizedBox(height: 40.h),
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
    // Simplified background with subtle color only
    return Container(
      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
    );
  }

  Widget _buildAvatarSelector(bool isDark) {
    return GestureDetector(
      onTap: _chooseAvatar,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: _selectedAvatar != null
                  ? _buildAvatarImage(_selectedAvatar!)
                  : Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 28.sp,
                    ),
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit,
                  size: 14.sp,
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                ),
                SizedBox(width: 4.w),
                Text(
                  AppLocalizations.of(context).tapToCustomize,
                  style: TextStyle(
                    fontSize: 12.sp,
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
      child: Container(
        width: 120.w,
        height: 120.w,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(32.r),
        ),
        child: Icon(
          Icons.school,
          size: 56.sp,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildWelcomeBadge(ThemeData theme, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(isDark ? 0.3 : 0.2),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.celebration,
            size: 18.sp,
            color: isDark ? AppColors.primaryLight : AppColors.primary,
          ),
          SizedBox(width: 8.w),
          Text(
            AppLocalizations.of(context).welcome,
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
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
      ),
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label with icon
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 20.sp,
                color: isDark ? AppColors.primaryLight : AppColors.primary,
              ),
              SizedBox(width: 8.w),
              Text(
                AppLocalizations.of(context).whatShouldWeCallYou,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8.h),
          
          Text(
            AppLocalizations.of(context).chooseNameThatInspires,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
          ),
          
          SizedBox(height: 16.h),
          
          // Name input field
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).enterYourName,
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
                      margin: EdgeInsets.all(8.w),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16.sp,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: isDark
                  ? AppColors.backgroundDark
                  : AppColors.backgroundLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(
                  color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide(
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 16.h,
              ),
            ),
          ),
          
          SizedBox(height: 8.h),
          
          // Character count hint
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${_nameController.text.length}/20 ${AppLocalizations.of(context).characters}',
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
          padding: EdgeInsets.symmetric(vertical: 18.h),
          decoration: BoxDecoration(
            color: _isNameValid
                ? (isDark ? AppColors.primaryLight : AppColors.primary)
                : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isNameValid ? AppLocalizations.of(context).startLearningJourney : AppLocalizations.of(context).enterYourNameButton,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: _isNameValid
                      ? Colors.white
                      : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_isNameValid) ...[
                SizedBox(width: 8.w),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 20.sp,
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
      spacing: 16.w,
      runSpacing: 12.h,
      alignment: WrapAlignment.center,
      children: [
        _buildTrustItem(
          icon: Icons.verified_user,
          label: AppLocalizations.of(context).freeForever,
          isDark: isDark,
        ),
        _buildTrustItem(
          icon: Icons.offline_bolt,
          label: AppLocalizations.of(context).learnOffline,
          isDark: isDark,
        ),
        _buildTrustItem(
          icon: Icons.emoji_events,
          label: AppLocalizations.of(context).earnRewards,
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
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)
            .withOpacity(0.6),
        borderRadius: BorderRadius.circular(20.r),
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
            size: 16.sp,
            color: isDark ? AppColors.primaryLight : AppColors.primary,
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  /// Build avatar image widget - handles both assets and file paths
  Widget _buildAvatarImage(String avatarPath) {
    if (AvatarImageService.isCustomAvatar(avatarPath)) {
      // Custom photo from file
      return Image.file(
        File(avatarPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: Icon(Icons.broken_image, color: Colors.grey[600]),
          );
        },
      );
    } else {
      // Asset image
      return Image.asset(
        avatarPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: Icon(Icons.broken_image, color: Colors.grey[600]),
          );
        },
      );
    }
  }
}
