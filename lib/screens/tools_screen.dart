import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'code_editor_screen.dart';
import '../services/admob_service.dart';
import '../utils/app_theme.dart';
import '../widgets/topic_selection_dialog.dart';

/// ToolsScreen - Dashboard for all utility tools
/// Displays tools as a grid of clickable icons with labels
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  // ------------------- ADS -------------------
  InterstitialAd? _interstitialAd;
  bool _adShown = false;
  DateTime? _lastAdShown;
  static const int minSecondsBetweenAds = 60; // Minimum 60 seconds between ads
  
  // Banner Ad
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    // Do NOT show interstitial on screen open - policy violation risk
    // Only load banner ad initially
    _loadBannerAd();
  }

  // ------------------- INTERSTITIAL AD -------------------
  /// Shows interstitial only if enough time has passed since last ad
  void _showInterstitialIfAppropriate() {
    if (_adShown) return;
    
    // Rate limiting: prevent ad fatigue
    if (_lastAdShown != null) {
      final secondsSinceLastAd = DateTime.now().difference(_lastAdShown!).inSeconds;
      if (secondsSinceLastAd < minSecondsBetweenAds) return;
    }
    
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    AdMobService.loadInterstitialAd(
      adUnitId: 'ca-app-pub-5721278995377651/6519657994',
      onAdLoaded: (ad) {
        _interstitialAd = ad;
        _lastAdShown = DateTime.now();
        try { 
          ad.show(); 
          _adShown = true; 
        } catch (_) {}
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) => ad.dispose(),
          onAdFailedToShowFullScreenContent: (ad, err) => ad.dispose(),
        );
      },
      onAdFailedToLoad: (err) {
        _interstitialAd = null;
      },
    );
  }

  // ------------------- BANNER AD -------------------
  void _loadBannerAd() {
    if (_bannerAd != null) return;

    _bannerAd = AdMobService.loadBannerAd(
      adUnitId: 'ca-app-pub-5721278995377651/6253583275',
      size: AdSize.banner,
      onAdLoaded: (ad) {
        if (mounted) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        }
      },
      onAdFailedToLoad: (error) {
        if (mounted) {
          setState(() {
            _bannerAd = null;
            _isBannerAdLoaded = false;
          });
        }
      },
    );
  }

  void _disposeBannerAd() {
    AdMobService.disposeBannerAd(_bannerAd);
    _bannerAd = null;
    _isBannerAdLoaded = false;
  }

  @override
  void dispose() {
    AdMobService.disposeInterstitialAd(_interstitialAd);
    _disposeBannerAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Tools',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: 0.3,
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.gradientHeader,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppBorderRadius.lg),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.backgroundDark,
                    Color(0xFF1E1B4B),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.backgroundLight,
                    Color(0xFFE0E7FF),
                  ],
                ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                _buildHeaderCard(context, isDark),
                const SizedBox(height: AppSpacing.xl),
                // Tools Grid
                Expanded(
                  child: _buildToolsGrid(context, isDark),
                ),
                // Banner Ad - at bottom
                Container(
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: _isBannerAdLoaded && _bannerAd != null
                      ? _bannerAd!.size.height.toDouble()
                      : 50,
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                  child: _isBannerAdLoaded && _bannerAd != null
                      ? AdWidget(ad: _bannerAd!)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.visibility_off,
                              size: 16,
                              color: isDark ? Colors.grey[600] : Colors.grey[400],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Ad loading...',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[600] : Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [
                  Color(0xFF312E81),
                  Color(0xFF4C1D95),
                ]
              : AppColors.gradientLightHeader,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.1),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.construction,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Utility Tools',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Select a tool to get started',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsGrid(BuildContext context, bool isDark) {
    // Define tools data - only real tools, no placeholders
    final tools = [
      _ToolItem(
        icon: Icons.workspace_premium,
        label: 'Get Certificate',
        color: AppColors.accentBlue,
        onTap: () => _onCertificateTap(),
      ),
      _ToolItem(
        icon: Icons.code,
        label: 'Development',
        color: AppColors.accentGreen,
        onTap: () => _onDevelopmentTap(),
      ),
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.lg,
        mainAxisSpacing: AppSpacing.lg,
        childAspectRatio: 1.1,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        return _buildToolCard(context, tools[index], isDark);
      },
    );
  }

  Widget _buildToolCard(BuildContext context, _ToolItem tool, bool isDark) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        tool.onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          boxShadow: AppShadows.cardLight,
          border: Border.all(
            color: tool.color.withValues(alpha: isDark ? 0.3 : 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    tool.color.withValues(alpha: isDark ? 0.3 : 0.15),
                    tool.color.withValues(alpha: isDark ? 0.15 : 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              ),
              child: Icon(
                tool.icon,
                size: 36,
                color: tool.color,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              tool.label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String toolName) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.surfaceLight : AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        ),
        content: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: isDark ? AppColors.primary : AppColors.primaryLight,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$toolName coming soon!',
              style: TextStyle(
                color: isDark ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Handles certificate tool tap - shows topic selection dialog
  void _onCertificateTap() {
    HapticFeedback.mediumImpact();
    
    // Show interstitial at natural break point
    _showInterstitialIfAppropriate();
    
    // Show topic selection dialog
    showDialog(
      context: context,
      builder: (context) => const TopicSelectionDialog(),
    );
  }

  /// Handles development tool tap - opens code editor
  void _onDevelopmentTap() {
    HapticFeedback.mediumImpact();
    
    // Show interstitial at natural break point
    _showInterstitialIfAppropriate();
    
    // Navigate to code editor
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CodeEditorScreen()),
    );
  }

  /// Handles tool tap - shows ad at natural break point (after user action)
  void _onToolTap(String toolName) {
    HapticFeedback.mediumImpact();
    
    // Show interstitial at natural break point (user initiated action)
    // Only if not already shown in this session
    _showInterstitialIfAppropriate();
    
    // Show coming soon message
    _showComingSoon(context, toolName);
  }
}

/// Helper class to store tool data
class _ToolItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ToolItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
