import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'subscription_service.dart';

// ─── Product IDs ──────────────────────────────────────────────────────────────
class ProductIds {
  static const noAds   = 'mindcrush_no_ads';    // one-time
  static const monthly = 'mindcrush_monthly';   // subscription
  static const yearly  = 'mindcrush_yearly';    // subscription
  static const forever = 'mindcrush_forever';   // one-time

  static const Set<String> all = {noAds, monthly, yearly, forever};

  // Subscriptions (recurring)
  static const Set<String> subscriptions = {monthly, yearly};

  // One-time purchases
  static const Set<String> oneTime = {noAds, forever};
}

// ─── Purchase Result ──────────────────────────────────────────────────────────
enum PurchaseResultStatus { success, cancelled, error, pending }

class PurchaseResult {
  final PurchaseResultStatus status;
  final String? productId;
  final String? errorMessage;
  const PurchaseResult({required this.status, this.productId, this.errorMessage});
}

// ─── Billing Service ──────────────────────────────────────────────────────────
class BillingService {
  static final BillingService _instance = BillingService._internal();
  factory BillingService() => _instance;
  BillingService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;

  // Products loaded from store
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  // Stream subscription for purchase updates
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  // Callbacks set by UI
  void Function(PurchaseResult)? onPurchaseResult;

  // ─── Initialize ─────────────────────────────────────────────────────────
  Future<bool> initialize() async {
    final available = await _iap.isAvailable();
    if (!available) return false;

    // Start listening to purchases
    _purchaseSubscription?.cancel();
    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (e) => debugPrint('BillingService error: $e'),
    );

    // Load products
    await loadProducts();
    return true;
  }

  // ─── Load Products ───────────────────────────────────────────────────────
  Future<List<ProductDetails>> loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(ProductIds.all);
      if (response.error != null) {
        debugPrint('Product load error: ${response.error}');
      }
      _products = response.productDetails;
      debugPrint('Loaded ${_products.length} products');
      for (final p in _products) {
        debugPrint('  → ${p.id}: ${p.price}');
      }
      return _products;
    } catch (e) {
      debugPrint('loadProducts exception: $e');
      return [];
    }
  }

  // ─── Buy Product ────────────────────────────────────────────────────────
  Future<void> buy(ProductDetails product) async {
    final PurchaseParam param;

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (ProductIds.subscriptions.contains(product.id)) {
        param = GooglePlayPurchaseParam(productDetails: product);
      } else {
        param = PurchaseParam(productDetails: product);
      }
    } else {
      param = PurchaseParam(productDetails: product);
    }

    try {
      if (ProductIds.subscriptions.contains(product.id)) {
        await _iap.buyNonConsumable(purchaseParam: param);
      } else {
        await _iap.buyNonConsumable(purchaseParam: param);
      }
    } catch (e) {
      onPurchaseResult?.call(PurchaseResult(
        status: PurchaseResultStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  // ─── Handle Purchase Updates ─────────────────────────────────────────────
  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        onPurchaseResult?.call(PurchaseResult(
          status: PurchaseResultStatus.pending,
          productId: purchase.productID,
        ));
      } else if (purchase.status == PurchaseStatus.purchased ||
                 purchase.status == PurchaseStatus.restored) {

        // Complete the purchase on the store side
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }

        onPurchaseResult?.call(PurchaseResult(
          status: PurchaseResultStatus.success,
          productId: purchase.productID,
        ));

      } else if (purchase.status == PurchaseStatus.error) {
        onPurchaseResult?.call(PurchaseResult(
          status: PurchaseResultStatus.error,
          productId: purchase.productID,
          errorMessage: purchase.error?.message,
        ));
      } else if (purchase.status == PurchaseStatus.canceled) {
        onPurchaseResult?.call(PurchaseResult(
          status: PurchaseResultStatus.cancelled,
          productId: purchase.productID,
        ));
      }
    }
  }

  // ─── Restore Purchases ───────────────────────────────────────────────────
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  // ─── Get Product by ID ───────────────────────────────────────────────────
  ProductDetails? getProduct(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── Dispose ─────────────────────────────────────────────────────────────
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    onPurchaseResult = null;
  }
}
