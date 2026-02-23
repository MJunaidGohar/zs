import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
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

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // ------------------- BACKGROUND MUSIC -------------------
  AudioPlayer? _audioPlayer;
  bool _isMusicPlaying = false;
  bool _isMusicEnabled = true; // Toggle for music on/off
  String? _customAudioPath; // Path to user-selected custom audio
  static const String _customAudioPrefKey = 'custom_audio_path';

  // ------------------- ADS -------------------
  InterstitialAd? _interstitialAd;
  bool _adShown = false;
  int _lastAdTriggerCombo = 0; // Track last combo milestone when ad was shown

  // ------------------- GRID CONFIG -------------------
  static const int gridRows = 8;
  int gridCols = 6;
  late List<List<int>> grid;
  final Random _random = Random();

  // ------------------- EMOJI THEMES -------------------
  static const String _themePrefKey = 'game_theme';
  String _currentTheme = 'fruits'; // 'fruits' or 'emojis'
  bool _showThemeDialog = false;

  final List<String> _fruitEmojis = [
    "🍎", "🍌", "🍇", "🍊", "🍓", "🍉", "🍑", "🍒"
  ];

  // Popular social media emojis - most commonly used and attractive
  final List<String> _socialEmojis = [
    "😂", "❤️", "🔥", "😍", "🥰", "👍", "🎉", "😎"
  ];

  List<String> get emojis => _currentTheme == 'fruits' ? _fruitEmojis : _socialEmojis;

  // ------------------- SCORE / COMBO -------------------
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  int combo = 0;
  int _lastVibratedMilestone = 0; // Track last 1000-point milestone vibrated

  // ------------------- SELECTION -------------------
  int? selR, selC;

  // ------------------- STUCK BOARD HANDLING -------------------
  bool _stuckNotified = false;

  Timer? _idleHintTimer;
  Point<int>? _hintA;
  Point<int>? _hintB;
  late final AnimationController _hintPulseController;

  // ------------------- CASCADE CONTROL -------------------
  int _cascadeDepth = 0;
  static const int _cascadeDepthLimit = 30;

  // ------------------- EFFECTS -------------------
  final List<_Effect> _effects = [];
  final List<_Particle> _particles = [];
  static const int _maxEffects = 50;

  // ------------------- TUTORIAL -------------------
  bool _showTutorial = false;
  int _tutorialStep = 0;
  late final AnimationController _tutorialController;
  late final AnimationController _handSwipeController;
  late final AnimationController _backgroundController;
  late final AnimationController _particleController;

  // ------------------- VOLUME CONTROL -------------------
  final VolumeController _volumeController = VolumeController();
  double _currentVolume = 0.5;
  StreamSubscription<double>? _volumeListener;

  @override
  void initState() {
    super.initState();
    _hintPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _tutorialController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _handSwipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadThemeAndInit();
    // Removed: _loadAd() - now shows at 100 score milestone instead
    _loadCustomAudioPath(); // Load saved custom audio path
    _initAudioPlayer();
    _initVolumeController();
  }

  // ------------------- CUSTOM AUDIO METHODS -------------------
  Future<void> _loadCustomAudioPath() async {
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
    try {
      // Pick audio file only
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final selectedPath = result.files.single.path!;
        
        // Verify file exists
        if (!File(selectedPath).existsSync()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Selected file not found')),
            );
          }
          return;
        }

        // Save to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_customAudioPrefKey, selectedPath);

        setState(() {
          _customAudioPath = selectedPath;
        });

        // Restart music with new file
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

      // Restart music to use default
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
    // Get current volume
    _volumeController.getVolume().then((volume) {
      setState(() {
        _currentVolume = volume;
      });
    });

    // Listen to volume changes from hardware buttons
    _volumeListener = _volumeController.listener((volume) {
      setState(() {
        _currentVolume = volume;
      });
      
      // Update audio player volume if music is playing
      if (_audioPlayer != null && _isMusicEnabled) {
        _audioPlayer!.setVolume(volume);
      }
    });
  }

  void _setVolume(double volume) {
    _volumeController.setVolume(volume);
    setState(() {
      _currentVolume = volume;
    });
  }

  // ------------------- AUDIO PLAYER METHODS -------------------
  Future<void> _initAudioPlayer() async {
    try {
      _audioPlayer = AudioPlayer();
      
      // Set to loop mode for continuous background music
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      
      // Load and play background music
      await _playBackgroundMusic();
    } catch (e) {
      // Silently handle audio initialization errors
      debugPrint('Audio player initialization error: $e');
    }
  }

  Future<void> _playBackgroundMusic() async {
    if (_audioPlayer == null || !_isMusicEnabled) return;

    try {
      // Stop any current playback first
      await _audioPlayer!.stop();

      // Play custom audio if available
      if (_customAudioPath != null && File(_customAudioPath!).existsSync()) {
        await _audioPlayer!.play(DeviceFileSource(_customAudioPath!));
        _isMusicPlaying = true;
      } else {
        // No custom audio available - prepared for default music
        // Play from assets when available
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
    // Load saved theme as default, or use 'fruits' if no saved theme
    setState(() {
      _currentTheme = savedTheme ?? 'fruits';
      _showThemeDialog = true; // Always show dialog every time
    });
  }

  Future<void> _saveTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefKey, theme);
  }

  Future<void> _checkFirstTimeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('game_tutorial_seen') ?? false;
    if (!hasSeenTutorial && mounted) {
      setState(() => _showTutorial = true);
      _tutorialController.forward();
      _handSwipeController.repeat(reverse: true);
    }
  }

  void _dismissTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('game_tutorial_seen', true);
    setState(() {
      _showTutorial = false;
      _tutorialStep = 0;
    });
    _handSwipeController.stop();
    _tutorialController.stop();
  }

  void _nextTutorialStep() {
    setState(() {
      _tutorialStep++;
      if (_tutorialStep >= 3) {
        _dismissTutorial();
      }
    });
  }

  // ------------------- AD HELPERS -------------------
  void _loadAd() {
    if (_adShown) return;
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-5721278995377651/6519657994',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
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
      ),
    );
  }

  // ------------------- GRID -------------------
  void _initGrid() {
    grid = List.generate(
      gridRows,
      (_) => List.generate(gridCols, (_) => _random.nextInt(emojis.length)),
    );
    _clearHint();
    _lastVibratedMilestone = 0; // Reset milestone on new game
    setState(() {});
  }

  void _registerInteraction() {
    _clearHint();
    _resetIdleHintTimer();
  }

  void _resetIdleHintTimer() {
    _idleHintTimer?.cancel();
    _idleHintTimer = Timer(const Duration(seconds: 30), _showHintIfPossible);
  }

  void _clearHint() {
    _hintA = null;
    _hintB = null;
    if (_hintPulseController.isAnimating) {
      _hintPulseController.stop();
    }
  }

  List<Point<int>>? _findHintMove() {
    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < gridCols; c++) {
        if (c + 1 < gridCols) {
          _swap(r, c, r, c + 1);
          final m = _findMatches();
          _swap(r, c, r, c + 1);
          if (m.isNotEmpty) return [Point(r, c), Point(r, c + 1)];
        }
        if (r + 1 < gridRows) {
          _swap(r, c, r + 1, c);
          final m = _findMatches();
          _swap(r, c, r + 1, c);
          if (m.isNotEmpty) return [Point(r, c), Point(r + 1, c)];
        }
      }
    }
    return null;
  }

  void _showHintIfPossible() {
    if (!mounted) return;
    if (!_hasAnyPotentialMoves()) return;
    final hint = _findHintMove();
    if (hint == null) return;

    setState(() {
      _hintA = hint[0];
      _hintB = hint[1];
    });

    _hintPulseController.repeat(reverse: true);
  }

  bool _hasAnyPotentialMoves() {
    // Try swapping adjacent tiles; if any swap creates a match, a move exists.
    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < gridCols; c++) {
        if (c + 1 < gridCols) {
          _swap(r, c, r, c + 1);
          final m = _findMatches();
          _swap(r, c, r, c + 1);
          if (m.isNotEmpty) return true;
        }
        if (r + 1 < gridRows) {
          _swap(r, c, r + 1, c);
          final m = _findMatches();
          _swap(r, c, r + 1, c);
          if (m.isNotEmpty) return true;
        }
      }
    }
    return false;
  }

  void _reshuffleBoard() {
    _registerInteraction();
    // Keep current emoji pool; just reshuffle board values until at least one move exists.
    // Also try to avoid immediate matches so user can start playing.
    const int maxAttempts = 60;
    final flat = <int>[];
    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < gridCols; c++) {
        flat.add(_random.nextInt(emojis.length));
      }
    }

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      flat.shuffle(_random);
      int i = 0;
      for (int r = 0; r < gridRows; r++) {
        for (int c = 0; c < gridCols; c++) {
          grid[r][c] = flat[i++];
        }
      }
      if (_findMatches().isEmpty && _hasAnyPotentialMoves()) {
        selR = null;
        selC = null;
        _stuckNotified = false;
        _clearHint();
        setState(() {});
        return;
      }
    }

    // Fallback: ensure at least one move even if matches exist.
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      flat.shuffle(_random);
      int i = 0;
      for (int r = 0; r < gridRows; r++) {
        for (int c = 0; c < gridCols; c++) {
          grid[r][c] = flat[i++];
        }
      }
      if (_hasAnyPotentialMoves()) {
        selR = null;
        selC = null;
        _stuckNotified = false;
        _clearHint();
        setState(() {});
        return;
      }
    }
  }

  Future<void> _changeTheme(String theme) async {
    setState(() {
      _currentTheme = theme;
      _showThemeDialog = false;
    });
    await _saveTheme(theme);
    _initGrid();
    _resetIdleHintTimer();
    _checkFirstTimeTutorial();
  }

  void _onTileTap(int r, int c) {
    _registerInteraction();
    if (selR == null) {
      selR = r;
      selC = c;
      setState(() {});
      return;
    }
    final sr = selR!, sc = selC!;
    if ((sr - r).abs() + (sc - c).abs() != 1) {
      selR = r;
      selC = c;
      setState(() {});
      return;
    }
    selR = null; selC = null;
    _attemptSwap(sr, sc, r, c);
  }

  void _attemptSwap(int r1, int c1, int r2, int c2) {
    _registerInteraction();
    _swap(r1, c1, r2, c2);
    setState(() {});
    final matches = _findMatches();
    if (matches.isNotEmpty) {
      final pts = matches.length * 5;
      combo++;
      scoreNotifier.value += pts;
      _checkAndTriggerVibration();
      _checkAndShowAdAtComboMilestone(); // Check if we hit combo 7 milestone
      _showScorePopup(pts, combo);
      _showExplosionEffect(matches.toList());
      _removeAndRefill(matches.toList());
    } else {
      combo = 0;
      scoreNotifier.value = max(0, scoreNotifier.value - 1);
    }
  }

  void _checkAndTriggerVibration() {
    final currentScore = scoreNotifier.value;
    final currentMilestone = (currentScore ~/ 1000) * 1000;
    
    // Check if we crossed a new 1000-point milestone
    if (currentMilestone > 0 && currentMilestone > _lastVibratedMilestone) {
      _lastVibratedMilestone = currentMilestone;
      _triggerVibration();
    }
  }

  void _checkAndShowAdAtComboMilestone() {
    // Show ad when combo reaches 7 (and not already shown at this combo milestone)
    if (combo >= 7 && combo != _lastAdTriggerCombo) {
      _lastAdTriggerCombo = combo;
      _loadAd();
    }
  }

  Future<void> _triggerVibration() async {
    try {
      // Check if device has vibration capability
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // Vibrate for 300ms
        await Vibration.vibrate(duration: 300);
      }
    } catch (e) {
      // Silently fail if vibration is not available
    }
  }

  void _swap(int r1, int c1, int r2, int c2) {
    final tmp = grid[r1][c1];
    grid[r1][c1] = grid[r2][c2];
    grid[r2][c2] = tmp;
  }

  Set<Point<int>> _findMatches() {
    final matched = <Point<int>>{};
    // horizontal
    for (int r = 0; r < gridRows; r++) {
      int run = 1;
      for (int c = 1; c < gridCols; c++) {
        if (grid[r][c] == grid[r][c - 1]) {
          run++;
        } else {
          if (run >= 3) {
            for (int k = 0; k < run; k++) {
              matched.add(Point(r, c - 1 - k));
            }
          }
          run = 1;
        }
      }
      if (run >= 3) {
        for (int k = 0; k < run; k++) {
          matched.add(Point(r, gridCols - 1 - k));
        }
      }
    }
    // vertical
    for (int c = 0; c < gridCols; c++) {
      int run = 1;
      for (int r = 1; r < gridRows; r++) {
        if (grid[r][c] == grid[r - 1][c]) {
          run++;
        } else {
          if (run >= 3) {
            for (int k = 0; k < run; k++) {
              matched.add(Point(r - 1 - k, c));
            }
          }
          run = 1;
        }
      }
      if (run >= 3) {
        for (int k = 0; k < run; k++) {
          matched.add(Point(gridRows - 1 - k, c));
        }
      }
    }
    return matched;
  }

  void _removeAndRefill(List<Point<int>> matched) {
    if (_cascadeDepth > _cascadeDepthLimit) {
      _cascadeDepth = 0;
      return;
    }
    _cascadeDepth++;
    for (var p in matched) {
      if (p.x >= 0 && p.x < gridRows && p.y >= 0 && p.y < gridCols) {
        grid[p.x][p.y] = -1;
      }
    }
    setState(() {});
    for (int c = 0; c < gridCols; c++) {
      final colVals = <int>[];
      for (int r = gridRows - 1; r >= 0; r--) {
        if (grid[r][c] != -1) {
          colVals.add(grid[r][c]);
        }
      }
      while (colVals.length < gridRows) {
        colVals.add(_random.nextInt(emojis.length));
      }
      for (int r = gridRows - 1, i = 0; r >= 0; r--, i++) {
        grid[r][c] = colVals[i];
      }
    }
    Future.delayed(const Duration(milliseconds: 120), () {
      final nextMatches = _findMatches();
      if (nextMatches.isNotEmpty) {
        final pts = nextMatches.length * 10;
        combo++;
        scoreNotifier.value += pts;
        _checkAndTriggerVibration();
        _checkAndShowAdAtComboMilestone(); // Check if we hit combo 7 milestone
        _showScorePopup(pts, combo);
        _showExplosionEffect(nextMatches.toList());
        _removeAndRefill(nextMatches.toList());
      } else {
        _cascadeDepth = 0;

        // If the board becomes stuck (no possible match-producing move), notify.
        final hasMoves = _hasAnyPotentialMoves();
        if (!hasMoves && mounted && !_stuckNotified) {
          _stuckNotified = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No matches available. Tap refresh to reshuffle.'),
              action: SnackBarAction(
                label: 'Refresh',
                onPressed: _reshuffleBoard,
              ),
            ),
          );
        }
      }
    });
  }

  // ------------------- EFFECTS -------------------
  void _showScorePopup(int points, int combo) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) {
        return Positioned(
          top: 50,
          left: MediaQuery.of(context).size.width / 2 - 30,
          child: _AnimatedScore(points: points, combo: combo),
        );
      },
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1000), () => entry.remove());
  }

  void _showExplosionEffect(List<Point<int>> tiles) {
    setState(() {
      for (var t in tiles) {
        // Create multiple particles per tile for explosion effect
        for (int i = 0; i < 6; i++) {
          _particles.add(_Particle(
            x: t.y.toDouble(),
            y: t.x.toDouble(),
            vx: (_random.nextDouble() - 0.5) * 6,
            vy: (_random.nextDouble() - 0.5) * 6,
            color: Colors.primaries[_random.nextInt(Colors.primaries.length)],
            size: 3 + _random.nextDouble() * 5,
          ));
        }
      }
    });

    _particleController.forward(from: 0).then((_) {
      setState(() {
        _particles.clear();
      });
    });
  }

  // ------------------- TUTORIAL WIDGET -------------------
  Widget _buildTutorialOverlay(double tileSize, double padding) {
    // Calculate position for the first two adjacent tiles in the center
    final startRow = gridRows ~/ 2 - 1;
    final startCol = gridCols ~/ 2 - 1;
    final gap = 6.0;

    // Calculate actual pixel positions for the two tiles
    final tile1Left = padding + startCol * (tileSize + gap);
    final tile1Top = padding + startRow * (tileSize + gap);
    final tile2Left = padding + (startCol + 1) * (tileSize + gap);

    final centerX = (tile1Left + tile2Left + tileSize) / 2;
    final centerY = tile1Top + tileSize / 2;

    // Tutorial steps content
    final List<Map<String, dynamic>> steps = [
      {
        'icon': Icons.games,
        'title': 'Welcome to BrainStorming!',
        'message': 'Match colorful tiles to score points and create amazing combos!',
        'showDemo': false,
      },
      {
        'icon': Icons.swap_horiz,
        'title': 'How to Swap',
        'message': 'Tap one tile, then tap an adjacent tile to swap their positions.',
        'showDemo': true,
      },
      {
        'icon': Icons.auto_awesome,
        'title': 'Make Matches',
        'message': 'Match 3 or more identical tiles to score points and create explosions!',
        'showDemo': true,
      },
    ];

    final currentStep = steps[_tutorialStep];

    return GestureDetector(
      onTap: _nextTutorialStep,
      child: Container(
        color: Colors.black.withValues(alpha: 200),
        child: Stack(
          children: [
            // Shimmer background effect
            AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
                  painter: _ShimmerPainter(_backgroundController.value),
                );
              },
            ),
            
            // Demo tiles for steps that need them
            if (currentStep['showDemo'] as bool)
              Positioned(
                left: tile1Left - 8,
                top: tile1Top - 8,
                child: AnimatedBuilder(
                  animation: _tutorialController,
                  builder: (context, child) {
                    final glow = 1.0 + (_tutorialController.value * 0.3);
                    return Container(
                      width: tileSize * 2 + gap + 16,
                      height: tileSize + 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.tealAccent.withValues(alpha: 120),
                            blurRadius: 25 * glow,
                            spreadRadius: 8 * glow,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildDemoTile(tileSize, emojis[0], _tutorialController),
                          SizedBox(width: gap),
                          _buildDemoTile(tileSize, emojis[0], _tutorialController),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Swipe hand animation
            if (currentStep['showDemo'] as bool)
              AnimatedBuilder(
                animation: _handSwipeController,
                builder: (context, child) {
                  final slide = _handSwipeController.value;
                  return Positioned(
                    left: centerX - 24 + (slide * 40),
                    top: centerY + 10,
                    child: Transform.rotate(
                      angle: -0.3,
                      child: Icon(
                        Icons.touch_app,
                        size: 56,
                        color: Colors.white.withValues(alpha: 240),
                      ),
                    ),
                  );
                },
              ),

            // Tutorial card
            Positioned(
              left: 0,
              right: 0,
              bottom: 100,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
                      color: Colors.tealAccent.withValues(alpha: 100),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 100),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.tealAccent.withValues(alpha: 50),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress dots
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
                                  : Colors.white.withValues(alpha: 100),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent.withValues(alpha: 30),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.tealAccent.withValues(alpha: 100),
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
                      
                      // Title
                      Text(
                        currentStep['title'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Message
                      Text(
                        currentStep['message'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 200),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Action button
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
                                color: Colors.tealAccent.withValues(alpha: 100),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _tutorialStep < steps.length - 1 ? 'Next' : 'Start Playing!',
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
                      const SizedBox(height: 12),
                      
                      // Skip option
                      if (_tutorialStep == 0)
                        GestureDetector(
                          onTap: () => _dismissTutorial(),
                          child: Text(
                            "Don't show this again",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 150),
                              fontSize: 14,
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
      ),
    );
  }

  Widget _buildDemoTile(double tileSize, String emoji, AnimationController controller) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 1.0 + (controller.value * 0.05);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.indigo.shade500.withAlpha(235),
                  Colors.purpleAccent.shade200.withAlpha(235),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withAlpha(50),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(140),
                  offset: const Offset(0, 6),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Center(
              child: Text(
                emoji,
                style: TextStyle(
                  fontSize: tileSize * 0.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ------------------- THEME SELECTION DIALOG -------------------
  Widget _buildThemeSelectionDialog(double tileSize) {
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
              BoxShadow(
                color: Colors.tealAccent.withAlpha(60),
                blurRadius: 50,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
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

              // Title
              const Text(
                "Choose Your Theme",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Select the emoji style you want to play with",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(180),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),

              // Theme options
              Row(
                children: [
                  // Fruits option
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
                            const Text(
                              "Fruits",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Classic fruit emojis",
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
                                child: const Text(
                                  "Selected",
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
                  // Emojis option
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
                            const Text(
                              "Emojis",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Social media favorites",
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
                                child: const Text(
                                  "Selected",
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
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final candidate = (width ~/ 64).clamp(5, 9);
    if (candidate != gridCols) {
      gridCols = candidate;
      _initGrid();
    }
    final padding = 12.0;
    final gap = 6.0;
    final tileSize = (width - padding * 2 - (gridCols - 1) * gap) / gridCols;

    final hasMoves = _hasAnyPotentialMoves();
    if (hasMoves) {
      _stuckNotified = false;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070B12),
      body: SafeArea(
        child: Column(
          children: [
            // ------------------- TOP BAR -------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 390;

                  final titleScoreCard = _GlassCard(
                    gradient: LinearGradient(colors: [Colors.indigo.shade400, Colors.purpleAccent.shade200]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: const [
                          Text("🕹 ", style: TextStyle(fontSize: 18)),
                          Text("BrainStroming", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ]),
                        Row(
                          children: [
                            ValueListenableBuilder<int>(
                              valueListenable: scoreNotifier,
                              builder: (_, score, child) => Text(
                                "Score: $score",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.yellowAccent),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _toggleMusic,
                              child: Icon(
                                _isMusicEnabled ? Icons.volume_up : Icons.volume_off,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );

                  final refreshButton = GestureDetector(
                    onTap: hasMoves ? null : _reshuffleBoard,
                    child: Opacity(
                      opacity: hasMoves ? 0.45 : 1,
                      child: _GlassCard(
                        gradient: LinearGradient(colors: [Colors.blueGrey.shade400, Colors.blueGrey.shade200]),
                        child: const Icon(Icons.refresh, color: Colors.white),
                      ),
                    ),
                  );

                  final closeButton = GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: _GlassCard(
                      gradient: LinearGradient(colors: [Colors.red.shade400, Colors.redAccent.shade200]),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  );

                  final customAudioButton = GestureDetector(
                    onTap: _showAudioOptionsDialog,
                    child: _GlassCard(
                      gradient: LinearGradient(
                        colors: _customAudioPath != null
                            ? [Colors.green.shade400, Colors.teal.shade400]
                            : [Colors.blueGrey.shade400, Colors.blueGrey.shade200],
                      ),
                      child: Icon(
                        _customAudioPath != null ? Icons.music_note : Icons.music_off,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  );

                  final comboCard = _GlassCard(
                    gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.redAccent.shade200]),
                    child: Column(
                      children: [
                        const Text("COMBO", style: TextStyle(fontSize: 11, color: Colors.white70)),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 400),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14 + combo.toDouble() * 0.5,
                            color: combo > 0 ? Colors.yellowAccent : Colors.white,
                          ),
                          child: Text("$combo"),
                        ),
                      ],
                    ),
                  );

                  if (!isNarrow) {
                    return Row(
                      children: [
                        Expanded(child: titleScoreCard),
                        const SizedBox(width: 10),
                        customAudioButton,
                        const SizedBox(width: 10),
                        refreshButton,
                        const SizedBox(width: 10),
                        closeButton,
                        const SizedBox(width: 10),
                        comboCard,
                      ],
                    );
                  }

                  return Column(
                    children: [
                      titleScoreCard,
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: comboCard),
                          const SizedBox(width: 10),
                          customAudioButton,
                          const SizedBox(width: 10),
                          refreshButton,
                          const SizedBox(width: 10),
                          closeButton,
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            // ------------------- GRID -------------------
            Expanded(
              child: Stack(
                children: [
                  GridView.builder(
                    padding: EdgeInsets.all(padding),
                    itemCount: gridRows * gridCols,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridCols,
                      mainAxisSpacing: gap,
                      crossAxisSpacing: gap,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, idx) {
                      final r = idx ~/ gridCols;
                      final c = idx % gridCols;
                      final val = grid[r][c];
                      final displayEmoji = (val >= 0 && val < emojis.length) ? emojis[val % emojis.length] : "";
                      final isSelected = (selR == r && selC == c);
                      final isHint = (_hintA?.x == r && _hintA?.y == c) || (_hintB?.x == r && _hintB?.y == c);
                      return GestureDetector(
                        onTap: () => _onTileTap(r, c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeInOutBack,
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(colors: [Colors.amberAccent.shade100, Colors.deepOrange.shade300])
                                : LinearGradient(colors: [Colors.indigo.shade500.withValues(alpha: 235), Colors.purpleAccent.shade200.withValues(alpha: 235)]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? Colors.yellowAccent : Colors.white12,
                              width: isSelected ? 2.6 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 140), offset: const Offset(0, 6), blurRadius: 14),
                              const BoxShadow(color: Colors.white10, offset: Offset(0, -1), blurRadius: 1)
                            ],
                          ),
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _hintPulseController,
                              builder: (context, child) {
                                final pulse = isHint ? (1 + (_hintPulseController.value * 0.08)) : 1.0;
                                final selectedScale = isSelected ? 1.08 : 1.0;
                                return Transform.scale(
                                  scale: pulse * selectedScale,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: isHint
                                          ? [
                                              BoxShadow(
                                                color: Colors.white.withValues(alpha: 38),
                                                blurRadius: 18,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : const [],
                                    ),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                displayEmoji,
                                style: TextStyle(
                                  fontSize: tileSize * 0.54,
                                  shadows: const [Shadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // ------------------- PARTICLES -------------------
                  if (_particles.isNotEmpty)
                    AnimatedBuilder(
                      animation: _particleController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: Size(width, MediaQuery.of(context).size.height),
                          painter: _ParticlePainter(
                            _particles,
                            _particleController.value,
                            tileSize,
                            padding,
                            gap,
                          ),
                        );
                      },
                    ),
                  // ------------------- TUTORIAL -------------------
                  if (_showTutorial)
                    _buildTutorialOverlay(tileSize, padding),
                  // ------------------- THEME SELECTION -------------------
                  if (_showThemeDialog)
                    _buildThemeSelectionDialog(tileSize),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _idleHintTimer?.cancel();
    _hintPulseController.dispose();
    _tutorialController.dispose();
    _handSwipeController.dispose();
    _backgroundController.dispose();
    _particleController.dispose();
    _interstitialAd?.dispose();
    scoreNotifier.dispose();
    _volumeController.removeListener();
    _disposeAudioPlayer();
    super.dispose();
  }
}

// ------------------- GLASS CARD -------------------
class _GlassCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  const _GlassCard({required this.child, this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: gradient ?? LinearGradient(colors: [Colors.white24, Colors.white10]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 77), offset: const Offset(2, 2), blurRadius: 6)],
      ),
      child: child,
    );
  }
}

// ------------------- SCORE POPUP -------------------
class _AnimatedScore extends StatefulWidget {
  final int points;
  final int combo;
  const _AnimatedScore({required this.points, required this.combo});
  @override State<_AnimatedScore> createState() => _AnimatedScoreState();
}

class _AnimatedScoreState extends State<_AnimatedScore> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnim;
  late final Animation<double> _opacityAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _offsetAnim = Tween<Offset>(begin: const Offset(0, 0), end: const Offset(0, -3))
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnim = Tween<double>(begin: 1, end: 0)
        .animate(CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.5)
        .animate(CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)));
    _controller.forward();
  }

  MaterialColor _getComboColor() {
    if (widget.combo >= 5) return Colors.purple;
    if (widget.combo >= 3) return Colors.orange;
    return Colors.yellow;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _offsetAnim.value * 50,
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: Opacity(
              opacity: _opacityAnim.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.combo > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purpleAccent.shade400,
                            Colors.deepPurpleAccent.shade400,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purpleAccent.withAlpha(100),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        "COMBO x${widget.combo}!",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getComboColor().shade400,
                          Colors.amber.shade400,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: _getComboColor().withAlpha(100),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Text(
                      "+${widget.points}",
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override void dispose() { _controller.dispose(); super.dispose(); }
}

// ------------------- EFFECT -------------------
class _Effect { double x,y; int lifetime; _Effect({required this.x, required this.y, required this.lifetime}); }

// ------------------- PARTICLE SYSTEM -------------------
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
  final double tileSize;
  final double padding;
  final double gap;

  _ParticlePainter(this.particles, this.progress, this.tileSize, this.padding, this.gap);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final x = padding + particle.x * (tileSize + gap) + tileSize / 2;
      final y = padding + particle.y * (tileSize + gap) + tileSize / 2;
      
      final currentX = x + particle.vx * progress * 50;
      final currentY = y + particle.vy * progress * 50 + 0.5 * 9.8 * progress * progress * 100;
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

// ------------------- SHIMMER BACKGROUND -------------------
class _ShimmerPainter extends CustomPainter {
  final double progress;

  _ShimmerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withAlpha(10),
          Colors.white.withAlpha(20),
          Colors.white.withAlpha(10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
        transform: GradientRotation(progress * 2 * 3.14159),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
