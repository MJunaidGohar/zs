import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import '../models/button_position.dart';

/// Floating Button Service
/// Manages the floating chat button position persistence
/// Ensures button stays where user placed it across app restarts
class FloatingButtonService {
  static const String _boxName = 'floating_button_box';
  static const String _positionKey = 'button_position';
  
  Box<ButtonPosition>? _box;
  
  // Private constructor
  FloatingButtonService._();
  
  // Singleton instance
  static final FloatingButtonService _instance = FloatingButtonService._();
  
  /// Get singleton instance
  factory FloatingButtonService() => _instance;
  
  /// Initialize the service and register Hive adapter
  Future<void> init() async {
    try {
      // Register adapter if not already registered
      if (!Hive.isAdapterRegistered(20)) {
        Hive.registerAdapter(ButtonPositionAdapter());
      }
      
      _box = await Hive.openBox<ButtonPosition>(_boxName);
    } catch (e) {
      debugPrint('FloatingButtonService init error: $e');
    }
  }
  
  /// Check if service is ready
  bool get isReady => _box != null && _box!.isOpen;
  
  /// Get saved button position or return default
  ButtonPosition getPosition(double screenWidth, double screenHeight) {
    if (!isReady) {
      return ButtonPosition.defaultPosition(screenWidth, screenHeight);
    }
    
    final savedPosition = _box!.get(_positionKey);
    if (savedPosition != null) {
      // Validate position is within screen bounds (with some tolerance)
      final validatedX = savedPosition.x.clamp(0.0, screenWidth - 60);
      final validatedY = savedPosition.y.clamp(100.0, screenHeight - 100);
      
      return savedPosition.copyWith(
        x: validatedX,
        y: validatedY,
      );
    }
    
    return ButtonPosition.defaultPosition(screenWidth, screenHeight);
  }
  
  /// Save button position
  Future<void> savePosition(Offset offset) async {
    if (!isReady) return;
    
    final position = ButtonPosition.fromOffset(offset);
    await _box!.put(_positionKey, position);
  }
  
  /// Save position with explicit coordinates
  Future<void> savePositionCoords(double x, double y) async {
    if (!isReady) return;
    
    final position = ButtonPosition(x: x, y: y);
    await _box!.put(_positionKey, position);
  }
  
  /// Reset to default position
  Future<void> resetToDefault(double screenWidth, double screenHeight) async {
    if (!isReady) return;
    
    final defaultPos = ButtonPosition.defaultPosition(screenWidth, screenHeight);
    await _box!.put(_positionKey, defaultPos);
  }
  
  /// Check if position has been customized by user
  bool get hasCustomPosition {
    if (!isReady) return false;
    return _box!.get(_positionKey) != null;
  }
  
  /// Ensure position is within safe area
  /// Returns corrected position if needed
  Offset clampPosition(Offset position, Size screenSize) {
    const double buttonSize = 60;
    const double minPadding = 8;
    
    double x = position.dx.clamp(
      minPadding,
      screenSize.width - buttonSize - minPadding,
    );
    
    double y = position.dy.clamp(
      minPadding + 80, // Below status bar
      screenSize.height - buttonSize - minPadding - 80, // Above nav bar
    );
    
    return Offset(x, y);
  }
  
  /// Check if position is near an edge (for snap behavior)
  bool isNearEdge(Offset position, Size screenSize, {double threshold = 50}) {
    return position.dx < threshold || 
           position.dx > screenSize.width - threshold - 60 ||
           position.dy < threshold + 100 ||
           position.dy > screenSize.height - threshold - 100;
  }
  
  /// Snap position to nearest edge
  Offset snapToEdge(Offset position, Size screenSize) {
    const double buttonSize = 60;
    const double padding = 16;
    
    double x = position.dx;
    double y = position.dy;
    
    // Calculate distances to each edge
    final leftDist = x;
    final rightDist = screenSize.width - x - buttonSize;
    final topDist = y - 100; // Account for status bar
    final bottomDist = screenSize.height - y - buttonSize - 80; // Account for nav
    
    // Snap horizontally
    if (leftDist < rightDist && leftDist < 100) {
      x = padding;
    } else if (rightDist < leftDist && rightDist < 100) {
      x = screenSize.width - buttonSize - padding;
    }
    
    // Snap vertically (only if near top/bottom)
    if (topDist < bottomDist && topDist < 100) {
      y = padding + 100;
    } else if (bottomDist < topDist && bottomDist < 100) {
      y = screenSize.height - buttonSize - padding - 80;
    }
    
    return Offset(x, y);
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
  }
}
