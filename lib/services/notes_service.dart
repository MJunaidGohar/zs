import 'dart:convert';
import 'dart:developer';
import 'package:hive/hive.dart';
import '../models/note.dart';
import 'hive_service.dart';

/// NotesService - Handles all CRUD operations for Notes
/// Uses Hive for offline storage
class NotesService {
  static final NotesService _instance = NotesService._internal();
  factory NotesService() => _instance;
  NotesService._internal();

  static Box<Note>? _notesBox;

  /// Initialize the notes box
  static Future<void> init() async {
    if (_notesBox != null && _notesBox!.isOpen) return;

    // Register adapter if not already registered
    if (!Hive.isAdapterRegistered(NoteAdapter().typeId)) {
      Hive.registerAdapter(NoteAdapter());
    }

    _notesBox = Hive.isBoxOpen('notes')
        ? Hive.box<Note>('notes')
        : await Hive.openBox<Note>('notes');

    // Create default welcome note if no notes exist
    await _createDefaultWelcomeNoteIfNeeded();

    log('✅ NotesService initialized');
  }

  /// Create default welcome note if no notes exist
  static Future<void> _createDefaultWelcomeNoteIfNeeded() async {
    if (_notesBox == null || !_notesBox!.isOpen) return;
    
    // Check if notes box is empty
    if (_notesBox!.isEmpty) {
      final welcomeNote = _createWelcomeNote();
      await _notesBox!.put(welcomeNote.id, welcomeNote);
      log('✅ Default welcome note created');
    }
  }

  /// Create the welcome note with app description and editor showcase
  static Note _createWelcomeNote() {
    final now = DateTime.now();
    final id = now.millisecondsSinceEpoch.toString();
    
    // Rich text content with formatting showcasing editor features
    final deltaJson = [
      {'insert': '👋 Welcome to Zarori Sawal!\n'},
      {'insert': '\n'},
      {
        'attributes': {'bold': true, 'size': 'large'},
        'insert': '📱 About This App'
      },
      {'insert': '\n'},
      {
        'insert': 'Zarori Sawal is your all-in-one learning companion! Master skills in:'
      },
      {'insert': '\n'},
      {
        'attributes': {'list': 'bullet'},
        'insert': 'English Language'
      },
      {
        'attributes': {'list': 'bullet'},
        'insert': 'Computer Skills'
      },
      {
        'attributes': {'list': 'bullet'},
        'insert': 'Digital Marketing'
      },
      {
        'attributes': {'list': 'bullet'},
        'insert': 'Web Development'
      },
      {
        'attributes': {'list': 'bullet'},
        'insert': 'YouTube & Content Creation'
      },
      {'insert': '\n'},
      {
        'attributes': {'bold': true, 'size': 'large'},
        'insert': '🎯 Key Features'
      },
      {'insert': '\n'},
      {
        'attributes': {'bold': true},
        'insert': 'Learning Mode:'
      },
      {'insert': ' Study with structured Topic → Level → Subtopic progression\n'},
      {
        'attributes': {'bold': true},
        'insert': 'Test Mode:'
      },
      {'insert': ' Challenge yourself with MCQs and track progress\n'},
      {
        'attributes': {'bold': true},
        'insert': 'Offline Access:'
      },
      {'insert': ' Learn anytime, anywhere without internet\n'},
      {
        'attributes': {'bold': true},
        'insert': 'AI Chat Assistant:'
      },
      {'insert': ' Get instant help with your questions\n'},
      {
        'attributes': {'bold': true},
        'insert': 'Match-3 Game:'
      },
      {'insert': ' Relax and have fun while learning\n'},
      {'insert': '\n'},
      {
        'attributes': {'bold': true, 'size': 'large'},
        'insert': '📝 How to Use This Notes Editor'
      },
      {'insert': '\n'},
      {
        'insert': 'This note demonstrates the rich text editor features:'
      },
      {'insert': '\n'},
      {
        'attributes': {'bold': true},
        'insert': 'Bold text'
      },
      {'insert': ' for emphasis | '},
      {
        'attributes': {'italic': true},
        'insert': 'Italic for style'
      },
      {'insert': ' | '},
      {
        'attributes': {'underline': true},
        'insert': 'Underlined'
      },
      {'insert': '\n'},
      {
        'attributes': {'strike': true},
        'insert': 'Strikethrough for completed items'
      },
      {'insert': '\n'},
      {'insert': '\n'},
      {
        'attributes': {'color': '#FF6B6B'},
        'insert': 'Colored text'
      },
      {'insert': ' to highlight important points\n'},
      {'insert': '\n'},
      {
        'attributes': {'header': 1},
        'insert': 'Heading 1'
      },
      {'insert': '\n'},
      {
        'attributes': {'header': 2},
        'insert': 'Heading 2'
      },
      {'insert': '\n'},
      {
        'attributes': {'list': 'ordered'},
        'insert': 'Numbered lists for steps'
      },
      {
        'attributes': {'list': 'ordered'},
        'insert': 'Easy to follow instructions'
      },
      {
        'attributes': {'list': 'ordered'},
        'insert': 'Organized information'
      },
      {'insert': '\n'},
      {
        'attributes': {'list': 'bullet'},
        'insert': 'Bullet points for quick notes'
      },
      {
        'attributes': {'list': 'bullet'},
        'insert': 'Brainstorming ideas'
      },
      {
        'attributes': {'list': 'bullet'},
        'insert': 'Key takeaways'
      },
      {'insert': '\n'},
      {
        'attributes': {'link': 'https://flutter.dev'},
        'insert': '🔗 Clickable links'
      },
      {'insert': ' to external resources\n'},
      {'insert': '\n'},
      {
        'attributes': {'bold': true, 'size': 'large'},
        'insert': '📚 Learning Content'
      },
      {'insert': '\n'},
      {
        'insert': 'New topics and skills are regularly added to the Google Sheets content database. Stay tuned for:'
      },
      {'insert': '\n'},
      {
        'attributes': {'list': 'bullet'},
        'insert': 'More subjects and topics'
      },
      {
        'attributes': {'list': 'bullet'},
        'insert': 'Advanced levels for existing subjects'
      },
      {
        'attributes': {'list': 'bullet'},
        'insert': 'Interactive quizzes and assessments'
      },
      {
        'attributes': {'list': 'bullet'},
        'insert': 'Video tutorials and guides'
      },
      {'insert': '\n'},
      {
        'attributes': {'background': '#FFF3CD', 'color': '#856404'},
        'insert': '💡 Pro Tip: Pin this note to keep it at the top of your notes list!'
      },
      {'insert': '\n'},
      {'insert': '\n'},
      {
        'attributes': {'italic': true, 'color': '#6C757D'},
        'insert': 'Happy Learning! 🎓'
      },
      {'insert': '\n'}
    ];

    return Note(
      id: id,
      title: '👋 Welcome to Zarori Sawal!',
      content: jsonEncode(deltaJson),
      createdAt: now,
      updatedAt: now,
      isPinned: true,  // Pin by default so it stays at top
    );
  }

