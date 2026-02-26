import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'button_position.g.dart';

/// Button Position Model
/// Stores the floating chat button position for persistence across app restarts
@HiveType(typeId: 20)
class ButtonPosition extends HiveObject {
  @HiveField(0)
  double x;

  @HiveField(1)
  double y;

  @HiveField(2)
  DateTime lastUpdated;

  ButtonPosition({
    required this.x,
    required this.y,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// Create from Offset
  factory ButtonPosition.fromOffset(Offset offset) {
    return ButtonPosition(
      x: offset.dx,
      y: offset.dy,
    );
  }

  /// Convert to Offset
  Offset toOffset() => Offset(x, y);

  /// Default position (bottom-right corner with padding)
  factory ButtonPosition.defaultPosition(double screenWidth, double screenHeight) {
    const double buttonSize = 60;
    const double padding = 16;
    return ButtonPosition(
      x: screenWidth - buttonSize - padding,
      y: screenHeight - buttonSize - padding - 80, // Above bottom nav
    );
  }

  /// Copy with modified fields
  ButtonPosition copyWith({
    double? x,
    double? y,
    DateTime? lastUpdated,
  }) {
    return ButtonPosition(
      x: x ?? this.x,
      y: y ?? this.y,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'ButtonPosition{x: $x, y: $y}';
  }
}
