import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  DateTime? _lastInterstitialTime;

  static const String _lastAdTimeKey = 'last_interstitial_time';

  // Production IDs
  final String _androidInterstitialId =
      'ca-app-pub-4722357587218735/8525006559';
  final String _iosInterstitialId = ''; // Set if releasing on iOS

  // Frequency Cap: 5 minutes
  static const Duration _interstitialCooldown = Duration(minutes: 5);

  Future<void> init() async {
    await MobileAds.instance.initialize();

    // Load last ad time from storage
    final prefs = await SharedPreferences.getInstance();
    final lastTimeMs = prefs.getInt(_lastAdTimeKey);
    if (lastTimeMs != null) {
      _lastInterstitialTime = DateTime.fromMillisecondsSinceEpoch(lastTimeMs);
    }

    _loadInterstitialAd();
  }

  String get interstitialAdUnitId {
    if (Platform.isAndroid) return _androidInterstitialId;
    if (Platform.isIOS) return _iosInterstitialId;
    throw UnsupportedError('Unsupported platform');
  }

  void _loadInterstitialAd() {
    if (_isInterstitialLoading || _interstitialAd != null) return;

    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          // debugPrint('Interstitial Ad loaded');
          // ...
          // debugPrint('Interstitial Ad failed to load: $error');
          // ...
          // debugPrint('Ad skipped: Cooldown active');
          // ...
          // debugPrint('Ad skipped: Not loaded yet');
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  ad.dispose();
                  _interstitialAd = null;
                  _loadInterstitialAd(); // Preload next one
                },
                onAdFailedToShowFullScreenContent: (ad, error) {
                  ad.dispose();
                  _interstitialAd = null;
                  _loadInterstitialAd();
                },
              );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial Ad failed to load: $error');
          _isInterstitialLoading = false;
          _interstitialAd = null;
          // Retry after delay? For now, we just wait for next trigger attempt
        },
      ),
    );
  }

  /// Show interstitial ad if available and cooldown passed
  Future<void> showInterstitialAd() async {
    final now = DateTime.now();

    // Check cooldown
    if (_lastInterstitialTime != null &&
        now.difference(_lastInterstitialTime!) < _interstitialCooldown) {
      debugPrint('Ad skipped: Cooldown active');
      return;
    }

    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _lastInterstitialTime = now;

      // Persist to storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastAdTimeKey, now.millisecondsSinceEpoch);
    } else {
      debugPrint('Ad skipped: Not loaded yet');
      _loadInterstitialAd(); // Try loading again
    }
  }

  /// Get Native Ad Unit ID
  static String get nativeAdUnitId {
    if (kIsWeb) return ''; // Ads not supported on web yet
    if (Platform.isAndroid) {
      // UNIQUE Native Ad Unit ID (Must differ from Interstitial)
      // If you don't have a native ID yet, use: 'ca-app-pub-3940256099942544/2247696110' (Test ID)
      return 'ca-app-pub-4722357587218735/6584061825';
    }
    if (Platform.isIOS) {
      return ''; // Set if releasing on iOS
    }
    throw UnsupportedError('Unsupported platform');
  }
}
