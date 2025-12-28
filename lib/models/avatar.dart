// models/avatar.dart

/// ------------------------------------------------------
/// Avatar Model
/// Stores information about a user's avatar
/// ------------------------------------------------------
class Avatar {
  final String id;          // Unique ID for the avatar
  final String assetPath;   // Path to avatar image in assets

  /// -------------------------------
  /// Constructor
  /// -------------------------------
  Avatar({required this.id, required this.assetPath});

  /// -------------------------------
  /// Convert Avatar object → Map
  /// Useful for saving in SharedPreferences if needed
  /// -------------------------------
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assetPath': assetPath,
    };
  }

  /// -------------------------------
  /// Create Avatar object ← Map
  /// Useful for loading from SharedPreferences
  /// -------------------------------
  factory Avatar.fromJson(Map<String, dynamic> map) {
    return Avatar(
      id: map['id'],
      assetPath: map['assetPath'],
    );
  }
}
