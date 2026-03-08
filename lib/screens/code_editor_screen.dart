import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/app_theme.dart';

/// CodeEditorScreen - A lightweight IDE for web development
/// Features: File explorer, syntax-highlighted editor, web preview
/// Always uses LTR layout regardless of app language
class CodeEditorScreen extends StatefulWidget {
  const CodeEditorScreen({super.key});

  @override
  State<CodeEditorScreen> createState() => _CodeEditorScreenState();
}

class _CodeEditorScreenState extends State<CodeEditorScreen> {
  // File management
  Directory? _projectDir;
  List<FileSystemEntity> _files = [];
  File? _currentFile;

  // Editor controllers
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  final ScrollController _codeScrollController = ScrollController();

  // State
  bool _isLoading = true;
  bool _hasChanges = false;
  String _currentLanguage = 'html';
  bool _showPreview = false;
  String _previewContent = '';
  bool _isSidebarVisible = true;
  WebViewController? _webViewController;

  // Supported file types with their extensions and colors
  final Map<String, _LanguageConfig> _languages = {
    'html': _LanguageConfig('HTML', 'html', Colors.orange, Icons.html),
    'css': _LanguageConfig('CSS', 'css', Colors.blue, Icons.style),
    'js': _LanguageConfig('JavaScript', 'js', Colors.yellow, Icons.javascript),
  };

  @override
  void initState() {
    super.initState();
    _initializeProject();
    _codeController.addListener(_onCodeChanged);
  }

  Future<void> _initializeProject() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _projectDir = Directory('${appDir.path}/web_projects');

      if (!await _projectDir!.exists()) {
        await _projectDir!.create(recursive: true);
      }

      await _refreshFiles();

