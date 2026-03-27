import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/subscription_service.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const _cBg      = Color(0xFF0B1326);
const _cSurface = Color(0xFF131B2E);
const _cCard    = Color(0xFF171F33);
const _cCyan    = Color(0xFF00FBFB);
const _cIndigo  = Color(0xFF6366F1);
const _cGold    = Color(0xFFFFD700);

// ─── Plan Model ───────────────────────────────────────────────────────────────
class _Plan {
  final String id;
  final String titleKey;
  final String priceLabel;
  final String periodKey;
  final Color color;
  final IconData icon;
  final List<String> features;
  final bool isPopular;

  const _Plan({
    required this.id,
    required this.titleKey,
    required this.priceLabel,
    required this.periodKey,
    required this.color,
    required this.icon,
    required this.features,
    this.isPopular = false,
  });
}

const _plans = [
  _Plan(
    id: 'no_ads',
    titleKey: 'subscription.no_ads_title',
    priceLabel: r'$0.99',
    periodKey: 'subscription.one_time',
    color: Color(0xFF10B981),
    icon: Icons.block_rounded,
    features: [
      'subscription.feature_no_ads',
      'subscription.feature_20_energy',
    ],
  ),
  _Plan(
    id: 'monthly',
    titleKey: 'subscription.monthly_title',
    priceLabel: r'$2.99',
    periodKey: 'subscription.per_month',
    color: Color(0xFF6366F1),
    icon: Icons.calendar_month_rounded,
    features: [
      'subscription.feature_all_sections',
      'subscription.feature_unlimited_energy',
      'subscription.feature_no_ads',
    ],
    isPopular: true,
  ),
  _Plan(
    id: 'yearly',
    titleKey: 'subscription.yearly_title',
    priceLabel: r'$19.99',
    periodKey: 'subscription.per_year',
    color: Color(0xFFF59E0B),
    icon: Icons.workspace_premium_rounded,
    features: [
      'subscription.feature_all_sections',
      'subscription.feature_unlimited_energy',
      'subscription.feature_no_ads',
      'subscription.feature_save_44',
    ],
  ),
  _Plan(
    id: 'forever',
    titleKey: 'subscription.forever_title',
    priceLabel: r'$39.99',
    periodKey: 'subscription.one_time',
    color: Color(0xFFEC4899),
    icon: Icons.all_inclusive_rounded,
    features: [
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
  final _service = SubscriptionService();
  bool _loading = false;
  String? _processingId;

  Future<void> _purchase(_Plan plan) async {
    if (_loading) return;
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    setState(() { _loading = true; _processingId = plan.id; });

    try {
      // TODO: Integrate in_app_purchase — for now activate directly via API
      final ok = await _service.purchase(
        token: token,
        subscriptionType: plan.id,
        productId: 'mindcrush_${plan.id}',
      );

      if (!mounted) return;

      if (ok) {
        // Refresh subscription status in provider
        await context.read<UserProvider>().refreshSubscription();
        _showSuccess(plan);
      } else {
        _showError();
      }
    } catch (_) {
      if (mounted) _showError();
    } finally {
      if (mounted) setState(() { _loading = false; _processingId = null; });
    }
  }

  Future<void> _restore() async {
    if (_loading) return;
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    setState(() { _loading = true; });
    try {
      final status = await _service.restore(token);
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
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  void _showSuccess(_Plan plan) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(children: [
          Icon(Icons.check_circle_rounded, color: plan.color, size: 56),
          const SizedBox(height: 8),
          Text('subscription.success_title'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
        ]),
        content: Text('subscription.success_body'.tr(),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: plan.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: Text('common.ok'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('subscription.error'.tr()),
      backgroundColor: Colors.red,
    ));
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
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 8),
                  if (sub != null && sub.hasSubscription) _buildActiveCard(sub),
                  const SizedBox(height: 16),
                  ..._plans.map((p) => _PlanCard(
                    plan: p,
                    isActive: sub?.subscriptionType == p.id,
                    isLoading: _processingId == p.id && _loading,
                    onTap: sub?.subscriptionType == p.id ? null : () => _purchase(p),
                  )),
                  const SizedBox(height: 16),
                  _buildRestoreBtn(),
                  const SizedBox(height: 24),
                ],
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
        boxShadow: [BoxShadow(color: _cCyan.withValues(alpha: 0.08), blurRadius: 20)],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('subscription.title'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('subscription.subtitle'.tr(),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _cGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: _cGold, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCard(SubscriptionStatus sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_cIndigo.withValues(alpha: 0.3), _cCyan.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cCyan.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: _cCyan, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('subscription.active_label'.tr(),
                    style: const TextStyle(color: _cCyan, fontWeight: FontWeight.bold)),
                Text('subscription.${sub.subscriptionType}_title'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                if (sub.expiresAt != null)
                  Text('subscription.expires'.tr(args: [sub.expiresAt!.toString().substring(0, 10)]),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreBtn() {
    return Center(
      child: TextButton.icon(
        onPressed: _loading ? null : _restore,
        icon: const Icon(Icons.restore_rounded, size: 18, color: _cCyan),
        label: Text('subscription.restore'.tr(),
            style: const TextStyle(color: _cCyan, fontSize: 13)),
      ),
    );
  }
}

// ─── Plan Card ────────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final bool isActive;
  final bool isLoading;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.plan,
    required this.isActive,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isActive ? plan.color.withValues(alpha: 0.15) : _cCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? plan.color : plan.color.withValues(alpha: 0.25),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: plan.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(plan.icon, color: plan.color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plan.titleKey.tr(),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(plan.periodKey.tr(),
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(plan.priceLabel,
                            style: TextStyle(
                                color: plan.color, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...plan.features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: plan.color, size: 16),
                      const SizedBox(width: 8),
                      Text(f.tr(),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                    ],
                  ),
                )),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive ? plan.color.withValues(alpha: 0.4) : plan.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: onTap,
                    child: isLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            isActive
                                ? 'subscription.active_btn'.tr()
                                : 'subscription.subscribe_btn'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          ),
          // Popular badge
          if (plan.isPopular)
            Positioned(
              top: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: plan.color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('subscription.popular'.tr(),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          // Active checkmark
          if (isActive)
            Positioned(
              top: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: plan.color, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}
