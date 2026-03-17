import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class AdService {
  // ─── Singleton ────────────────────────────────────────────────────────────
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // ─── Ad Unit IDs ──────────────────────────────────────────────────────────
  // 🔴 Test IDs — استبدلها بالـ Live IDs قبل النشر
  static const String _interstitialAdId =
      'ca-app-pub-3940256099942544/1033173712'; // Test Interstitial
  static const String _rewardedAdId =
      'ca-app-pub-3940256099942544/5224354917'; // Test Rewarded

  // ─── Live IDs (ستُفعَّل عند التبديل) ─────────────────────────────────────
  // static const String _interstitialAdId = 'ca-app-pub-XXXXX/XXXXX';
  // static const String _rewardedAdId     = 'ca-app-pub-XXXXX/XXXXX';

  InterstitialAd? _interstitialAd;
  RewardedAd?     _rewardedAd;
  int             _gameCount = 0; // عداد المباريات

  // ─── تحميل مسبق للإعلانات ────────────────────────────────────────────────
  void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialAdId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.setImmersiveMode(true);
          debugPrint('✅ Interstitial loaded');
        },
        onAdFailedToLoad: (err) {
          _interstitialAd = null;
          debugPrint('❌ Interstitial failed: ${err.message}');
        },
      ),
    );
  }

  void loadRewarded() {
    RewardedAd.load(
      adUnitId: _rewardedAdId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          debugPrint('✅ Rewarded loaded');
        },
        onAdFailedToLoad: (err) {
          _rewardedAd = null;
          debugPrint('❌ Rewarded failed: ${err.message}');
        },
      ),
    );
  }

  // ─── عند انتهاء كل مبارة (فردي أو زوجي) ─────────────────────────────────
  // يُظهر Interstitial بعد كل 3 مباريات
  void onGameComplete() {
    _gameCount++;
    debugPrint('🎮 Game complete — count: $_gameCount');
    if (_gameCount % 3 == 0) {
      _showInterstitial();
    } else {
      // preload للمرة القادمة
      loadInterstitial();
    }
  }

  void _showInterstitial() {
    if (_interstitialAd == null) {
      debugPrint('⚠️ Interstitial not ready, reloading...');
      loadInterstitial();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitial(); // preload التالي فوراً
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitial();
        debugPrint('❌ Interstitial failed to show: ${err.message}');
      },
    );
    _interstitialAd!.show();
    _interstitialAd = null;
  }

  // ─── إعلان المكافأة (Rewarded) ────────────────────────────────────────────
  // onRewarded: يُستدعى بعد مشاهدة الإعلان كاملاً
  // لو فشل التحميل → يُمنح المستخدم المكافأة تلقائياً (تجربة جيدة)
  void showRewarded({required VoidCallback onRewarded}) {
    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          loadRewarded(); // preload التالي
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _rewardedAd = null;
          onRewarded(); // منح المكافأة عند فشل العرض
          loadRewarded();
          debugPrint('❌ Rewarded failed to show: ${err.message}');
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (_, reward) {
          debugPrint('🏆 Reward earned: ${reward.amount} ${reward.type}');
          onRewarded();
        },
      );
      _rewardedAd = null;
    } else {
      // مش محمل — حمّل واعرض
      debugPrint('⚠️ Rewarded not ready, loading...');
      RewardedAd.load(
        adUnitId: _rewardedAdId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            showRewarded(onRewarded: onRewarded); // الآن اعرضه
          },
          onAdFailedToLoad: (_) {
            debugPrint('❌ Rewarded failed to load, giving reward anyway');
            onRewarded(); // فشل التحميل → امنح المكافأة مباشرة
          },
        ),
      );
    }
  }
}
