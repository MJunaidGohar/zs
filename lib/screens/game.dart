import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../services/admob_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:file_picker/file_picker.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

// Block piece definition with shape and color
class BlockPiece {
  final List<List<int>> shape;
  final int colorIndex;
  final String id;

  BlockPiece({
    required this.shape,
    required this.colorIndex,
    required this.id,
  });

  int get width => shape[0].length;
  int get height => shape.length;

  List<Point<int>> get occupiedCells {
    final cells = <Point<int>>[];
    for (int r = 0; r < shape.length; r++) {
      for (int c = 0; c < shape[r].length; c++) {
        if (shape[r][c] == 1) {
          cells.add(Point(r, c));
        }
      }
    }
    return cells;
  }

  BlockPiece rotated() {
    final newShape = List.generate(
      width,
      (r) => List.generate(height, (c) => 0),
    );
    for (int r = 0; r < height; r++) {
      for (int c = 0; c < width; c++) {
        if (shape[r][c] == 1) {
          newShape[c][height - 1 - r] = 1;
        }
      }
    }
    return BlockPiece(
      shape: newShape,
      colorIndex: colorIndex,
      id: '${id}_rotated',
    );
  }
}

class PieceShapes {
  static final List<List<List<int>>> all = [
    [[1]],
    [[1, 1]],
    [[1, 1, 1]],
    [[1, 0], [1, 1]],
    [[1, 1, 1, 1]],
    [[1, 1], [1, 1]],
    [[1, 1, 1], [0, 1, 0]],
    [[1, 0, 0], [1, 1, 1]],
    [[0, 0, 1], [1, 1, 1]],
    [[0, 1, 1], [1, 1, 0]],
    [[1, 1, 0], [0, 1, 1]],
  ];

  static BlockPiece random(Random random, int colorIndex) {
    final shape = all[random.nextInt(all.length)];
    return BlockPiece(
      shape: shape,
      colorIndex: colorIndex,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  AudioPlayer? _audioPlayer;
  bool _isMusicPlaying = false;
  bool _isMusicEnabled = true;
  String? _customAudioPath;
  static const String _customAudioPrefKey = 'custom_audio_path';

  InterstitialAd? _interstitialAd;
  bool _adShown = false;
  int _lastAdTriggerScore = 0;

  static const int gridSize = 8;
  late List<List<int?>> grid;
  final Random _random = Random();

  static const String _themePrefKey = 'game_theme';
  String _currentTheme = 'fruits';
  bool _showThemeDialog = false;

  final List<BlockPiece?> _availablePieces = [null, null, null];
  BlockPiece? _draggedPiece;
  int? _draggedPieceIndex;
  Point<int>? _previewPosition;
  bool _isValidPlacement = false;

  final List<Color> _fruitColors = [
    const Color(0xFFFF6B6B),
    const Color(0xFFFFE66D),
    const Color(0xFF9B59B6),
    const Color(0xFFFF8C42),
    const Color(0xFFFF1744),
    const Color(0xFF00BCD4),
    const Color(0xFFFFA07A),
    const Color(0xFFC0392B),
  ];

  final List<Color> _socialColors = [
    const Color(0xFFFFD700),
    const Color(0xFFE91E63),
    const Color(0xFFFF5722),
    const Color(0xFF9C27B0),
    const Color(0xFFFF4081),
    const Color(0xFF4CAF50),
    const Color(0xFF2196F3),
    const Color(0xFF607D8B),
  ];

  List<Color> get blockColors => _currentTheme == 'fruits' ? _fruitColors : _socialColors;

  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  int _combo = 0;
  int _linesCleared = 0;
  int _lastVibratedMilestone = 0;
  int _highScore = 0;
  static const String _highScorePrefKey = 'block_blast_high_score';

  bool _gameOver = false;
  bool _showGameOverDialog = false;
  bool _isProcessing = false;

  late final AnimationController _lineClearController;
  late final AnimationController _piecePlaceController;
  late final AnimationController _backgroundController;
  late final List<AnimationController> _pieceBounceControllers;

  final Set<int> _clearingRows = {};
  final Set<int> _clearingCols = {};

  final List<_Particle> _particles = [];
  late final AnimationController _particleController;

  bool _showTutorial = false;
  int _tutorialStep = 0;
  late final AnimationController _tutorialController;
  late final AnimationController _handSwipeController;

  final VolumeController _volumeController = VolumeController();
  double _currentVolume = 0.5;
  StreamSubscription<double>? _volumeListener;

  @override
  void initState() {
    super.initState();

    _lineClearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _piecePlaceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _tutorialController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _handSwipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pieceBounceControllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );

    _initGame();
    _loadThemeAndInit();
    _loadHighScore();
    _loadCustomAudioPath();
    _initAudioPlayer();
    _initVolumeController();
  }

  bool get _isWeb => kIsWeb;

  Future<void> _loadCustomAudioPath() async {
    if (_isWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString(_customAudioPrefKey);

      if (savedPath != null && File(savedPath).existsSync()) {
        setState(() {
          _customAudioPath = savedPath;
        });
      }
    } catch (e) {
      debugPrint('Load custom audio path error: $e');
    }
  }

  Future<void> _pickCustomMedia() async {
    if (_isWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom audio not available in web mode')),
        );
      }
      return;
    }
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final selectedPath = result.files.single.path!;

