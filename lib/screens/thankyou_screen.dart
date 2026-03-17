import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../models/category_model.dart';
import '../providers/user_provider.dart';
import '../services/energy_service.dart';
import '../services/game_service.dart';
import '../services/ad_service.dart';
import 'home_screen.dart';
import 'categories_screen.dart';

class ThankYouScreen extends StatefulWidget {
  final int           score;
  final int           questionsAnswered;
  final int           difficultyReached;
  final CategoryModel category;

  const ThankYouScreen({
    super.key,
    required this.score,
    required this.questionsAnswered,
    required this.difficultyReached,
    required this.category,
  });

  @override
  State<ThankYouScreen> createState() => _ThankYouScreenState();
}

class _ThankYouScreenState extends State<ThankYouScreen> {
  final _energyService = EnergyService();
  final _gameService   = GameService();

  late int _displayScore;   // النقاط المعروضة (تتغير بعد المضاعفة)
  bool     _isDoubled     = false;  // هل تم المضاعفة؟
  bool     _isDoubling    = false;  // loading أثناء المضاعفة

  @override
  void initState() {
    super.initState();
    _displayScore = widget.score;
  }

  // ─── مضاعفة النقاط بعد Rewarded Ad ──────────────────────────────────────
  void _onDoublePoints() {
    if (_isDoubled || _isDoubling) return;

    AdService().showRewarded(
      onRewarded: () async {
        final token = context.read<UserProvider>().token;
        if (token == null) return;

        setState(() => _isDoubling = true);
        try {
          final newTotal = await _gameService.addBonusScore(
            bonusScore: widget.score, // يضيف نفس النقاط → مضاعفة
            token:      token,
          );
          if (!mounted) return;
          // تحديث الـ Provider بالنقاط الجديدة
          await context.read<UserProvider>().updateTotalScore(newTotal);
          setState(() {
            _displayScore = widget.score * 2;
            _isDoubled    = true;
            _isDoubling   = false;
          });
        } catch (_) {
          if (mounted) setState(() => _isDoubling = false);
        }
      },
    );
  }

  // ─── check الطاقة قبل "العب مجدداً" ──────────────────────────────────────
  Future<void> _checkEnergyAndPlayAgain() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    try {
      final energyRes = await _energyService.getEnergy(token);
      final energy    = energyRes['energy'] as int? ?? 0;
      if (!mounted) return;

      if (energy > 0) {
        final consumeRes = await _energyService.consumeEnergy(token);
        if (!mounted) return;
        if (consumeRes['can_play'] == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CategoriesScreen()),
          );
        }
      } else {
        _showNoEnergyDialog(token);
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CategoriesScreen()),
      );
    }
  }

  // ─── dialog انتهاء الطاقة ────────────────────────────────────────────────
  void _showNoEnergyDialog(String token) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E3F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'energy.empty_title'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(Icons.favorite_border,
                      color: Colors.white24, size: 28),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'energy.recharge_hint'.tr(),
              style: const TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'energy.wait_midnight'.tr(),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr(), style: const TextStyle(color: Colors.white38)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: Text('energy.watch_ad'.tr()),
            onPressed: () {
              Navigator.pop(context);
              AdService().showRewarded(
                onRewarded: () async {
                  try {
                    await _energyService.rechargeEnergy(token);
                    if (!mounted) return;
                    await _checkEnergyAndPlayAgain();
                  } catch (_) {}
                },
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // ─── أيقونة ────────────────────────────────────────────────
              Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF3D5AF1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.45),
                      blurRadius: 35,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🏆', style: TextStyle(fontSize: 60)),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'result.title'.tr(),
                style: const TextStyle(
                  color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'result.played'.tr(namedArgs: {'category': widget.category.nameAr}),
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),

              const SizedBox(height: 30),

              // ─── الإحصائيات ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _InfoCard(
                    icon: '⭐',
                    label: 'result.points_label'.tr(),
                    value: '$_displayScore',
                    color: _isDoubled
                        ? const Color(0xFFFFD700)
                        : Colors.white,
                    // تأثير توهج لو النقاط اتضاعفت
                    glow: _isDoubled,
                  ),
                  _InfoCard(
                    icon: '❓',
                    label: 'result.questions_label'.tr(),
                    value: '${widget.questionsAnswered}',
                    color: Colors.white,
                  ),
                  _InfoCard(
                    icon: '🎯',
                    label: 'result.level_label'.tr(),
                    value: '${widget.difficultyReached}',
                    color: _levelColor(widget.difficultyReached),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ─── زر مضاعفة النقاط (يختفي بعد الاستخدام) ─────────────────
              if (widget.score > 0)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _isDoubled
                      // ✅ حالة بعد المضاعفة
                      ? Container(
                          key: const ValueKey('doubled'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'result.doubled'.tr(),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      // 🎁 زر المضاعفة
                      : GestureDetector(
                          key: const ValueKey('double_btn'),
                          onTap: _isDoubling ? null : _onDoublePoints,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFD700),
                                  Color(0xFFFFA500),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: _isDoubling
                                ? const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      const Text('🎁',
                                          style: TextStyle(fontSize: 20)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'result.double_btn'.tr(namedArgs: {'score': '${widget.score * 2}'}),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                ),

              const SizedBox(height: 24),

              // ─── الأزرار ────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (_) => false,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('result.home_btn'.tr(),
                          style: const TextStyle(color: Colors.white, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _checkEnergyAndPlayAgain,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('result.play_again'.tr(),
                          style: const TextStyle(color: Colors.white, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _levelColor(int d) {
    if (d <= 3) return Colors.greenAccent;
    if (d <= 6) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}

// ─── بطاقة إحصائية ────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color  color;
  final bool   glow;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: glow
              ? const Color(0xFFFFD700).withValues(alpha: 0.6)
              : Colors.white12,
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                  blurRadius: 12,
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
