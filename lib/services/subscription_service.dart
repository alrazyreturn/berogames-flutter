import 'package:dio/dio.dart';
import '../config/api_config.dart';

class SubscriptionStatus {
  final bool hasSubscription;
  final String subscriptionType; // free | no_ads | monthly | yearly | forever
  final bool canPlayPremium;
  final bool unlimitedEnergy;
  final bool noAds;
  final DateTime? expiresAt;

  const SubscriptionStatus({
    required this.hasSubscription,
    required this.subscriptionType,
    required this.canPlayPremium,
    required this.unlimitedEnergy,
    required this.noAds,
    this.expiresAt,
  });

  factory SubscriptionStatus.free() => const SubscriptionStatus(
        hasSubscription: false,
        subscriptionType: 'free',
        canPlayPremium: false,
        unlimitedEnergy: false,
        noAds: false,
      );

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) =>
      SubscriptionStatus(
        hasSubscription: json['has_subscription'] as bool? ?? false,
        subscriptionType: json['subscription_type'] as String? ?? 'free',
        canPlayPremium: json['can_play_premium'] as bool? ?? false,
        unlimitedEnergy: json['unlimited_energy'] as bool? ?? false,
        noAds: json['no_ads'] as bool? ?? false,
        expiresAt: json['expires_at'] != null
            ? DateTime.tryParse(json['expires_at'].toString())
            : null,
      );

  bool get isFree => subscriptionType == 'free';
  bool get isForever => subscriptionType == 'forever';
}

class SubscriptionService {
  final _dio = Dio();

  // ─── جلب حالة الاشتراك ────────────────────────────────────────────────────
  Future<SubscriptionStatus> getStatus(String token) async {
    try {
      final res = await _dio.get(
        '${ApiConfig.baseUrl}${ApiConfig.subscriptionStatus}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return SubscriptionStatus.fromJson(Map<String, dynamic>.from(res.data));
    } catch (_) {
      return SubscriptionStatus.free();
    }
  }

  // ─── تفعيل اشتراك بعد الدفع ───────────────────────────────────────────────
  Future<bool> purchase({
    required String token,
    required String subscriptionType,
    String? purchaseToken,
    String? productId,
  }) async {
    try {
      final res = await _dio.post(
        '${ApiConfig.baseUrl}${ApiConfig.subscriptionPurchase}',
        data: {
          'subscription_type': subscriptionType,
          'purchase_token': purchaseToken,
          'product_id': productId,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // ─── استعادة الاشتراك ─────────────────────────────────────────────────────
  Future<SubscriptionStatus> restore(String token) async {
    try {
      final res = await _dio.post(
        '${ApiConfig.baseUrl}${ApiConfig.subscriptionRestore}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (res.data['restored'] == true) {
        return SubscriptionStatus.fromJson(Map<String, dynamic>.from(res.data));
      }
      return SubscriptionStatus.free();
    } catch (_) {
      return SubscriptionStatus.free();
    }
  }
}
