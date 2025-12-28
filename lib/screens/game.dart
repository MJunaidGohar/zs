import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // ------------------- ADS -------------------
  InterstitialAd? _interstitialAd;
  bool _adShown = false;

  // ------------------- GRID CONFIG -------------------
  static const int gridRows = 8;
  int gridCols = 6;
  late List<List<int>> grid;
  final Random _random = Random();

  // ------------------- EMOJIS -------------------
  final List<String> emojis = [
    "😀","😂","😍","🥳","🤩","😎","😭","😡","😱","😇",
    "🥰","😈","🤯","💥","✨","😺","🙃","😉","🤗","🤤",
    "😴","🤓","😏","🤠","🥶","😵","🤡","🤖"
  ];

  // ------------------- SCORE / COMBO -------------------
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  int combo = 0;

  // ------------------- SELECTION -------------------
  int? selR, selC;

  // ------------------- CASCADE CONTROL -------------------
  int _cascadeDepth = 0;
  static const int _cascadeDepthLimit = 30;

  // ------------------- SPARKLES / BLASTS -------------------
  final List<_Effect> _effects = [];
  static const int _maxEffects = 50;

  @override
  void initState() {
    super.initState();
    _initGrid();
    _loadAd();
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
          try { ad.show(); _adShown = true; } catch (_) {}
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) => ad.dispose(),
            onAdFailedToShowFullScreenContent: (ad, err) => ad.dispose(),
          );
        },
        onAdFailedToLoad: (err) => _interstitialAd = null,
      ),
    );
  }

  // ------------------- GRID -------------------
  void _initGrid() {
    grid = List.generate(
      gridRows,
      (_) => List.generate(gridCols, (_) => _random.nextInt(emojis.length)),
    );
    setState(() {});
  }

  void _onTileTap(int r, int c) {
    if (selR == null) { selR = r; selC = c; setState(() {}); return; }
    final sr = selR!, sc = selC!;
    if ((sr - r).abs() + (sc - c).abs() != 1) { selR = r; selC = c; setState(() {}); return; }
    selR = null; selC = null;
    _attemptSwap(sr, sc, r, c);
  }

  void _attemptSwap(int r1, int c1, int r2, int c2) {
    _swap(r1, c1, r2, c2);
    setState(() {});
    final matches = _findMatches();
    if (matches.isNotEmpty) {
      final pts = matches.length * 5;
      combo++;
      scoreNotifier.value += pts;
      _showScorePopup(pts);
      _showEffect(matches.toList());
      _removeAndRefill(matches.toList());
    } else {
      combo = 0;
      scoreNotifier.value = max(0, scoreNotifier.value - 1);
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
        if (grid[r][c] == grid[r][c - 1]) run++;
        else { if (run >= 3) for (int k = 0; k < run; k++) matched.add(Point(r, c - 1 - k)); run = 1; }
      }
      if (run >= 3) for (int k = 0; k < run; k++) matched.add(Point(r, gridCols - 1 - k));
    }
    // vertical
    for (int c = 0; c < gridCols; c++) {
      int run = 1;
      for (int r = 1; r < gridRows; r++) {
        if (grid[r][c] == grid[r - 1][c]) run++;
        else { if (run >= 3) for (int k = 0; k < run; k++) matched.add(Point(r - 1 - k, c)); run = 1; }
      }
      if (run >= 3) for (int k = 0; k < run; k++) matched.add(Point(gridRows - 1 - k, c));
    }
    return matched;
  }

  void _removeAndRefill(List<Point<int>> matched) {
    if (_cascadeDepth > _cascadeDepthLimit) { _cascadeDepth = 0; return; }
    _cascadeDepth++;
    for (var p in matched) if (p.x >= 0 && p.x < gridRows && p.y >= 0 && p.y < gridCols) grid[p.x][p.y] = -1;
    setState(() {});
    for (int c = 0; c < gridCols; c++) {
      final colVals = <int>[];
      for (int r = gridRows - 1; r >= 0; r--) if (grid[r][c] != -1) colVals.add(grid[r][c]);
      while (colVals.length < gridRows) colVals.add(_random.nextInt(emojis.length));
      for (int r = gridRows - 1, i = 0; r >= 0; r--, i++) grid[r][c] = colVals[i];
    }
    Future.delayed(const Duration(milliseconds: 120), () {
      final nextMatches = _findMatches();
      if (nextMatches.isNotEmpty) {
        final pts = nextMatches.length * 10;
        combo++;
        scoreNotifier.value += pts;
        _showScorePopup(pts);
        _showEffect(nextMatches.toList());
        _removeAndRefill(nextMatches.toList());
      } else _cascadeDepth = 0;
    });
  }

  // ------------------- EFFECTS -------------------
  void _showScorePopup(int points) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) {
        return Positioned(
          top: 50,
          left: MediaQuery.of(context).size.width / 2 - 30,
          child: _AnimatedScore(points: points),
        );
      },
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 800), () => entry.remove());
  }

  void _showEffect(List<Point<int>> tiles) {
    for (var t in tiles) {
      if (_effects.length < _maxEffects) {
        _effects.add(_Effect(x: t.y.toDouble(), y: t.x.toDouble(), lifetime: 600 + _random.nextInt(400)));
      }
    }
    setState(() {});
    // remove effects after lifetime
    Future.delayed(const Duration(milliseconds: 800), () {
      _effects.clear();
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final candidate = (width ~/ 64).clamp(5, 9);
    if (candidate != gridCols) { gridCols = candidate; _initGrid(); }
    final padding = 12.0;
    final gap = 6.0;
    final tileSize = (width - padding * 2 - (gridCols - 1) * gap) / gridCols;

    return Scaffold(
      backgroundColor: const Color(0xFF050505), // royal black
      body: SafeArea(
        child: Column(
          children: [
            // ------------------- TOP BAR -------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _GlassCard(
                      gradient: LinearGradient(colors: [Colors.deepPurple.shade400, Colors.purpleAccent.shade200]),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: const [
                            Text("🕹 ", style: TextStyle(fontSize: 18)),
                            Text("BrainStroming", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ]),
                          ValueListenableBuilder<int>(
                            valueListenable: scoreNotifier,
                            builder: (_, score, __) => Text(
                              "Score: $score",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.yellowAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: _GlassCard(
                      gradient: LinearGradient(colors: [Colors.red.shade400, Colors.redAccent.shade200]),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _GlassCard(
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
                  ),
                ],
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
                      return GestureDetector(
                        onTap: () => _onTileTap(r, c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeInOutBack,
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(colors: [Colors.orangeAccent.shade100, Colors.deepOrange.shade200])
                                : LinearGradient(colors: [Colors.deepPurple.shade500.withOpacity(0.9), Colors.purpleAccent.shade200.withOpacity(0.9)]),
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected ? Border.all(color: Colors.yellowAccent, width: 3) : null,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.45), offset: const Offset(3,3), blurRadius: 6),
                              const BoxShadow(color: Colors.white10, offset: Offset(-2,-2), blurRadius: 2)
                            ],
                          ),
                          child: Center(
                            child: Text(displayEmoji, style: TextStyle(fontSize: tileSize * 0.52)),
                          ),
                        ),
                      );
                    },
                  ),
                  // ------------------- EFFECTS -------------------
                  ..._effects.map((e) => Positioned(
                    left: e.x * tileSize + tileSize / 4,
                    top: e.y * tileSize + tileSize / 4 + padding,
                    child: const Icon(Icons.star, color: Colors.yellowAccent, size: 16),
                  )),
                ],
              ),
            ),
            // ------------------- BOTTOM TIP BAR -------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  "Tip: swap adjacent tiles. Matches give +10 per tile. Failed swap = -1",
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    scoreNotifier.dispose();
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), offset: const Offset(2, 2), blurRadius: 6)],
      ),
      child: child,
    );
  }
}

// ------------------- SCORE POPUP -------------------
class _AnimatedScore extends StatefulWidget {
  final int points;
  const _AnimatedScore({required this.points});
  @override State<_AnimatedScore> createState() => _AnimatedScoreState();
}

class _AnimatedScoreState extends State<_AnimatedScore> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _offsetAnim = Tween<Offset>(begin: const Offset(0,0), end: const Offset(0,-2))
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnim = Tween<double>(begin:1,end:0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnim,
      child: FadeTransition(
        opacity: _opacityAnim,
        child: Text("+${widget.points}", style: const TextStyle(fontSize:20,fontWeight: FontWeight.bold,color:Colors.yellowAccent,shadows:[Shadow(color:Colors.black45,offset:Offset(1,1),blurRadius:4)])),
      ),
    );
  }

  @override void dispose() { _controller.dispose(); super.dispose(); }
}

// ------------------- EFFECT -------------------
class _Effect { double x,y; int lifetime; _Effect({required this.x, required this.y, required this.lifetime}); }
