import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'avatar_selection_screen.dart';
import '../widgets/top_bar_scaffold.dart';
import '../providers/user_provider.dart';
import '../utils/app_theme.dart';
import '../services/notification_service.dart';
import 'main_selection_screen.dart';

/// Main onboarding screen where user enters their name
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedAvatar;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserData());
    _animationController.forward();
    
    // Check notification permission from screen context
    Future.delayed(const Duration(milliseconds: 1000), () {
      NotificationService.checkPermissionFromScreen();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Load saved avatar and user name from provider
  void _loadUserData() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    setState(() {
      _nameController.text = userProvider.userName ?? '';
      _selectedAvatar = userProvider.selectedAvatar;
    });
  }

  /// Save user name and navigate to MainSelectionScreen
  Future<void> _saveNameAndProceed() async {
    String name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Please enter your name'),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.setUserName(name);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainSelectionScreen()),
    );
  }

  /// Open Avatar Selection Screen
  Future<void> _chooseAvatar() async {
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

    return TopBarScaffold(
      title: "Welcome",
      leadingWidget: GestureDetector(
        onTap: _chooseAvatar,
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? Colors.white54 : Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipOval(
            child: _selectedAvatar != null
                ? Image.asset(_selectedAvatar!, fit: BoxFit.cover)
                : Container(
                    color: Colors.white24,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: child,
            );
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                
                // App Logo / Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.gradientPrimary,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
                    boxShadow: AppShadows.glowPrimary,
                  ),
                  child: const Icon(
                    Icons.school,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xxxl),
                
                // Welcome Text
                Text(
                  'Welcome to',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xs),
                
                Text(
                  'Zarori Sawal',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                  ),
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                Text(
                  'Your Personal Learning Companion',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xxxxl),
                
                // Name Input Card
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                    boxShadow: isDark ? AppShadows.cardDark : AppShadows.cardLight,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What should we call you?',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      
                      const SizedBox(height: AppSpacing.md),
                      
                      Text(
                        'Enter a cute name that you like',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        ),
                      ),
                      
                      const SizedBox(height: AppSpacing.lg),
                      
                      // Name Input Field
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'Enter your name...',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                          ),
                          filled: true,
                          fillColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                        ),
                      ),
                      
                      const SizedBox(height: AppSpacing.xl),
                      
                      // Get Started Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveNameAndProceed,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xxxxl),
                
                // Avatar Selection Hint
                GestureDetector(
                  onTap: _chooseAvatar,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.face,
                          size: 20,
                          color: isDark ? AppColors.primaryLight : AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Tap avatar to choose your look',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.primaryLight : AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xxl),
                
                // Footer
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? AppColors.surfaceDark.withValues(alpha: 0.8)
                        : AppColors.surfaceLight.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    boxShadow: isDark ? AppShadows.cardDark : AppShadows.small,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.code,
                            size: 14,
                            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Developed by',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'M. Junaid Gohar',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'J_studio',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark ? AppColors.primaryLight : AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
