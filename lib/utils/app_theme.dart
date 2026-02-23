import 'package:flutter/material.dart';

/// ------------------------------------------------------------
/// App Design System - Zarori Sawal
/// ------------------------------------------------------------
/// A comprehensive design system providing consistent colors,
/// typography, spacing, and component styles across the app.
/// ------------------------------------------------------------

/// ==================== COLOR PALETTE ====================

/// Primary Colors - Deep Indigo/Violet theme for professional look
class AppColors {
  // Primary Brand Colors
  static const Color primaryLight = Color(0xFF6366F1);    // Indigo 500
  static const Color primary = Color(0xFF4F46E5);       // Indigo 600
  static const Color primaryDark = Color(0xFF4338CA);   // Indigo 700
  
  // Secondary Colors - Teal accent
  static const Color secondaryLight = Color(0xFF2DD4BF); // Teal 400
  static const Color secondary = Color(0xFF14B8A6);      // Teal 500
  static const Color secondaryDark = Color(0xFF0D9488);  // Teal 600
  
  // Accent Colors
  static const Color accentPurple = Color(0xFF8B5CF6);   // Violet 500
  static const Color accentPink = Color(0xFFEC4899);     // Pink 500
  static const Color accentOrange = Color(0xFFF97316);   // Orange 500
  static const Color accentGreen = Color(0xFF10B981);    // Emerald 500
  static const Color accentRed = Color(0xFFEF4444);      // Red 500
  static const Color accentYellow = Color(0xFFF59E0B);   // Amber 500
  static const Color accentBlue = Color(0xFF3B82F6);     // Blue 500
  
  // Background Colors - Light Theme
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF);    // White
  static const Color cardLight = Color(0xFFFFFFFF);     // White
  static const Color dividerLight = Color(0xFFE2E8F0);  // Slate 200
  
  // Background Colors - Dark Theme
  static const Color backgroundDark = Color(0xFF0F172A);  // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B);     // Slate 800
  static const Color cardDark = Color(0xFF1E293B);        // Slate 800
  static const Color dividerDark = Color(0xFF334155);     // Slate 700
  
  // Text Colors - Light Theme
  static const Color textPrimaryLight = Color(0xFF0F172A);   // Slate 900
  static const Color textSecondaryLight = Color(0xFF475569); // Slate 600
  static const Color textTertiaryLight = Color(0xFF94A3B8);    // Slate 400
  
  // Text Colors - Dark Theme
  static const Color textPrimaryDark = Color(0xFFF1F5F9);    // Slate 100
  static const Color textSecondaryDark = Color(0xFFCBD5E1);  // Slate 300
  static const Color textTertiaryDark = Color(0xFF64748B);   // Slate 500
  
  // Semantic Colors
  static const Color success = Color(0xFF10B981);   // Emerald 500
  static const Color successLight = Color(0xFFD1FAE5); // Emerald 100
  static const Color warning = Color(0xFFF59E0B);   // Amber 500
  static const Color warningLight = Color(0xFFFEF3C7); // Amber 100
  static const Color error = Color(0xFFEF4444);     // Red 500
  static const Color errorLight = Color(0xFFFEE2E2);  // Red 100
  static const Color info = Color(0xFF3B82F6);      // Blue 500
  static const Color infoLight = Color(0xFFDBEAFE);   // Blue 100
  
  // Gradient Colors - Enhanced for both modes
  static const List<Color> gradientPrimary = [
    Color(0xFF6366F1), // Indigo 500
    Color(0xFF8B5CF6), // Violet 500
  ];
  
  static const List<Color> gradientSecondary = [
    Color(0xFF14B8A6), // Teal 500
    Color(0xFF06B6D4), // Cyan 500
  ];
  
  static const List<Color> gradientSuccess = [
    Color(0xFF10B981), // Emerald 500
    Color(0xFF34D399), // Emerald 400
  ];
  
  static const List<Color> gradientDarkHeader = [
    Color(0xFF3730A3), // Indigo 800
    Color(0xFF4C1D95), // Violet 900
  ];
  
  static const List<Color> gradientLightHeader = [
    Color(0xFF6366F1), // Indigo 500
    Color(0xFFA855F7), // Purple 500
  ];
  
  // Dark mode specific gradients for cards
  static const List<Color> gradientDarkCard = [
    Color(0xFF1E293B), // Slate 800
    Color(0xFF0F172A), // Slate 900
  ];
  
  // Accent gradients for attractive UI elements
  static const List<Color> gradientAccentWarm = [
    Color(0xFFF59E0B), // Amber 500
    Color(0xFFF97316), // Orange 500
  ];
  
  static const List<Color> gradientAccentCool = [
    Color(0xFF3B82F6), // Blue 500
    Color(0xFF06B6D4), // Cyan 500
  ];
  
  static const List<Color> gradientAccentPurple = [
    Color(0xFF8B5CF6), // Violet 500
    Color(0xFFEC4899), // Pink 500
  ];
}