        if (!File(selectedPath).existsSync()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Selected file not found')),
            );
          }
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_customAudioPrefKey, selectedPath);

        setState(() {
          _customAudioPath = selectedPath;
        });

        await _stopBackgroundMusic();
        await _playBackgroundMusic();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Audio selected: ${_getFileName(selectedPath)}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Pick custom media error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting media: $e')),
        );
      }
    }
  }

  Future<void> _clearCustomAudio() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_customAudioPrefKey);

      setState(() {
        _customAudioPath = null;
      });

      await _stopBackgroundMusic();
      await _playBackgroundMusic();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom audio cleared')),
        );
      }
    } catch (e) {
      debugPrint('Clear custom audio error: $e');
    }
  }

  String _getFileName(String path) {
    if (_isWeb) return path;
    return path.split(Platform.pathSeparator).last;
  }

  void _showAudioOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A237E),
        title: const Text(
          'Background Music',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_customAudioPath != null) ...[
              Row(
                children: [
                  const Icon(
                    Icons.music_note,
                    color: Colors.tealAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current: ${_getFileName(_customAudioPath!)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            ListTile(
              leading: const Icon(Icons.folder_open, color: Colors.tealAccent),
              title: const Text('Select Audio', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Choose audio file (MP3, WAV, etc.)',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickCustomMedia();
              },
            ),
            if (_customAudioPath != null)
              ListTile(
                leading: const Icon(Icons.clear, color: Colors.redAccent),
                title: const Text('Clear custom audio', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Use default music', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _clearCustomAudio();
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.tealAccent)),
          ),
        ],
      ),
    );
  }

  void _initVolumeController() {
    _volumeController.getVolume().then((volume) {
      setState(() {
        _currentVolume = volume;
      });
    });

    _volumeListener = _volumeController.listener((volume) {
      setState(() {
        _currentVolume = volume;
      });

      if (_audioPlayer != null && _isMusicEnabled) {
        _audioPlayer!.setVolume(volume);
      }
    });
  }

  Future<void> _initAudioPlayer() async {
    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _playBackgroundMusic();
    } catch (e) {
      debugPrint('Audio player initialization error: $e');
    }
  }

  Future<void> _playBackgroundMusic() async {
    if (_audioPlayer == null || !_isMusicEnabled) return;

    try {
      await _audioPlayer!.stop();

      if (!_isWeb && _customAudioPath != null && File(_customAudioPath!).existsSync()) {
        await _audioPlayer!.play(DeviceFileSource(_customAudioPath!));
        _isMusicPlaying = true;
      } else {
        _isMusicPlaying = true;
      }
    } catch (e) {
      debugPrint('Background music playback error: $e');
    }
  }

  Future<void> _toggleMusic() async {
    setState(() {
      _isMusicEnabled = !_isMusicEnabled;
    });

    if (_isMusicEnabled) {
      await _resumeBackgroundMusic();
    } else {
      await _pauseBackgroundMusic();
    }
  }

  Future<void> _pauseBackgroundMusic() async {
    if (_audioPlayer == null || !_isMusicPlaying) return;

    try {
      await _audioPlayer!.pause();
      _isMusicPlaying = false;
    } catch (e) {
      debugPrint('Pause music error: $e');
    }
  }

  Future<void> _resumeBackgroundMusic() async {
    if (_audioPlayer == null) return;

    try {
      await _audioPlayer!.resume();
      _isMusicPlaying = true;
    } catch (e) {
      debugPrint('Resume music error: $e');
    }
  }

  Future<void> _stopBackgroundMusic() async {
    if (_audioPlayer == null) return;

    try {
      await _audioPlayer!.stop();
      _isMusicPlaying = false;
    } catch (e) {
      debugPrint('Stop music error: $e');
    }
  }

  Future<void> _disposeAudioPlayer() async {
    if (_audioPlayer == null) return;

    try {
      await _audioPlayer!.dispose();
      _audioPlayer = null;
      _isMusicPlaying = false;
    } catch (e) {
      debugPrint('Dispose audio player error: $e');
    }
  }

  Future<void> _loadThemeAndInit() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themePrefKey);
    setState(() {
      _currentTheme = savedTheme ?? 'fruits';
      _showThemeDialog = true;
    });
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt(_highScorePrefKey) ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    if (scoreNotifier.value > _highScore) {
      _highScore = scoreNotifier.value;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_highScorePrefKey, _highScore);
    }
  }

  Future<void> _saveTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefKey, theme);
  }

  Future<void> _checkFirstTimeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('block_blast_tutorial_seen') ?? false;
    if (!hasSeenTutorial && mounted) {
      setState(() => _showTutorial = true);
    }
  }

  void _dismissTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('block_blast_tutorial_seen', true);
    setState(() {
      _showTutorial = false;
      _tutorialStep = 0;
    });
  }

  void _nextTutorialStep() {
    setState(() {
      _tutorialStep++;
      if (_tutorialStep >= 3) {
        _dismissTutorial();
      }
    });
  }

  void _loadAd() {
    if (_adShown) return;
    AdMobService.loadInterstitialAd(
      adUnitId: 'ca-app-pub-5721278995377651/6519657994',
      onAdLoaded: (ad) {
        _interstitialAd = ad;
        try {
          ad.show();
          _adShown = true;
        } catch (e) {
          developer.log('Failed to show interstitial ad: $e');
        }
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) => ad.dispose(),
          onAdFailedToShowFullScreenContent: (ad, err) {
            developer.log('Interstitial ad failed to show: ${err.message}');
            ad.dispose();
          },
        );
      },
      onAdFailedToLoad: (err) {
        developer.log('Interstitial ad failed to load: ${err.message}');
        _interstitialAd = null;
      },
    );
  }

  void _checkAndShowAdAtScoreMilestone() {
    final currentScore = scoreNotifier.value;
    final milestone = (currentScore ~/ 500) * 500;

    if (milestone > 0 && milestone > _lastAdTriggerScore) {
      _lastAdTriggerScore = milestone;
      _loadAd();
    }
  }

  void _initGame() {
    grid = List.generate(
      gridSize,
      (_) => List.generate(gridSize, (_) => null),
    );
    scoreNotifier.value = 0;
    _combo = 0;
    _linesCleared = 0;
    _lastVibratedMilestone = 0;
    _lastAdTriggerScore = 0;
    _gameOver = false;
    _showGameOverDialog = false;
    _clearingRows.clear();
    _clearingCols.clear();
    _generateNewPieces();
    setState(() {});
  }

  void _generateNewPieces() {
    for (int i = 0; i < 3; i++) {
      if (_availablePieces[i] == null) {
        _availablePieces[i] = PieceShapes.random(_random, _random.nextInt(blockColors.length));
        _pieceBounceControllers[i].forward(from: 0);
      }
    }
    if (!_hasAnyValidMoves()) {
      _triggerGameOver();
    }
  }

  bool _hasAnyValidMoves() {
    for (final piece in _availablePieces) {
      if (piece == null) continue;
      if (_canPlaceAnywhere(piece)) return true;
      final rotated = piece.rotated();
      if (_canPlaceAnywhere(rotated)) return true;
    }
    return false;
  }

  bool _canPlaceAnywhere(BlockPiece piece) {
    for (int r = 0; r <= gridSize - piece.height; r++) {
      for (int c = 0; c <= gridSize - piece.width; c++) {
        if (_isValidPlacementCheck(piece, r, c)) return true;
      }
    }
    return false;
  }

  bool _isValidPlacementCheck(BlockPiece piece, int row, int col) {
    if (row < 0 || col < 0 || row + piece.height > gridSize || col + piece.width > gridSize) {
      return false;
    }
    for (final cell in piece.occupiedCells) {
      final gridR = row + cell.x;
      final gridC = col + cell.y;
      if (gridR < 0 || gridR >= gridSize || gridC < 0 || gridC >= gridSize) {
        return false;
      }
      if (grid[gridR][gridC] != null) {
        return false;
      }
    }
    return true;
  }

  void _onPieceDragStart(BlockPiece piece, int index) {
    setState(() {
      _draggedPiece = piece;
      _draggedPieceIndex = index;
    });
    HapticFeedback.lightImpact();
  }

  void _onGridHover(int row, int col) {
    if (_draggedPiece == null) return;
    setState(() {
      _previewPosition = Point(row, col);
      _isValidPlacement = _isValidPlacementCheck(_draggedPiece!, row, col);
    });
  }

  void _onGridDrop(int row, int col) {
    if (_draggedPiece == null || _draggedPieceIndex == null) return;
    if (_isValidPlacementCheck(_draggedPiece!, row, col)) {
      _placePiece(_draggedPiece!, _draggedPieceIndex!, row, col);
    }
    setState(() {
      _draggedPiece = null;
      _draggedPieceIndex = null;
      _previewPosition = null;
      _isValidPlacement = false;
    });
  }

  void _placePiece(BlockPiece piece, int pieceIndex, int row, int col) {
    if (_isProcessing) return;
    _isProcessing = true;
    for (final cell in piece.occupiedCells) {
      final gridR = row + cell.x;
      final gridC = col + cell.y;
      grid[gridR][gridC] = piece.colorIndex;
    }
    _availablePieces[pieceIndex] = null;
    final pieceScore = piece.occupiedCells.length * 10;
    scoreNotifier.value += pieceScore;
    HapticFeedback.mediumImpact();
    _piecePlaceController.forward(from: 0);
    _checkAndShowAdAtScoreMilestone();
    _processLineClears();
    setState(() {});
    _isProcessing = false;
  }

  void _processLineClears() {
    final rowsToClear = <int>{};
    final colsToClear = <int>{};
    for (int r = 0; r < gridSize; r++) {
      bool full = true;
      for (int c = 0; c < gridSize; c++) {
        if (grid[r][c] == null) {
          full = false;
          break;
        }
      }
      if (full) rowsToClear.add(r);
    }
    for (int c = 0; c < gridSize; c++) {
      bool full = true;
      for (int r = 0; r < gridSize; r++) {
        if (grid[r][c] == null) {
          full = false;
          break;
        }
      }
      if (full) colsToClear.add(c);
    }
    if (rowsToClear.isNotEmpty || colsToClear.isNotEmpty) {
      setState(() {
        _clearingRows.addAll(rowsToClear);
        _clearingCols.addAll(colsToClear);
      });
      final linesCount = rowsToClear.length + colsToClear.length;
      _combo++;
      final bonusScore = linesCount * 100 * _combo;
      scoreNotifier.value += bonusScore;
      _linesCleared += linesCount;
      _checkAndTriggerVibration();
      _showLineClearEffect(rowsToClear, colsToClear);
      _lineClearController.forward(from: 0).then((_) {
        setState(() {
          for (final r in rowsToClear) {
            for (int c = 0; c < gridSize; c++) {
              grid[r][c] = null;
            }
          }
          for (final c in colsToClear) {
            for (int r = 0; r < gridSize; r++) {
              grid[r][c] = null;
            }
          }
          _clearingRows.clear();
          _clearingCols.clear();
        });
        _generateNewPieces();
      });
    } else {
      _generateNewPieces();
    }
  }

  void _checkAndTriggerVibration() {
    final currentScore = scoreNotifier.value;
    final currentMilestone = (currentScore ~/ 1000) * 1000;
    if (currentMilestone > 0 && currentMilestone > _lastVibratedMilestone) {
      _lastVibratedMilestone = currentMilestone;
      _triggerVibration();
    }
  }

  Future<void> _triggerVibration() async {
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 300);
      }
    } catch (e) {}
  }

  void _showLineClearEffect(Set<int> rows, Set<int> cols) {
    for (final r in rows) {
      for (int c = 0; c < gridSize; c++) {
        _addParticlesAtCell(r, c);
      }
    }
    for (final c in cols) {
      for (int r = 0; r < gridSize; r++) {
        _addParticlesAtCell(r, c);
      }
    }
    _particleController.forward(from: 0).then((_) {
      setState(() {
        _particles.clear();
      });
    });
  }

  void _addParticlesAtCell(int row, int col) {
    for (int i = 0; i < 8; i++) {
      _particles.add(_Particle(
        x: col.toDouble(),
        y: row.toDouble(),
        vx: (_random.nextDouble() - 0.5) * 8,
        vy: (_random.nextDouble() - 0.5) * 8,
        color: blockColors[_random.nextInt(blockColors.length)],
        size: 4 + _random.nextDouble() * 6,
      ));
    }
  }

  void _triggerGameOver() {
    _gameOver = true;
    _saveHighScore();
    setState(() {
      _showGameOverDialog = true;
    });
  }

  void _restartGame() {
    _saveHighScore();
    _initGame();
    setState(() {
      _showGameOverDialog = false;
    });
  }

  void _rotatePiece(int index) {
    if (_availablePieces[index] == null) return;
    setState(() {
      _availablePieces[index] = _availablePieces[index]!.rotated();
    });
    HapticFeedback.lightImpact();
    _pieceBounceControllers[index].forward(from: 0.3);
  }

  Future<void> _changeTheme(String theme) async {
    setState(() {
      _currentTheme = theme;
      _showThemeDialog = false;
    });
    await _saveTheme(theme);
    _initGame();
    _checkFirstTimeTutorial();
  }

  Widget _buildFruitIcon(int index, double size) {
    final fruits = ["🍎", "🍌", "🍇", "🍊", "🍓", "🍉", "🍑", "🍒"];
    return Text(fruits[index % fruits.length], style: TextStyle(fontSize: size));
  }

  Widget _buildEmojiIcon(int index, double size) {
    final emojis = ["😂", "❤️", "🔥", "😍", "🥰", "👍", "🎉", "😎"];
    return Text(emojis[index % emojis.length], style: TextStyle(fontSize: size));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    final gridPadding = 8.0;
    final availableWidth = size.width - (gridPadding * 2);
    final cellSize = (availableWidth / gridSize).floorToDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(l10n, isSmallScreen),
            const SizedBox(height: 4),
            _buildScoreBar(l10n),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: _buildGameGrid(cellSize, gridPadding),
              ),
            ),
            _buildPiecesArea(l10n, isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations? l10n, bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildMenuButton(),
        ],
      ),
    );
  }

  Widget _buildMenuButton() {
    return PopupMenuButton<String>(
      icon: _GlassCard(
        gradient: LinearGradient(
          colors: [Colors.grey.shade600, Colors.grey.shade700],
        ),
        child: const Icon(
          Icons.more_vert,
          color: Colors.white,
          size: 20,
        ),
      ),
      onSelected: (value) {
        switch (value) {
          case 'sound':
            _toggleMusic();
            break;
          case 'music':
            _showAudioOptionsDialog();
            break;
          case 'refresh':
            _restartGame();
            break;
          case 'exit':
            Navigator.of(context).pop();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'sound',
          child: Row(
            children: [
              Icon(
                _isMusicEnabled ? Icons.volume_up : Icons.volume_off,
                color: _isMusicEnabled ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(_isMusicEnabled ? 'Mute Sound' : 'Unmute Sound'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'music',
          child: Row(
            children: [
              Icon(
                _customAudioPath != null ? Icons.music_note : Icons.music_off,
                color: _customAudioPath != null ? Colors.orange : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(_customAudioPath != null ? 'Change Music' : 'Select Music'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh, color: Colors.blue),
              SizedBox(width: 8),
              Text('Restart Game'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'exit',
          child: Row(
            children: [
              Icon(Icons.close, color: Colors.red),
              SizedBox(width: 8),
              Text('Exit Game'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreBar(AppLocalizations? l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _GlassCard(
              gradient: LinearGradient(
                colors: [Colors.amber.shade600, Colors.orange.shade600],
              ),
              child: Column(
                children: [
                  Text(
                    l10n?.score ?? "Score",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withAlpha(200),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ValueListenableBuilder<int>(
                    valueListenable: scoreNotifier,
                    builder: (_, score, __) => Text(
                      score.toString(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _GlassCard(
              gradient: LinearGradient(
                colors: [Colors.purple.shade500, Colors.deepPurple.shade500],
              ),
              child: Column(
                children: [
                  Text(
                    "Best",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withAlpha(200),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _highScore.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _GlassCard(
              gradient: LinearGradient(
                colors: _combo > 0
                    ? [Colors.pink.shade500, Colors.red.shade500]
                    : [Colors.teal.shade500, Colors.cyan.shade500],
              ),
              child: Column(
                children: [
                  Text(
                    l10n?.combo ?? "Combo",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withAlpha(200),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "x$_combo",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _combo > 0 ? Colors.yellowAccent : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _GlassCard(
              gradient: LinearGradient(
                colors: [Colors.green.shade500, Colors.lightGreen.shade500],
              ),
              child: Column(
                children: [
                  Text(
                    "Lines",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withAlpha(200),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _linesCleared.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameGrid(double cellSize, double padding) {
    return Container(
      margin: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withAlpha(20),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(gridSize, (row) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(gridSize, (col) {
                    return _buildGridCell(row, col, cellSize);
                  }),
                );
              }),
            ),
            if (_particles.isNotEmpty)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _particleController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(cellSize * gridSize, cellSize * gridSize),
                      painter: _ParticlePainter(
                        _particles,
                        _particleController.value,
                        cellSize,
                      ),
                    );
                  },
                ),
              ),
            if (_showGameOverDialog)
              _buildGameOverOverlay(),
            if (_showTutorial)
              _buildTutorialOverlay(cellSize),
            if (_showThemeDialog)
              _buildThemeSelectionDialog(),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCell(int row, int col, double cellSize) {
    final colorIndex = grid[row][col];
    final isClearingRow = _clearingRows.contains(row);
    final isClearingCol = _clearingCols.contains(col);
    final isClearing = isClearingRow || isClearingCol;

    bool isPreview = false;
    bool isValidPreview = false;
    if (_previewPosition != null && _draggedPiece != null) {
      final previewRow = _previewPosition!.x;
      final previewCol = _previewPosition!.y;

      for (final cell in _draggedPiece!.occupiedCells) {
        if (previewRow + cell.x == row && previewCol + cell.y == col) {
          isPreview = true;
          isValidPreview = _isValidPlacement;
          break;
        }
      }
    }

    Widget cellWidget = Container(
      width: cellSize,
      height: cellSize,
      margin: const EdgeInsets.all(0.5),
      decoration: BoxDecoration(
        color: colorIndex != null
            ? blockColors[colorIndex % blockColors.length]
            : isPreview
                ? isValidPreview
                    ? Colors.green.withAlpha(80)
                    : Colors.red.withAlpha(60)
                : const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: colorIndex != null
              ? Colors.white.withAlpha(60)
              : isPreview
                  ? isValidPreview
                      ? Colors.green.withAlpha(180)
                      : Colors.red.withAlpha(120)
                  : Colors.white.withAlpha(8),
          width: colorIndex != null ? 1 : 0.5,
        ),
        boxShadow: colorIndex != null
            ? [
                BoxShadow(
                  color: blockColors[colorIndex % blockColors.length].withAlpha(100),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: colorIndex != null
          ? Center(
              child: _currentTheme == 'fruits'
                  ? _buildFruitIcon(colorIndex, cellSize * 0.5)
                  : _buildEmojiIcon(colorIndex, cellSize * 0.5),
            )
          : null,
    );

    if (isClearing) {
      cellWidget = AnimatedBuilder(
        animation: _lineClearController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 - (_lineClearController.value * 0.3),
            child: Opacity(
              opacity: 1.0 - _lineClearController.value,
              child: child,
            ),
          );
        },
        child: cellWidget,
      );
    }

    return DragTarget<BlockPiece>(
      onWillAcceptWithDetails: (details) {
        _onGridHover(row, col);
        return _isValidPlacementCheck(details.data, row, col);
      },
      onAcceptWithDetails: (details) {
        _onGridDrop(row, col);
      },
      onLeave: (_) {
        setState(() {
          _previewPosition = null;
          _isValidPlacement = false;
        });
      },
      builder: (context, candidateData, rejectedData) {
        return cellWidget;
      },
    );
  }

  Widget _buildPiecesArea(AppLocalizations? l10n, bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(
          color: Colors.white.withAlpha(15),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return _buildDraggablePiece(index, isSmallScreen);
        }),
      ),
    );
  }

  Widget _buildDraggablePiece(int index, bool isSmallScreen) {
    final piece = _availablePieces[index];
    final containerSize = isSmallScreen ? 55.0 : 70.0;

    if (piece == null) {
      return Container(
        width: containerSize,
        height: containerSize,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withAlpha(10),
            width: 0.5,
          ),
        ),
      );
    }

    final cellSize = containerSize / 4;

    Widget pieceWidget = AnimatedBuilder(
      animation: _pieceBounceControllers[index],
      builder: (context, child) {
        final bounce = 1.0 + (_pieceBounceControllers[index].value * 0.03);
        return Transform.scale(
          scale: bounce,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () => _rotatePiece(index),
        child: Container(
          width: containerSize,
          height: containerSize,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: blockColors[piece.colorIndex].withAlpha(100),
              width: 1,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(piece.height, (r) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(piece.width, (c) {
                    if (piece.shape[r][c] == 0) {
                      return SizedBox(width: cellSize, height: cellSize);
                    }
                    return Container(
                      width: cellSize - 1,
                      height: cellSize - 1,
                      margin: const EdgeInsets.all(0.5),
                      decoration: BoxDecoration(
                        color: blockColors[piece.colorIndex],
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Center(
                        child: _currentTheme == 'fruits'
                            ? _buildFruitIcon(piece.colorIndex, cellSize * 0.35)
                            : _buildEmojiIcon(piece.colorIndex, cellSize * 0.35),
                      ),
                    );
                  }),
                );
              }),
            ),
          ),
        ),
      ),
    );

    return Draggable<BlockPiece>(
      data: piece,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: containerSize * 1.2,
          height: containerSize * 1.2,
          decoration: BoxDecoration(
            color: blockColors[piece.colorIndex].withAlpha(40),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Transform.scale(
              scale: 1.1,
              child: pieceWidget,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.2,
        child: pieceWidget,
      ),
      onDragStarted: () => _onPieceDragStart(piece, index),
      onDragCompleted: () {
        setState(() {
          _draggedPiece = null;
          _draggedPieceIndex = null;
          _previewPosition = null;
        });
      },
      onDraggableCanceled: (_, __) {
        setState(() {
          _draggedPiece = null;
          _draggedPieceIndex = null;
          _previewPosition = null;
        });
      },
      child: pieceWidget,
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      color: Colors.black.withAlpha(200),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1A237E),
                const Color(0xFF3949AB),
                const Color(0xFF5C6BC0),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.tealAccent.withAlpha(100),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(150),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.redAccent.shade400,
                      Colors.pinkAccent.shade400,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withAlpha(100),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.gamepad,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Game Over!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<int>(
                valueListenable: scoreNotifier,
                builder: (_, score, __) => Column(
                  children: [
                    Text(
                      "Final Score: $score",
                      style: TextStyle(
                        color: Colors.white.withAlpha(230),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (score > _highScore)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "NEW HIGH SCORE!",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Best: $_highScore",
                style: TextStyle(
                  color: Colors.white.withAlpha(150),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _restartGame,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.tealAccent.shade400,
                        Colors.cyanAccent.shade400,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.tealAccent.withAlpha(100),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, color: Colors.black87, size: 24),
                      SizedBox(width: 8),
                      Text(
                        "Play Again",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialOverlay(double cellSize) {
    final l10n = AppLocalizations.of(context);

    final steps = [
      {
        'icon': Icons.grid_on,
        'title': l10n?.welcomeToBrainStorming ?? "Welcome to Block Blast!",
        'message': "Drag colorful block pieces to fill the 8x8 grid.",
      },
      {
        'icon': Icons.touch_app,
        'title': "How to Play",
        'message': "Drag pieces from the bottom to the grid. Tap a piece to rotate it!",
      },
      {
        'icon': Icons.auto_awesome,
        'title': "Clear Lines",
        'message': "Fill entire rows or columns to clear them and earn bonus points!",
      },
    ];

    final currentStep = steps[_tutorialStep];

    return GestureDetector(
      onTap: _nextTutorialStep,
      child: Container(
        color: Colors.black.withAlpha(220),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1A237E),
                  const Color(0xFF3949AB),
                  const Color(0xFF5C6BC0),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.tealAccent.withAlpha(100),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(100),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    steps.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: index == _tutorialStep ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index == _tutorialStep
                            ? Colors.tealAccent
                            : Colors.white.withAlpha(100),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withAlpha(30),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.tealAccent.withAlpha(100),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    currentStep['icon'] as IconData,
                    color: Colors.tealAccent.shade200,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  currentStep['title'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  currentStep['message'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _nextTutorialStep,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.tealAccent.shade400,
                          Colors.cyanAccent.shade400,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.tealAccent.withAlpha(100),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _tutorialStep < steps.length - 1 ? "Next" : "Start Playing",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _tutorialStep < steps.length - 1
                              ? Icons.arrow_forward
                              : Icons.play_arrow,
                          color: Colors.black87,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_tutorialStep == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GestureDetector(
                      onTap: _dismissTutorial,
                      child: Text(
                        l10n?.dontShowAgain ?? "Don't show again",
                        style: TextStyle(
                          color: Colors.white.withAlpha(150),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelectionDialog() {
    final l10n = AppLocalizations.of(context);

    return Container(
      color: Colors.black.withAlpha(220),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1A237E),
                const Color(0xFF3949AB),
                const Color(0xFF5C6BC0),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.tealAccent.withAlpha(100),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(150),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.tealAccent.shade400,
                      Colors.cyanAccent.shade400,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.tealAccent.withAlpha(100),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.palette,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n?.chooseYourTheme ?? "Choose Your Theme",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n?.selectEmojiStyle ?? "Select your favorite style",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(180),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _changeTheme('fruits'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade400,
                              Colors.redAccent.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _currentTheme == 'fruits'
                                ? Colors.white
                                : Colors.white.withAlpha(100),
                            width: _currentTheme == 'fruits' ? 4 : 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _currentTheme == 'fruits'
                                  ? Colors.orange.withAlpha(150)
                                  : Colors.orange.withAlpha(80),
                              blurRadius: _currentTheme == 'fruits' ? 25 : 15,
                              spreadRadius: _currentTheme == 'fruits' ? 6 : 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "🍎 🍌 🍇",
                              style: TextStyle(fontSize: 32),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n?.fruits ?? "Fruits",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n?.classicFruitEmojis ?? "Classic fruit style",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withAlpha(150),
                                fontSize: 11,
                              ),
                            ),
                            if (_currentTheme == 'fruits')
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  l10n?.selected ?? "Selected",
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _changeTheme('emojis'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purpleAccent.shade400,
                              Colors.deepPurpleAccent.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _currentTheme == 'emojis'
                                ? Colors.white
                                : Colors.white.withAlpha(100),
                            width: _currentTheme == 'emojis' ? 4 : 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _currentTheme == 'emojis'
                                  ? Colors.purpleAccent.withAlpha(150)
                                  : Colors.purpleAccent.withAlpha(80),
                              blurRadius: _currentTheme == 'emojis' ? 25 : 15,
                              spreadRadius: _currentTheme == 'emojis' ? 6 : 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "😂 ❤️ 🔥",
                              style: TextStyle(fontSize: 32),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n?.emojis ?? "Emojis",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n?.socialMediaFavorites ?? "Social media style",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withAlpha(150),
                                fontSize: 11,
                              ),
                            ),
                            if (_currentTheme == 'emojis')
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  l10n?.selected ?? "Selected",
                                  style: TextStyle(
                                    color: Colors.purple,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _lineClearController.dispose();
    _piecePlaceController.dispose();
    _backgroundController.dispose();
    _particleController.dispose();
    _tutorialController.dispose();
    _handSwipeController.dispose();
    for (final controller in _pieceBounceControllers) {
      controller.dispose();
    }
    AdMobService.disposeInterstitialAd(_interstitialAd);
    scoreNotifier.dispose();
    _volumeController.removeListener();
    _disposeAudioPlayer();
    super.dispose();
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;

  const _GlassCard({required this.child, this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: gradient ?? LinearGradient(colors: [Colors.white24, Colors.white10]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            offset: const Offset(2, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Particle {
  double x, y;
  double vx, vy;
  Color color;
  double size;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final double cellSize;

  _ParticlePainter(this.particles, this.progress, this.cellSize);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final x = particle.x * cellSize + cellSize / 2;
      final y = particle.y * cellSize + cellSize / 2;

      final currentX = x + particle.vx * progress * 50;
      final currentY = y + particle.vy * progress * 50 + 0.5 * 9.8 * progress * progress * 50;
      final currentSize = particle.size * (1 - progress);

      if (currentSize > 0) {
        final paint = Paint()
          ..color = particle.color.withAlpha((255 * (1 - progress)).toInt())
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          Offset(currentX, currentY),
          currentSize,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
