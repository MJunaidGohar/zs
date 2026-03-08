import 'package:flutter/material.dart';

/// Utility class to detect text direction based on content language
/// This allows displaying content with appropriate LTR/RTL direction
/// regardless of the app's current language setting
class TextDirectionHelper {
  /// Unicode range for Arabic script (includes Urdu, Arabic, Persian)
  /// Arabic: U+0600 - U+06FF
  /// Arabic Supplement: U+0750 - U+077F
  /// Arabic Extended-A: U+08A0 - U+08FF
  /// Arabic Presentation Forms-A: U+FB50 - U+FDFF
  /// Arabic Presentation Forms-B: U+FE70 - U+FEFF
  static final RegExp _rtlCharPattern = RegExp(
    r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  );

  /// Detects if text contains RTL characters (Arabic/Urdu script)
  static bool containsRtlText(String text) {
    if (text.isEmpty) return false;
    return _rtlCharPattern.hasMatch(text);
  }

  /// Returns the appropriate text direction based on content
  static TextDirection getTextDirection(String text) {
    return containsRtlText(text) ? TextDirection.rtl : TextDirection.ltr;
  }

  /// Wraps a widget with Directionality based on text content
  static Widget wrapWithDirectionality({
    required String text,
    required Widget child,
  }) {
    return Directionality(
      textDirection: getTextDirection(text),
      child: child,
    );
  }

  /// Creates a Text widget with auto-detected text direction
  static Widget autoDirectionText({
    required String text,
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    final isRtl = containsRtlText(text);
    return Text(
      text,
      style: style,
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      textAlign: textAlign ?? (isRtl ? TextAlign.right : TextAlign.left),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
