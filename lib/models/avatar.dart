// models/avatar.dart
import 'dart:io';

/// ------------------------------------------------------
/// Avatar Model
/// Stores information about a user's avatar
/// Supports both asset-based and custom photo avatars
/// ------------------------------------------------------
class Avatar {
  final String id;          // Unique ID for the avatar
  final String? assetPath;  // Path to avatar image in assets (null if custom)
  final String? filePath;   // Path to custom avatar file (null if asset)
  final bool isCustom;      // Whether this is a custom user photo

  /// -------------------------------
  /// Constructor
  /// -------------------------------
  Avatar({
    required this.id,
    this.assetPath,
    this.filePath,
    this.isCustom = false,
  }) : assert(assetPath != null || filePath != null, 
             'Either assetPath or filePath must be provided');

  /// -------------------------------
  /// Get display path (for UI)
  /// -------------------------------
  String get displayPath => isCustom ? filePath! : assetPath!;

  /// -------------------------------
  /// Check if avatar file exists (for custom avatars)
  /// -------------------------------
  Future<bool> fileExists() async {
    if (!isCustom || filePath == null) return true;
    final file = File(filePath!);
    return await file.exists();
  }

  /// -------------------------------
  /// Factory for asset avatars
  /// -------------------------------
  factory Avatar.asset({required String id, required String assetPath}) {
    return Avatar(id: id, assetPath: assetPath, isCustom: false);
  }

  /// -------------------------------
  /// Factory for custom photo avatars
  /// -------------------------------
  factory Avatar.custom({required String id, required String filePath}) {
    return Avatar(id: id, filePath: filePath, isCustom: true);
  }

  /// -------------------------------
  /// Convert Avatar object → Map
  /// Useful for saving in SharedPreferences/Hive if needed
  /// -------------------------------
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assetPath': assetPath,
      'filePath': filePath,
      'isCustom': isCustom,
    };
  }

  /// -------------------------------
  /// Create Avatar object ← Map
  /// Useful for loading from SharedPreferences/Hive
  /// -------------------------------
  factory Avatar.fromJson(Map<String, dynamic> map) {
    final isCustom = map['isCustom'] as bool? ?? false;
    return Avatar(
      id: map['id'] as String,
      assetPath: map['assetPath'] as String?,
      filePath: map['filePath'] as String?,
      isCustom: isCustom,
    );
  }

  /// -------------------------------
  /// Create Avatar from stored path string
  /// Handles backward compatibility with old format
  /// -------------------------------
  factory Avatar.fromPath(String path) {
    final isCustomPath = !path.startsWith('assets/') && 
                         (path.startsWith('/') || path.contains('avatars'));
    
    if (isCustomPath) {
      // Extract ID from filename or generate one
      final fileName = path.split('/').last;
      final id = 'custom_$fileName';
      return Avatar.custom(id: id, filePath: path);
    } else {
      // Asset path
      final id = path.split('/').last.replaceAll('.png', '');
      return Avatar.asset(id: id, assetPath: path);
    }
  }

  @override
  String toString() {
    return 'Avatar(id: $id, isCustom: $isCustom, path: $displayPath)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Avatar && other.id == id && other.displayPath == displayPath;
  }

  @override
  int get hashCode => Object.hash(id, displayPath);
}
