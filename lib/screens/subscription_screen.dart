import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/billing_service.dart';
import '../services/subscription_service.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const _cBg      = Color(0xFF0B1326);
const _cSurface = Color(0xFF131B2E);
const _cCard    = Color(0xFF171F33);
const _cCyan    = Color(0xFF00FBFB);
const _cIndigo  = Color(0xFF6366F1);
const _cGold    = Color(0xFFFFD700);

// ─── Plan Meta (UI info only — price comes from Google Play) ─────────────────
class _PlanMeta {
  final String productId;
  final String titleKey;
  final String periodKey;
  final Color  color;
  final IconData icon;
  final List<String> featureKeys;
  final bool isPopular;

  const _PlanMeta({
    required this.productId,
    required this.titleKey,
    required this.periodKey,
    required this.color,
    required this.icon,
    required this.featureKeys,
    this.isPopular = false,
  });
}

const _plansMeta = [
  _PlanMeta(
    productId: ProductIds.noAds,
    titleKey:  'subscription.no_ads_title',
    periodKey: 'subscription.one_time',
    color: Color(0xFF10B981),
    icon:  Icons.block_rounded,
    featureKeys: [
      'subscription.feature_no_ads',
      'subscription.feature_20_energy',
    ],
  ),
  _PlanMeta(
    productId: ProductIds.monthly,
    titleKey:  'subscription.monthly_title',
    periodKey: 'subscription.per_month',
    color: Color(0xFF6366F1),
    icon:  Icons.calendar_month_rounded,
    featureKeys: [
      'subscription.feature_all_sections',
      'subscription.feature_unlimited_energy',
      'subscription.feature_no_ads',
    ],
    isPopular: true,
  ),
  _PlanMeta(
    productId: ProductIds.yearly,
    titleKey:  'subscription.yearly_title',
    periodKey: 'subscription.per_year',
    color: Color(0xFFF59E0B),
    icon:  Icons.workspace_premium_rounded,
    featureKeys: [
      'subscription.feature_all_sections',
      'subscription.feature_unlimited_energy',
      'subscription.feature_no_ads',
      'subscription.feature_save_44',
    ],
  ),
  _PlanMeta(
    productId: ProductIds.forever,
    titleKey:  'subscription.forever_title',
    periodKey: 'subscription.one_time',
    color: Color(0xFFEC4899),
    icon:  Icons.all_inclusive_rounded,
    featureKeys: [
      'subscription.feature_all_sections',
      'subscription.feature_unlimited_energy',
      'subscription.feature_no_ads',
      'subscription.feature_lifetime',
    ],
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _billing     = BillingService();
  final _subService  = SubscriptionService();

  bool   _storeAvailable  = false;
  bool   _loadingProducts = true;
  bool   _purchasing      = false;
  String? _processingId;

  List<ProductDetails> _products = [];

  @override
  void initState() {
    super.initState();
    _initBilling();
  }

  Future<void> _initBilling() async {
    _billing.onPurchaseResult = _onPurchaseResult;

    final ok = await _billing.initialize();
    if (!mounted) return;

    setState(() {
      _storeAvailable  = ok;
      _loadingProducts = false;
      _products        = _billing.products;
    });
  }

  // ─── Called by BillingService when purchase updates arrive ───────────────
  void _onPurchaseResult(PurchaseResult result) async {
    if (!mounted) return;

    if (result.status == PurchaseResultStatus.pending) {
      // Show "processing…" — wait for final status
      if (!_purchasing) setState(() { _purchasing = true; });
      return;
    }

    setState(() { _purchasing = false; _processingId = null; });

    if (result.status == PurchaseResultStatus.success) {
      await _activateOnServer(result.productId!);
    } else if (result.status == PurchaseResultStatus.cancelled) {
      // silent — user cancelled
    } else if (result.status == PurchaseResultStatus.error) {
      _showError(result.errorMessage ?? 'subscription.error'.tr());
    }
  }

  // ─── Send purchase token to our backend ──────────────────────────────────
  Future<void> _activateOnServer(String productId) async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    final subType = _productIdToSubType(productId);

    final ok = await _subService.purchase(
      token:            token,
      subscriptionType: subType,
      productId:        productId,
    );

    if (!mounted) return;

    if (ok) {
      await context.read<UserProvider>().refreshSubscription();
      _showSuccess(productId);
    } else {
      _showError('subscription.error'.tr());
    }
  }

  String _productIdToSubType(String productId) {
    switch (productId) {
      case ProductIds.noAds:   return 'no_ads';
      case ProductIds.monthly: return 'monthly';
      case ProductIds.yearly:  return 'yearly';
      case ProductIds.forever: return 'forever';
      default: return 'no_ads';
    }
  }

  // ─── Start a purchase ────────────────────────────────────────────────────
  Future<void> _purchase(_PlanMeta meta) async {
    if (_purchasing) return;

    final product = _billing.getProduct(meta.productId);
    if (product == null) {
      _showError('subscription.product_not_found'.tr());
      return;
    }

    setState(() { _purchasing = true; _processingId = meta.productId; });
    await _billing.buy(product);
    // Result comes via _onPurchaseResult callback
  }

  // ─── Restore purchases ───────────────────────────────────────────────────
  Future<void> _restore() async {
    if (_purchasing) return;
    setState(() => _purchasing = true);
    try {
      await _billing.restorePurchases();
      // Result comes via _onPurchaseResult stream
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      final token = context.read<UserProvider>().token;
      if (token != null) {
        final status = await _subService.restore(token);
        if (!mounted) return;
        if (status.hasSubscription) {
          await context.read<UserProvider>().refreshSubscription();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('subscription.restored'.tr()),
            backgroundColor: Colors.green,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('subscription.no_restore'.tr()),
            backgroundColor: Colors.orange,
          ));
        }
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  void _showSuccess(String productId) {
    final meta = _plansMeta.firstWhere(
      (m) => m.productId == productId,
      orElse: () => _plansMeta.first,
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(children: [
          Icon(Icons.check_circle_rounded, color: meta.color, size: 56),
          const SizedBox(height: 8),
          Text('subscription.success_title'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
        ]),
        content: Text('subscription.success_body'.tr(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: meta.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: Text('common.ok'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
    ));
  }

  @override
  void dispose() {
    _billing.onPurchaseResult = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<UserProvider>().subscriptionStatus;

    return Scaffold(
      backgroundColor: _cBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _loadingProducts
                  ? const Center(child: CircularProgressIndicator(color: _cCyan))
                  : !_storeAvailable
                      ? _buildStoreUnavailable()
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            const SizedBox(height: 8),
                            if (sub != null && sub.hasSubscription)
                              _buildActiveCard(sub),
                            const SizedBox(height: 16),
                            ..._plansMeta.map((meta) {
                              final product = _billing.getProduct(meta.productId);
                              return _PlanCard(
                                meta:        meta,
                                product:     product,
                                isActive:    sub?.subscriptionType == _productIdToSubType(meta.productId),
                                isLoading:   _processingId == meta.productId && _purchasing,
                                globalLoading: _purchasing,
                                onTap: sub?.subscriptionType == _productIdToSubType(meta.productId)
                                    ? null
                                    : () => _purchase(meta),
                              );
                            }),
                            const SizedBox(height: 8),
                            _buildRestoreBtn(),
                            const SizedBox(height: 24),
                          ],
                        ),
            ),
            // Purchasing overlay
            if (_purchasing && _processingId == null)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _cCyan),
                      SizedBox(height: 16),
                      Text('جارٍ معالجة الدفع...',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: _cSurface,
        boxShadow: [
          BoxShadow(color: _cCyan.withValues(alpha: 0.08), blurRadius: 20)
        ],
      ),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('subscription.title'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text('subscription.subtitle'.tr(),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _cGold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.workspace_premium_rounded,
              color: _cGold, size: 26),
        ),
      ]),
    );
  }

  Widget _buildActiveCard(SubscriptionStatus sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          _cIndigo.withValues(alpha: 0.3),
          _cCyan.withValues(alpha: 0.1),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cCyan.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.verified_rounded, color: _cCyan, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('subscription.active_label'.tr(),
                style: const TextStyle(color: _cCyan, fontWeight: FontWeight.bold)),
            Text('subscription.${sub.subscriptionType}_title'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.bold)),
            if (sub.expiresAt != null)
              Text('subscription.expires'.tr(
                  args: [sub.expiresAt!.toString().substring(0, 10)]),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildStoreUnavailable() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.store_mall_directory_outlined,
            color: Colors.white38, size: 64),
        const SizedBox(height: 16),
        Text('subscription.store_unavailable'.tr(),
            style: const TextStyle(color: Colors.white54, fontSize: 16),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildRestoreBtn() {
    return Center(
      child: TextButton.icon(
        onPressed: _purchasing ? null : _restore,
        icon: const Icon(Icons.restore_rounded, size: 18, color: _cCyan),
        label: Text('subscription.restore'.tr(),
            style: const TextStyle(color: _cCyan, fontSize: 13)),
      ),
    );
  }
}

