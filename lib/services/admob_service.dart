// [TEMPORARY] AdMob Service for Web Testing
// This file provides platform-aware AdMob functionality that works on mobile
// and provides stubs for web testing.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:developer' as developer;

/// AdMob service that handles platform differences between mobile and web
class AdMobService {
  static bool get _isWeb => kIsWeb;
  
  /// Initialize AdMob - safely handles web platform
  static Future<void> initialize() async {
    if (_isWeb) {
      developer.log('[TEMP] AdMob: Skipped initialization on web');
      return;
    }
    
    try {
      await MobileAds.instance.initialize();
      developer.log('AdMob initialized successfully');
    } catch (e) {
      developer.log('AdMob initialization failed: $e');
    }
  }
  
  /// Load a banner ad with platform-aware handling
  static BannerAd? loadBannerAd({
    required String adUnitId,
    required AdSize size,
    required void Function(Ad) onAdLoaded,
    required void Function(LoadAdError) onAdFailedToLoad,
  }) {
    if (_isWeb) {
      developer.log('[TEMP] BannerAd: Skipped on web');
      return null;
    }
    
    final bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onAdFailedToLoad(error);
        },
      ),
    );
    
    bannerAd.load();
    return bannerAd;
  }
  
  /// Load an interstitial ad with platform-aware handling
  static void loadInterstitialAd({
    required String adUnitId,
    required void Function(InterstitialAd) onAdLoaded,
    required void Function(LoadAdError) onAdFailedToLoad,
  }) {
    if (_isWeb) {
      developer.log('[TEMP] InterstitialAd: Skipped on web');
      return;
    }
    
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
      ),
    );
  }
  
  /// Dispose a banner ad safely
  static void disposeBannerAd(BannerAd? bannerAd) {
    if (_isWeb) return;
    bannerAd?.dispose();
  }
  
  /// Dispose an interstitial ad safely
  static void disposeInterstitialAd(InterstitialAd? interstitialAd) {
    if (_isWeb) return;
    interstitialAd?.dispose();
  }
}

/// Widget that displays a banner ad or placeholder based on platform
class AdaptiveBannerAd extends StatelessWidget {
  final BannerAd? bannerAd;
  final bool isLoaded;
  final AdSize size;

  const AdaptiveBannerAd({
    super.key,
    this.bannerAd,
    this.isLoaded = false,
    this.size = AdSize.banner,
  });

  @override
  Widget build(BuildContext context) {
    if (_isWeb) {
      // Show placeholder on web for testing
      return Container(
        width: size.width.toDouble(),
        height: size.height.toDouble(),
        color: Colors.grey.shade300,
        child: const Center(
          child: Text(
            '[TEMP] Ad Placeholder',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
      );
    }
    
    if (!isLoaded || bannerAd == null) {
      return const SizedBox.shrink();
    }
    
    return SizedBox(
      width: bannerAd!.size.width.toDouble(),
      height: bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: bannerAd!),
    );
  }
  
  bool get _isWeb => kIsWeb;
}
