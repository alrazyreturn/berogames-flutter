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

  // ─── Live IDs (غيّرها هنا وقت النشر) ────────────────────────────────────
  // static const String _interstitialAdId = 'ca-app-pub-XXXXX/XXXXX';
  // static const String _rewardedAdId     = 'ca-app-pub-XXXXX/XXXXX';

  InterstitialAd? _interstitialAd;
  RewardedAd?     _rewardedAd;
  int             _gameCount           = 0;
  bool            _isLoadingInterstitial = false; // منع التحميل المكرر

  // ─── تحميل Interstitial (مع guard ضد التحميل المكرر) ─────────────────────
  void loadInterstitial() {
    // لو محمل بالفعل أو في طور التحميل → لا تحمّل مرة ثانية
    if (_interstitialAd != null || _isLoadingInterstitial) return;
    _isLoadingInterstitial = true;

    InterstitialAd.load(
      adUnitId: _interstitialAdId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd       = ad;
          _isLoadingInterstitial = false;
          _interstitialAd!.setImmersiveMode(true);
          debugPrint('✅ Interstitial loaded');
        },
        onAdFailedToLoad: (err) {
          _interstitialAd       = null;
          _isLoadingInterstitial = false;
          debugPrint('❌ Interstitial failed: ${err.message}');
        },
      ),
    );
  }

  // ─── تحميل Rewarded ───────────────────────────────────────────────────────
  void loadRewarded() {
    if (_rewardedAd != null) return;
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
  // تأخير 800ms لضمان اكتمال انتقال الشاشة قبل عرض الإعلان
  void onGameComplete() {
    _gameCount++;
    debugPrint('🎮 Game complete — count: $_gameCount');

    if (_gameCount % 3 == 0) {
      // ✅ تأخير لحين اكتمال انتقال الشاشة (سبب عدم ظهور الإعلان سابقاً)
      Future.delayed(const Duration(milliseconds: 800), _showInterstitial);
    }
    // لا نحمّل هنا — الإعلان محمّل مسبقاً من الـ startup ومن بعد كل عرض
  }

  void _showInterstitial() {
    if (_interstitialAd == null) {
      debugPrint('⚠️ Interstitial not ready, reloading...');
      loadInterstitial();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        debugPrint('📺 Interstitial showing');
      },
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
  // لو فشل التحميل → يُمنح المستخدم المكافأة تلقائياً (تجربة أفضل)
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
      // مش محمل بعد — حمّل واعرض
      debugPrint('⚠️ Rewarded not ready, loading...');
      RewardedAd.load(
        adUnitId: _rewardedAdId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            showRewarded(onRewarded: onRewarded);
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
