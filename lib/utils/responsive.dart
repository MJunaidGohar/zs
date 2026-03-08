import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Responsive design utilities for Zarori Sawal
/// Provides safe, screen-adaptive sizing helpers
class Responsive {
  /// Initialize ScreenUtil with design size (based on standard phone)
  static Widget init({required Widget child}) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // iPhone X/XS/11 Pro design baseline
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => child!,
      child: child,
    );
  }

  /// Get responsive width (percentage of screen width)
  static double wp(double percent) => percent.sw;

  /// Get responsive height (percentage of screen height)
  static double hp(double percent) => percent.sh;

  /// Get responsive font size (scales with screen width, respects accessibility)
  static double sp(double size) => size.sp;

  /// Get responsive width in pixels
  static double w(double width) => width.w;

  /// Get responsive height in pixels
  static double h(double height) => height.h;

  /// Get responsive radius
  static double r(double radius) => radius.r;

  /// Check if screen is small (phones < 360dp width)
  static bool isSmallScreen(BuildContext context) =>
      MediaQuery.of(context).size.width < 360;

  /// Check if screen is standard (phones 360-414dp width)
  static bool isStandardScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 360 && width < 600;
  }

  /// Check if screen is tablet (devices >= 600dp width)
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600;

  /// Get adaptive value based on screen size
  static T adaptive<T>({
    required BuildContext context,
    required T small,
    required T standard,
    T? tablet,
  }) {
    if (isTablet(context) && tablet != null) return tablet;
    if (isSmallScreen(context)) return small;
    return standard;
  }

  /// Safe area padding
  static EdgeInsets safePadding(BuildContext context) =>
      MediaQuery.of(context).padding;

  /// Screen size
  static Size screenSize(BuildContext context) =>
      MediaQuery.of(context).size;
}

/// Extension for responsive values on numbers
extension ResponsiveNum on num {
  /// Responsive width
  double get w => Responsive.w(toDouble());

  /// Responsive height
  double get h => Responsive.h(toDouble());

  /// Responsive font size
  double get sp => Responsive.sp(toDouble());

  /// Responsive radius
  double get r => Responsive.r(toDouble());

  /// Percentage of screen width
  double get sw => (this * ScreenUtil().screenWidth) / 100;

  /// Percentage of screen height
  double get sh => (this * ScreenUtil().screenHeight) / 100;
}