      // Create default index.html if no files exist
      if (_files.isEmpty) {
        await _createDefaultProject();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error initializing project: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createDefaultProject() async {
    final indexFile = File('${_projectDir!.path}/index.html');
    await indexFile.writeAsString('''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My First Web Page</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <h1>Hello World!</h1>
        <p>Welcome to web development.</p>
        <button onclick="showMessage()">Click Me</button>
        <p id="message"></p>
    </div>
    <script src="script.js"></script>
</body>
</html>''');

    final cssFile = File('${_projectDir!.path}/style.css');
    await cssFile.writeAsString('''* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: Arial, sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
    display: flex;
    justify-content: center;
    align-items: center;
}

.container {
    background: white;
    padding: 40px;
    border-radius: 20px;
    box-shadow: 0 20px 60px rgba(0,0,0,0.3);
    text-align: center;
}

h1 {
    color: #333;
    margin-bottom: 20px;
}

p {
    color: #666;
    margin-bottom: 20px;
}

button {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    border: none;
    padding: 12px 30px;
    border-radius: 25px;
    cursor: pointer;
    font-size: 16px;
    transition: transform 0.3s;
}

button:hover {
    transform: scale(1.05);
}

#message {
    margin-top: 20px;
    color: #667eea;
    font-weight: bold;
}''');

    final jsFile = File('${_projectDir!.path}/script.js');
    await jsFile.writeAsString('''function showMessage() {
    document.getElementById('message').textContent = 'You clicked the button!';
    console.log('Button clicked!');
}''');

    await _refreshFiles();
    await _openFile(indexFile);
  }

  Future<void> _refreshFiles() async {
    if (_projectDir == null) return;
    final List<FileSystemEntity> files = _projectDir!.listSync();
    setState(() {
      _files = files.where((f) => f is File).toList();
    });
  }

  Future<void> _openFile(File file) async {
    if (_hasChanges && _currentFile != null) {
      final shouldSave = await _showSaveDialog();
      if (shouldSave == true) {
        await _saveFile();
      } else if (shouldSave == null) {
        return;
      }
    }

    try {
      final content = await file.readAsString();
      final ext = file.path.split('.').last.toLowerCase();

      setState(() {
        _currentFile = file;
        _currentLanguage = _languages.containsKey(ext) ? ext : 'txt';
        _codeController.text = content;
        _hasChanges = false;
      });
    } catch (e) {
      debugPrint('Error reading file: $e');
    }
  }

  Future<void> _saveFile() async {
    if (_currentFile == null) return;

    try {
      await _currentFile!.writeAsString(_codeController.text);
      setState(() => _hasChanges = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('File saved successfully'),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool?> _showSaveDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('Do you want to save the changes to this file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewFile() async {
    final nameController = TextEditingController();
    String selectedExt = 'html';

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Enter file name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setState) => DropdownButton<String>(
                value: selectedExt,
                isExpanded: true,
                items: _languages.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Row(
                      children: [
                        Icon(entry.value.icon, color: entry.value.color, size: 20),
                        const SizedBox(width: 8),
                        Text(entry.value.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedExt = value);
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context, '${nameController.text}.$selectedExt');
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null) {
      final newFile = File('${_projectDir!.path}/$result');
      await newFile.writeAsString('');
      await _refreshFiles();
      await _openFile(newFile);
    }
  }

  Future<void> _deleteFile(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${file.path.split('/').last}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await file.delete();
        await _refreshFiles();
        if (_currentFile?.path == file.path) {
          setState(() {
            _currentFile = null;
            _codeController.clear();
          });
        }
      } catch (e) {
        debugPrint('Error deleting file: $e');
      }
    }
  }

  void _toggleSidebar() {
    setState(() => _isSidebarVisible = !_isSidebarVisible);
  }

  void _onCodeChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  void _onPreviewPressed() {
    if (_currentLanguage == 'html') {
      setState(() {
        _previewContent = _codeController.text;
        _showPreview = true;
        _initWebView();
      });
    } else {
      // For CSS/JS, preview the index.html with this content
      _previewProject();
    }
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // Block external navigation - only allow file:// and about:blank
            if (!request.url.startsWith('file://') &&
                !request.url.startsWith('about:blank') &&
                !request.url.startsWith('data:text/html')) {
              debugPrint('Blocked navigation to: ${request.url}');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(_previewContent);
  }

  Future<void> _previewProject() async {
    final indexFile = File('${_projectDir!.path}/index.html');
    if (await indexFile.exists()) {
      final content = await indexFile.readAsString();
      setState(() {
        _previewContent = content;
        _showPreview = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create an index.html file to preview'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _closePreview() {
    setState(() {
      _showPreview = false;
      _webViewController = null;
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    _codeScrollController.dispose();
    _webViewController = null;
    super.dispose();
  }

  // Syntax highlighting colors
  Color _getSyntaxColor(String text, int index) {
    // Simple syntax highlighting based on patterns
    if (text.startsWith('//', index) || text.startsWith('/*', index)) {
      return Colors.green;
    }
    if (text.startsWith('<', index) && _currentLanguage == 'html') {
      return Colors.orange;
    }
    // Keywords
    final keywords = ['function', 'var', 'let', 'const', 'if', 'else', 'for', 'while', 'return', 'class', 'import', 'from'];
    for (final keyword in keywords) {
      if (text.startsWith(keyword, index)) {
        return Colors.purple;
      }
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    // Force LTR for IDE regardless of app language
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _isLoading ? _buildLoadingView() : _buildEditorView(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        onPressed: () async {
          if (_hasChanges) {
            final shouldSave = await _showSaveDialog();
            if (shouldSave == true) {
              await _saveFile();
            } else if (shouldSave == null) {
              return;
            }
          }
          if (mounted) Navigator.pop(context);
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Development',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_currentFile != null)
            Text(
              _currentFile!.path.split('/').last + (_hasChanges ? ' •' : ''),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
      actions: [
        // Sidebar toggle button
        IconButton(
          icon: Icon(_isSidebarVisible ? Icons.menu_open : Icons.menu),
          onPressed: _toggleSidebar,
          tooltip: _isSidebarVisible ? 'Hide Sidebar' : 'Show Sidebar',
        ),
        // Save button
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
              : Icon(Icons.save, color: _hasChanges ? Colors.yellow : Colors.white),
          onPressed: _currentFile != null ? _saveFile : null,
          tooltip: 'Save',
        ),
        // Preview button
        IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: _onPreviewPressed,
          tooltip: 'Preview',
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.gradientHeader,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading Development Environment...'),
        ],
      ),
    );
  }

  Widget _buildEditorView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Main content
        Row(
          children: [
        // File explorer sidebar - conditionally visible
        if (_isSidebarVisible) _buildFileExplorer(isDark),
            // Editor area
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                child: _currentFile == null
                    ? _buildEmptyEditor(isDark)
                    : _buildCodeEditor(isDark),
              ),
            ),
          ],
        ),
        // Preview overlay
        if (_showPreview)
          _buildPreviewOverlay(),
      ],
    );
  }

  Widget _buildFileExplorer(bool isDark) {
    return Container(
      width: 200,
      color: isDark ? const Color(0xFF252526) : const Color(0xFFE8E8E8),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2D30) : const Color(0xFFD0D0D0),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[400]!,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FILES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    letterSpacing: 1,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: _createNewFile,
                      tooltip: 'New File',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: _refreshFiles,
                      tooltip: 'Refresh',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // File list
          Expanded(
            child: ListView.builder(
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final file = _files[index] as File;
                final fileName = file.path.split('/').last;
                final ext = fileName.split('.').last.toLowerCase();
                final isSelected = _currentFile?.path == file.path;
                final lang = _languages[ext];

                return GestureDetector(
                  onTap: () => _openFile(file),
                  onLongPress: () => _deleteFile(file),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? const Color(0xFF37373D) : const Color(0xFFE0E0E0))
                          : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: isSelected ? AppColors.accentGreen : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          lang?.icon ?? Icons.insert_drive_file,
                          size: 18,
                          color: lang?.color ?? Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileName,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected
                                  ? (isDark ? Colors.white : Colors.black)
                                  : (isDark ? Colors.grey[400] : Colors.grey[700]),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyEditor(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.code,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Select a file to edit',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'or create a new file',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[600] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeEditor(bool isDark) {
    return Stack(
      children: [
        // Background logo watermark
        Center(
          child: Opacity(
            opacity: 0.08,
            child: Image.asset(
              'assets/certificate/logo.png',
              width: 300,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Error loading watermark: $error');
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        // Code editor
        Container(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Column(
            children: [
              // Language indicator bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                color: isDark ? const Color(0xFF2D2D30) : const Color(0xFFF0F0F0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _languages[_currentLanguage]?.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _languages[_currentLanguage]?.icon ?? Icons.code,
                            size: 14,
                            color: _languages[_currentLanguage]?.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _languages[_currentLanguage]?.name ?? _currentLanguage.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              color: _languages[_currentLanguage]?.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_codeController.text.length} chars',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Editor
              Expanded(
                child: TextField(
                  controller: _codeController,
                  focusNode: _codeFocusNode,
                  scrollController: _codeScrollController,
                  maxLines: null,
                  expands: true,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    hintText: '// Start coding here...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[700] : Colors.grey[400],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            child: Column(
              children: [
                // Preview header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppColors.primary,
                  child: Row(
                    children: [
                      const Icon(Icons.preview, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Preview',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.open_in_browser, color: Colors.white, size: 20),
                        onPressed: _openInExternalBrowser,
                        tooltip: 'Open in Browser',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _closePreview,
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                // WebView for rendered preview
                Expanded(
                  child: _webViewController != null
                      ? WebViewWidget(controller: _webViewController!)
                      : const Center(
                          child: CircularProgressIndicator(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openInExternalBrowser() async {
    try {
      // Create a temporary HTML file for external preview
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/preview.html');
      await tempFile.writeAsString(_previewContent);

      // Use open_file_plus to open the HTML file in browser
      // This handles FileProvider automatically on Android
      final result = await OpenFile.open(
        tempFile.path,
        type: 'text/html',
      );

      if (result.type != ResultType.done && result.type != ResultType.fileNotFound) {
        debugPrint('Error opening file: ${result.message}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open browser: ${result.message}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening external browser: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Language configuration for syntax highlighting and icons
class _LanguageConfig {
  final String name;
  final String extension;
  final Color color;
  final IconData icon;

  const _LanguageConfig(this.name, this.extension, this.color, this.icon);
}
