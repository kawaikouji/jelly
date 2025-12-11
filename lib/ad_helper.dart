import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  // スクリーンショット撮影用などで広告を非表示にする場合はfalseにする
  static const bool showAds = true;

  // Android Ad Unit IDs
  static const String _androidBannerId =
      'ca-app-pub-7015028172777494/1084796625';
  static const String _androidInterstitialId =
      'ca-app-pub-7015028172777494/3227636430';

  // iOS Ad Unit IDs
  static const String _iosBannerId = 'ca-app-pub-7015028172777494/7533712959';
  static const String _iosInterstitialId =
      'ca-app-pub-7015028172777494/4033451642';

  // Test Ad Unit IDs
  static const String _testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';

  static String get bannerAdUnitId {
    if (!showAds) return '';
    if (kDebugMode) {
      return _testBannerId;
    }
    if (Platform.isAndroid) {
      return _androidBannerId;
    } else if (Platform.isIOS) {
      return _iosBannerId;
    }
    return '';
  }

  static String get interstitialAdUnitId {
    if (!showAds) return '';
    if (kDebugMode) {
      return _testInterstitialId;
    }
    if (Platform.isAndroid) {
      return _androidInterstitialId;
    } else if (Platform.isIOS) {
      return _iosInterstitialId;
    }
    return '';
  }
}

class AdManager {
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  static BannerAd? createBannerAd() {
    if (!AdHelper.showAds) return null;

    return BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) => debugPrint('Banner ad loaded.'),
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('Banner ad failed to load: $error');
          ad.dispose();
        },
      ),
    );
  }

  static void showInterstitialAd({required VoidCallback onAdClosed}) {
    if (!AdHelper.showAds) {
      onAdClosed();
      return;
    }

    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              onAdClosed();
            },
            onAdFailedToShowFullScreenContent:
                (InterstitialAd ad, AdError error) {
                  ad.dispose();
                  onAdClosed();
                },
          );
          ad.show();
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Interstitial ad failed to load: $error');
          onAdClosed();
        },
      ),
    );
  }
}
