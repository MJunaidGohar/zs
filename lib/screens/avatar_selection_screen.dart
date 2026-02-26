import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/top_bar_scaffold.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../utils/app_theme.dart';

/// ------------------------------------------------------------
/// Avatar Selection Screen
/// ------------------------------------------------------------
/// Lets user pick an avatar from available options.
/// Saves selection via [UserProvider] (which also updates
/// SharedPreferences), and closes the screen.
/// ------------------------------------------------------------
class AvatarSelectionScreen extends StatefulWidget {
  const AvatarSelectionScreen({super.key});

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen>
    with SingleTickerProviderStateMixin {
  // Static constants to avoid recreating every build
  static const List<String> _avatars = [
    'assets/avatar/boy_avatar.png',
    'assets/avatar/girl_avatar.png',
  ];
  
  // Pre-cached asset images for better performance
  late final List<AssetImage> _avatarImages;
  
  String? _hoveredAvatar;
  String? _selectedAvatar;
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: AppDurations.slow,
    );
    // Pre-cache avatar images
    _avatarImages = _avatars.map((path) => AssetImage(path)).toList();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TopBarScaffold(
      title: "Select Your Avatar",
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.backgroundDark,
                    Color(0xFF1E1B4B),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.backgroundLight,
                    Color(0xFFE0E7FF),
                  ],
                ),
        ),
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: AppSpacing.xxxl),

                  // Animated Header Card with Gradient - RepaintBoundary for isolation
                  RepaintBoundary(
                    child: TweenAnimationBuilder<double>(
                      duration: AppDurations.slower,
                      tween: Tween(begin: 0, end: 1),
                      curve: AppCurves.bounce,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.8 + (0.2 * value),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: _buildHeaderCard(theme, isDark),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxxxl),

                  // Avatar Selection Grid - use Wrap instead of Row to prevent overflow
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: _buildAvatarItems(theme, isDark),
                  ),

                  const SizedBox(height: AppSpacing.xxxxl),

                  // Hint Text
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 18,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Tap on an avatar to select',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF312E81),
                  Color(0xFF4C1D95),
                ]
              : AppColors.gradientLightHeader,
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.xxl),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.face_rounded,
              size: 56,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Choose Your Look',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Select an avatar that represents you',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Build avatar items - extracted for performance
  List<Widget> _buildAvatarItems(ThemeData theme, bool isDark) {
    return List.generate(_avatars.length, (index) {
      final avatarPath = _avatars[index];
      final isBoy = avatarPath.contains('boy');
      
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: _AvatarItem(
          index: index,
          avatarPath: avatarPath,
          avatarImage: _avatarImages[index],
          isBoy: isBoy,
          isDark: isDark,
          bounceController: _bounceController,
          onSelected: (path) async {
            HapticFeedback.mediumImpact();
            setState(() => _selectedAvatar = path);
            
            await _bounceController.forward();
            _bounceController.reverse();
            
            final userProvider = Provider.of<UserProvider>(context, listen: false);
            await userProvider.setAvatar(path);
            
            if (!context.mounted) return;
            Navigator.pop(context, path);
          },
        ),
      );
    });
  }
}

// Extracted widget for individual avatar items - prevents rebuilds
class _AvatarItem extends StatefulWidget {
  final int index;
  final String avatarPath;
  final AssetImage avatarImage;
  final bool isBoy;
  final bool isDark;
  final AnimationController bounceController;
  final Function(String) onSelected;

  const _AvatarItem({
    required this.index,
    required this.avatarPath,
    required this.avatarImage,
    required this.isBoy,
    required this.isDark,
    required this.bounceController,
    required this.onSelected,
  });

  @override
  State<_AvatarItem> createState() => _AvatarItemState();
}

class _AvatarItemState extends State<_AvatarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final delay = widget.index * 150;
    
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + delay),
      tween: Tween(begin: 0, end: 1),
      curve: AppCurves.bounce,
      builder: (context, value, child) {
        final delayedValue = delay > 0 
            ? ((value * 1000 - delay) / (1000 - delay)).clamp(0.0, 1.0) 
            : value;
        
        return Transform.translate(
          offset: Offset(0, 30 * (1 - delayedValue)),
          child: Opacity(
            opacity: delayedValue,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => widget.onSelected(widget.avatarPath),
        child: AnimatedContainer(
          duration: AppDurations.normal,
          curve: AppCurves.defaultCurve,
          transform: Matrix4.identity()..scale(_isHovered ? 1.08 : 1.0),
          onEnd: () {
            // Reset hover after animation completes if needed
          },
          child: Column(
            children: [
              _buildAvatarCard(),
              const SizedBox(height: AppSpacing.lg),
              _buildLabelBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarCard() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _isHovered
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isDark
                      ? const [
                          AppColors.primaryLight,
                          AppColors.accentPurple,
                        ]
                      : const [
                          AppColors.primary,
                          AppColors.accentPurple,
                        ],
                )
              : null,
          border: Border.all(
            color: _isHovered
                ? Colors.transparent
                : widget.isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : AppColors.dividerLight,
            width: 3,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: widget.isDark
                        ? AppColors.primaryLight.withValues(alpha: 0.5)
                        : AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: 6,
                  ),
                ]
              : [
                  BoxShadow(
                    color: widget.isDark
                        ? Colors.black.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: widget.avatarImage,
              fit: BoxFit.cover,
            ),
            border: Border.all(
              color: widget.isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.white,
              width: 3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabelBadge() {
    return AnimatedContainer(
      duration: AppDurations.normal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: _isHovered
            ? LinearGradient(
                colors: widget.isDark
                    ? const [
                        AppColors.primaryLight,
                        AppColors.accentPurple,
                      ]
                    : const [
                        AppColors.primary,
                        AppColors.accentPurple,
                      ],
              )
            : null,
        color: _isHovered
            ? null
            : widget.isDark
                ? AppColors.surfaceDark.withValues(alpha: 0.8)
                : AppColors.surfaceLight.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppBorderRadius.circular),
        boxShadow: _isHovered
            ? [
                BoxShadow(
                  color: widget.isDark
                      ? AppColors.primaryLight.withValues(alpha: 0.3)
                      : AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : AppShadows.small,
      ),
      child: Text(
        widget.isBoy ? 'Boy Avatar' : 'Girl Avatar',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: _isHovered
              ? Colors.white
              : widget.isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
        ),
      ),
    );
  }
}