  static Box<Note> get notesBox {
    if (_notesBox == null || !_notesBox!.isOpen) {
      throw Exception('NotesService not initialized. Call init() first.');
    }
    return _notesBox!;
  }

  /// Get all notes sorted by updatedAt (newest first), pinned notes first
  List<Note> getAllNotes() {
    final notes = notesBox.values.toList();
    notes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return notes;
  }

  /// Get recent notes (limited count)
  List<Note> getRecentNotes({int limit = 10}) {
    final notes = getAllNotes();
    return notes.take(limit).toList();
  }

  /// Get a single note by id
  Note? getNote(String id) {
    return notesBox.get(id);
  }

  /// Create a new note
  Future<Note> createNote({
    required String title,
    required String content,
  }) async {
    final note = Note.create(
      title: title,
      content: content,
    );
    await notesBox.put(note.id, note);
    log('✅ Note created: ${note.id}');
    return note;
  }

  /// Update an existing note
  Future<Note> updateNote(
    String id, {
    String? title,
    String? content,
    bool? isPinned,
  }) async {
    final existingNote = notesBox.get(id);
    if (existingNote == null) {
      throw Exception('Note not found: $id');
    }

    final updatedNote = existingNote.copyWith(
      title: title,
      content: content,
      isPinned: isPinned,
      updatedAt: DateTime.now(),
    );
    await notesBox.put(id, updatedNote);
    log('✅ Note updated: $id');
    return updatedNote;
  }

  /// Rename a note (update title)
  Future<Note> renameNote(String id, String newTitle) async {
    return updateNote(id, title: newTitle);
  }

  /// Toggle pin status
  Future<Note> togglePin(String id) async {
    final existingNote = notesBox.get(id);
    if (existingNote == null) {
      throw Exception('Note not found: $id');
    }
    return updateNote(id, isPinned: !existingNote.isPinned);
  }

  /// Delete a note
  Future<void> deleteNote(String id) async {
    await notesBox.delete(id);
    log('✅ Note deleted: $id');
  }

  /// Search notes by title or content
  List<Note> searchNotes(String query) {
    final lowerQuery = query.toLowerCase();
    return notesBox.values.where((note) {
      return note.title.toLowerCase().contains(lowerQuery) ||
          note.content.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Get total notes count
  int get notesCount => notesBox.length;

  /// Clear all notes (use with caution)
  Future<void> clearAllNotes() async {
    await notesBox.clear();
    log('✅ All notes cleared');
  }
}