// ─── Plan Card ────────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final _PlanMeta        meta;
  final ProductDetails?  product;
  final bool             isActive;
  final bool             isLoading;
  final bool             globalLoading;
  final VoidCallback?    onTap;

  const _PlanCard({
    required this.meta,
    required this.product,
    required this.isActive,
    required this.isLoading,
    required this.globalLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Show price from Google Play, fallback to N/A if product not loaded
    final priceLabel = product?.price ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:   isActive ? meta.color.withValues(alpha: 0.15) : _cCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? meta.color : meta.color.withValues(alpha: 0.25),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header row
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(meta.icon, color: meta.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(meta.titleKey.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text(meta.periodKey.tr(),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12)),
                ]),
              ),
              // Price from Google Play
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(priceLabel,
                    style: TextStyle(color: meta.color, fontSize: 22,
                        fontWeight: FontWeight.bold)),
                if (product == null)
                  Text('subscription.loading_price'.tr(),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 10)),
              ]),
            ]),
            const SizedBox(height: 14),

            // Features
            ...meta.featureKeys.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(Icons.check_circle_rounded, color: meta.color, size: 16),
                const SizedBox(width: 8),
                Text(f.tr(),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13)),
              ]),
            )),
            const SizedBox(height: 14),

            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive
                      ? meta.color.withValues(alpha: 0.4)
                      : meta.color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: (globalLoading || onTap == null) ? null : onTap,
                child: isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        isActive
                            ? 'subscription.active_btn'.tr()
                            : 'subscription.subscribe_btn'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
              ),
            ),
          ]),
        ),

        // Popular badge
        if (meta.isPopular)
          Positioned(
            top: 12, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: meta.color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('subscription.popular'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ),

        // Active checkmark
        if (isActive)
          Positioned(
            top: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: meta.color, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 14),
            ),
          ),
      ]),
    );
  }
}