/// ==================== TYPOGRAPHY ====================

class AppTypography {
  // Font Families
  static const String fontFamily = 'Roboto';
  
  // Display Styles
  static TextStyle displayLarge(BuildContext context) => TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: Theme.of(context).colorScheme.onSurface,
  );
  
  static TextStyle displayMedium(BuildContext context) => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    color: Theme.of(context).colorScheme.onSurface,
  );
  
  static TextStyle displaySmall(BuildContext context) => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    color: Theme.of(context).colorScheme.onSurface,
  );
  
  // Headline Styles
  static TextStyle headlineLarge(BuildContext context) => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurface,
  );
  
  static TextStyle headlineMedium(BuildContext context) => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurface,
  );
  
  static TextStyle headlineSmall(BuildContext context) => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurface,
  );
  
  // Title Styles
  static TextStyle titleLarge(BuildContext context) => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurface,
  );
  
  static TextStyle titleMedium(BuildContext context) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurface,
  );
  
  static TextStyle titleSmall(BuildContext context) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurface,
  );
  
  // Body Styles
  static TextStyle bodyLarge(BuildContext context) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5,
    color: Theme.of(context).colorScheme.onSurface,
  );
  
  static TextStyle bodyMedium(BuildContext context) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
    color: Theme.of(context).colorScheme.onSurface,
  );
  
  static TextStyle bodySmall(BuildContext context) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.4,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
  
  // Label Styles
  static TextStyle labelLarge(BuildContext context) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Theme.of(context).colorScheme.onSurface,
  );
  
  static TextStyle labelMedium(BuildContext context) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
  
  static TextStyle labelSmall(BuildContext context) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

/// ==================== SPACING ====================

class AppSpacing {
  // Base unit: 4
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double xxxxl = 48;
  
  // Screen Padding
  static const double screenPadding = 16;
  static const double cardPadding = 16;
  static const double sectionSpacing = 24;
  
  // Component Sizes
  static const double buttonHeight = 48;
  static const double iconSizeSmall = 20;
  static const double iconSizeMedium = 24;
  static const double iconSizeLarge = 32;
  static const double avatarSizeSmall = 40;
  static const double avatarSizeMedium = 56;
  static const double avatarSizeLarge = 80;
}

/// ==================== BORDER RADIUS ====================

class AppBorderRadius {
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double circular = 9999;
}

/// ==================== SHADOWS ====================

class AppShadows {
  // Light mode shadows
  static List<BoxShadow> get small => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get medium => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get large => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> get glowPrimary => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.4),
      blurRadius: 16,
      spreadRadius: 2,
    ),
  ];
  
  static List<BoxShadow> get glowSuccess => [
    BoxShadow(
      color: AppColors.success.withValues(alpha: 0.4),
      blurRadius: 16,
      spreadRadius: 2,
    ),
  ];
  
  static List<BoxShadow> get glowPurple => [
    BoxShadow(
      color: AppColors.accentPurple.withValues(alpha: 0.4),
      blurRadius: 16,
      spreadRadius: 2,
    ),
  ];
  
  // Dark mode specific glows (more subtle)
  static List<BoxShadow> get glowPrimaryDark => [
    BoxShadow(
      color: AppColors.primaryLight.withValues(alpha: 0.25),
      blurRadius: 16,
      spreadRadius: 2,
    ),
  ];
  
  // Card elevation shadows for light mode
  static List<BoxShadow> get cardLight => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  // Subtle shadow for dark mode (border effect)
  static List<BoxShadow> get cardDark => [
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.03),
      blurRadius: 8,
      offset: const Offset(0, -2),
    ),
  ];
}

/// ==================== DURATIONS ====================

class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration slower = Duration(milliseconds: 600);
}

/// ==================== CURVES ====================

class AppCurves {
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve bounce = Curves.easeOutBack;
  static const Curve sharp = Curves.easeOutCubic;
}
