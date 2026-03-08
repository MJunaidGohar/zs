import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../models/note.dart';
import '../services/notes_service.dart';
import '../utils/app_theme.dart';

/// NoteEditorScreen - Rich text editor for creating/editing notes
/// Uses standard Scaffold with AppBar for consistent navigation
class NoteEditorScreen extends StatefulWidget {
  final Note? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final NotesService _notesService = NotesService();
  late final QuillController _quillController;
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();

  bool _isLoading = false;
  bool _hasChanges = false;
  Note? _existingNote;

  @override
  void initState() {
    super.initState();
    _initializeEditor();
  }

  void _initializeEditor() {
    if (widget.note != null) {
      _existingNote = widget.note;
      _titleController.text = widget.note!.title;

      try {
        final delta = Delta.fromJson(jsonDecode(widget.note!.content));
        _quillController = QuillController(
          document: Document.fromDelta(delta),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        _quillController = QuillController(
          document: Document()..insert(0, widget.note!.content),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } else {
      _quillController = QuillController(
        document: Document(),
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    _quillController.addListener(_onContentChanged);
    _titleController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    if (!_hasChanges && mounted) {
      setState(() => _hasChanges = true);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.unsavedChangesTitle),
        content: Text(l10n.unsavedChangesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.discard),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context, false);
              await _saveNote();
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _saveNote() async {
    final l10n = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      final enteredTitle = await _showTitleDialog();
      if (enteredTitle == null || enteredTitle.isEmpty) return;
      _titleController.text = enteredTitle;
    }

    setState(() => _isLoading = true);

    try {
      final content = jsonEncode(_quillController.document.toDelta().toJson());
      final finalTitle = _titleController.text.trim();

      if (_existingNote != null) {
        await _notesService.updateNote(
          _existingNote!.id,
          title: finalTitle,
          content: content,
        );
      } else {
        final newNote = await _notesService.createNote(
          title: finalTitle,
          content: content,
        );
        _existingNote = newNote;
      }

      setState(() => _hasChanges = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noteSavedSuccessfully)),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _showTitleDialog() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.noteTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.enterNoteTitleHint,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isNotEmpty) Navigator.pop(context, title);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _quillController.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  /// Safely launch URL in browser with error handling
  Future<void> _launchUrlSafely(String url) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      // Ensure URL has a scheme
      String finalUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        finalUrl = 'https://$url';
      }

      final uri = Uri.parse(finalUrl);

      // Check if URL can be launched
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.cannotOpenLink}: $url'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.cannotOpenLink}: $url'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvoked: (didPop) async {
        if (!didPop && _hasChanges) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () async {
              if (await _onWillPop() && mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(_existingNote != null ? l10n.editNote : l10n.newNote),
          actions: [
            IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveNote,
              tooltip: l10n.save,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // Title
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
              ),
              child: TextField(
                controller: _titleController,
                focusNode: _titleFocusNode,
                decoration: InputDecoration(
                  hintText: l10n.noteTitle,
                  hintStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),

            // Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
              ),
              child: QuillSimpleToolbar(
                controller: _quillController,
                config: const QuillSimpleToolbarConfig(
                  toolbarIconAlignment: WrapAlignment.start,
                  showAlignmentButtons: true,
                  showBackgroundColorButton: false,
                  showListNumbers: true,
                  showListBullets: true,
                  showBoldButton: true,
                  showItalicButton: true,
                  showUnderLineButton: true,
                  showStrikeThrough: true,
                  showHeaderStyle: true,
                  showColorButton: true,
                  showClearFormat: true,
                  showDividers: false,
                  showFontFamily: false,
                  showFontSize: false,
                  showIndent: true,
                  showLink: true,
                  showUndo: true,
                  showRedo: true,
                  multiRowsDisplay: false,
                ),
              ),
            ),

            // Editor - Using Expanded with proper constraints
            Expanded(
              child: Container(
                color: isDark ? Colors.grey[900] : Colors.white,
                child: QuillEditor(
                  controller: _quillController,
                  scrollController: _editorScrollController,
                  focusNode: _editorFocusNode,
                  config: QuillEditorConfig(
                    placeholder: l10n.startWritingNote,
                    padding: const EdgeInsets.all(16),
                    scrollable: true,
                    autoFocus: false,
                    expands: false,
                    onLaunchUrl: _launchUrlSafely,
                  ),
                ),
              ),
            ),

            // Bottom bar with character count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${_quillController.document.toPlainText().length} ${l10n.chars}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
