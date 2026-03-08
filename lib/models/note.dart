import 'package:hive/hive.dart';

part 'note.g.dart';

/// Note Model
/// Represents a user-created note with rich text content and metadata
/// Stored in Hive for offline access
@HiveType(typeId: 3)
class Note extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String content;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  @HiveField(5)
  bool isPinned;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
  });

  /// Create a new note with current timestamp
  factory Note.create({
    required String title,
    required String content,
  }) {
    final now = DateTime.now();
    return Note(
      id: now.millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
      isPinned: false,
    );
  }

  /// Copy with modified fields
  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  @override
  String toString() {
    return 'Note{id: $id, title: $title, updatedAt: $updatedAt}';
  }
}
