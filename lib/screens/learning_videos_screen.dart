import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../l10n/app_localizations.dart';
import '../services/admob_service.dart';
import '../services/youtube_api_service.dart';
import '../screens/video_player_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class LearningVideosScreen extends StatefulWidget {
  const LearningVideosScreen({super.key});

  @override
  State<LearningVideosScreen> createState() => _LearningVideosScreenState();
}

class _LearningVideosScreenState extends State<LearningVideosScreen> {
  // ------------------- ADS -------------------
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  InterstitialAd? _interstitialAd;
  bool _adShown = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<VideoItem> _videos = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _nextPageToken;
  bool _hasSearched = false;

  // Allowed domains for display
  final List<String> _allowedDomains = YoutubeApiService.getAllowedDomains();
  String? _selectedDomain;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Interstitial removed from here - will show when leaving screen instead
  }

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

  // ------------------- INTERSTITIAL AD -------------------
  /// Shows interstitial ad when leaving the screen
  void _showInterstitialOnExit() {
    if (_adShown) {
      Navigator.pop(context);
      return;
    }
    
    AdMobService.loadInterstitialAd(
      adUnitId: 'ca-app-pub-5721278995377651/6519657994',
      onAdLoaded: (ad) {
        _interstitialAd = ad;
        _adShown = true;
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            Navigator.pop(context);
          },
          onAdFailedToShowFullScreenContent: (ad, err) {
            ad.dispose();
            Navigator.pop(context);
          },
        );
        try { ad.show(); } catch (_) {
          Navigator.pop(context);
        }
      },
      onAdFailedToLoad: (err) {
        _interstitialAd = null;
        Navigator.pop(context);
      },
    );
  }

  @override
  void dispose() {
    AdMobService.disposeInterstitialAd(_interstitialAd);
    _disposeBannerAd();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_nextPageToken != null && !_isLoading) {
        _loadMoreVideos();
      }
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
      _videos = [];
      _nextPageToken = null;
    });

    try {
      final result = await YoutubeApiService.searchVideos(query, maxResults: 20);

      if (mounted) {
        setState(() {
          _videos = result.videos;
          _nextPageToken = result.nextPageToken;
          _isLoading = false;
        });
        // Load banner ad only after successful search with results
        if (result.videos.isNotEmpty) {
          _loadBannerAd();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_nextPageToken == null || _isLoading) return;

    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await YoutubeApiService.searchVideos(
        query,
        maxResults: 20,
        pageToken: _nextPageToken,
      );

      if (mounted) {
        setState(() {
          _videos.addAll(result.videos);
          _nextPageToken = result.nextPageToken;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onDomainChipTap(String domain) {
    setState(() {
      if (_selectedDomain == domain) {
        _selectedDomain = null;
        _searchController.clear();
      } else {
        _selectedDomain = domain;
        _searchController.text = domain;
      }
    });
    _performSearch();
  }

  void _navigateToPlayer(VideoItem video) {
    // Show interstitial before navigating away
    if (!_adShown) {
      AdMobService.loadInterstitialAd(
        adUnitId: 'ca-app-pub-5721278995377651/6519657994',
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _adShown = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _pushVideoPlayer(video);
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _pushVideoPlayer(video);
            },
          );
          try { ad.show(); } catch (_) { _pushVideoPlayer(video); }
        },
        onAdFailedToLoad: (err) {
          _pushVideoPlayer(video);
        },
      );
    } else {
      _pushVideoPlayer(video);
    }
  }

  void _pushVideoPlayer(VideoItem video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(video: video),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _showInterstitialOnExit,
          tooltip: l10n.backToProfile,
        ),
        title: Text(l10n.learningVideos),
        centerTitle: true,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? theme.colorScheme.surface : Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // YouTube-style Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: _searchFocusNode.hasFocus
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(
                        Icons.search,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: l10n.searchLearningVideos,
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                          style: theme.textTheme.bodyLarge,
                          onSubmitted: (_) => _performSearch(),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _selectedDomain = null;
                            });
                          },
                        ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _performSearch,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.search,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Domain Chips
                SizedBox(
                  height: 40.h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _allowedDomains.length,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    itemBuilder: (context, index) {
                      final domain = _allowedDomains[index];
                      final isSelected = _selectedDomain == domain;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(domain),
                          onSelected: (_) => _onDomainChipTap(domain),
                          selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                          checkmarkColor: theme.colorScheme.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Content Area
          Expanded(
            child: _buildContent(isDark, theme),
          ),

          // Banner Ad - shown when user has searched and has results
          if (_hasSearched && _videos.isNotEmpty && _isBannerAdLoaded)
            Container(
              alignment: Alignment.center,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark, ThemeData theme) {
    if (!_hasSearched && _videos.isEmpty) {
      return _buildInitialState(theme);
    }

    if (_isLoading && _videos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && _videos.isEmpty) {
      return _buildErrorState(theme);
    }

    if (_videos.isEmpty) {
      return _buildEmptyState(theme);
    }

    return _buildVideoList(theme);
  }

  Widget _buildInitialState(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 80.sp,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.discoverLearningVideos,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.searchEducationalVideos,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _allowedDomains.map((domain) {
                return ActionChip(
                  label: Text(domain),
                  onPressed: () => _onDomainChipTap(domain),
                  avatar: Icon(
                    Icons.search,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noResultsFound,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tryDifferentKeywords,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.somethingWentWrong,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _performSearch,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.tryAgain),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoList(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _videos.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _videos.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final video = _videos[index];
        return _buildVideoCard(video, theme);
      },
    );
  }

  Widget _buildVideoCard(VideoItem video, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _navigateToPlayer(video),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Image.network(
                      video.thumbnailUrl,
                      width: 120.w,
                      height: 90.h,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 120.w,
                          height: 90.h,
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 120.w,
                          height: 90.h,
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          child: Icon(
                            Icons.play_circle_outline,
                            size: 40.sp,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        );
                      },
                    ),
                    // Play icon overlay
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 24.sp,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Video Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            video.channelTitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(video.publishedAt, context),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoDate, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 365) {
        return '${(diff.inDays / 365).floor()} ${(diff.inDays / 365).floor() > 1 ? l10n.years : l10n.year} ${l10n.ago}';
      } else if (diff.inDays > 30) {
        return '${(diff.inDays / 30).floor()} ${(diff.inDays / 30).floor() > 1 ? l10n.months : l10n.month} ${l10n.ago}';
      } else if (diff.inDays > 0) {
        return '${diff.inDays} ${diff.inDays > 1 ? l10n.days : l10n.day} ${l10n.ago}';
      } else if (diff.inHours > 0) {
        return '${diff.inHours} ${diff.inHours > 1 ? l10n.hours : l10n.hour} ${l10n.ago}';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes} ${diff.inMinutes > 1 ? l10n.minutes : l10n.minute} ${l10n.ago}';
      } else {
        return l10n.justNow;
      }
    } catch (e) {
      return isoDate;
    }
  }
}
