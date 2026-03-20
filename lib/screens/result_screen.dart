import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../models/category_model.dart';
import '../services/ad_service.dart';
import '../services/energy_service.dart';
import '../providers/user_provider.dart';
import 'home_screen.dart';
import 'categories_screen.dart';
import 'leaderboard_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';

// ─── Design tokens (Neon-Glass Editorial) ────────────────────────────────────
const _cBg      = Color(0xFF0B1326);
const _cSurface = Color(0xFF131B2E);
const _cCard    = Color(0xFF171F33);
const _cCyan    = Color(0xFF00FBFB);
const _cIndigo  = Color(0xFF6366F1);
const _cNavBg   = Color(0xFF10102B);

class ResultScreen extends StatefulWidget {
  final int           score;
  final int           totalQuestions;
  final int           difficultyReached;
  final CategoryModel category;

  const ResultScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.difficultyReached,
    required this.category,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confetti;
  late AnimationController _scaleCtrl;
  late Animation<double>   _scaleAnim;
  final _energyService = EnergyService();

  int get _maxPossible => widget.totalQuestions * 100;
  double get _percentage =>
      _maxPossible > 0 ? widget.score / _maxPossible : 0;
  bool get _isPassed => widget.score > 0;

  String get _gradeLabel {
    if (_percentage >= 0.8) return 'result.grade_excellent'.tr();
    if (_percentage >= 0.6) return 'result.grade_very_good'.tr();
    if (_percentage >= 0.4) return 'result.grade_good'.tr();
    return 'result.grade_try_again'.tr();
  }

  String get _gradeEmoji {
    if (_percentage >= 0.8) return '🏆';
    if (_percentage >= 0.6) return '⭐';
    if (_percentage >= 0.4) return '👍';
    return '💪';
  }

  Color get _gradeColor {
    if (_percentage >= 0.8) return const Color(0xFFFFD700);
    if (_percentage >= 0.6) return _cCyan;
    if (_percentage >= 0.4) return Colors.greenAccent;
    return Colors.orangeAccent;
  }

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
    if (_isPassed) _confetti.play();

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _scaleCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService().onGameComplete();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _scaleCtrl.dispose();
    super.dispose();
  }

  // ─── التحقق من الطاقة قبل "العب مجدداً" ──────────────────────────────────
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
        backgroundColor: _cCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '⚡ طاقتك انتهت!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                  child: Icon(Icons.favorite_border, color: Colors.white24, size: 28),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'شاهد إعلاناً للحصول على ❤️ طاقة إضافية',
              style: TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cIndigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('شاهد إعلان +❤️'),
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
      backgroundColor: _cBg,
      bottomNavigationBar: _buildBottomNav(),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          // ─── Confetti ────────────────────────────────────────────────────
          ConfettiWidget(
            confettiController:  _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles:   30,
            colors: [_cCyan, _cIndigo, Colors.amber, Colors.white],
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: Column(
                children: [
                  // ─── أيقونة + تقدير ──────────────────────────────────────
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _gradeColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: _gradeColor.withValues(alpha: 0.45),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:      _gradeColor.withValues(alpha: 0.25),
                            blurRadius: 32,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _gradeEmoji,
                          style: const TextStyle(fontSize: 54),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ─── التقدير ─────────────────────────────────────────────
                  Text(
                    _gradeLabel,
                    style: TextStyle(
                      color:      _gradeColor,
                      fontSize:   26,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color:      _gradeColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    widget.category.localizedName(context.locale.languageCode),
                    style: TextStyle(
                      color:    Colors.white.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── بطاقة النقاط الرئيسية ────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 28, horizontal: 24),
                    decoration: BoxDecoration(
                      color:        _cCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:      Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset:     const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${widget.score}',
                          style: TextStyle(
                            color:      Colors.white,
                            fontSize:   60,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color:      _gradeColor.withValues(alpha: 0.3),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'common.points_unit'.tr(),
                          style: TextStyle(
                            color:    _gradeColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // شريط النسبة
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value:           _percentage.clamp(0.0, 1.0),
                            backgroundColor: Colors.white.withValues(alpha: 0.07),
                            valueColor:      AlwaysStoppedAnimation(_gradeColor),
                            minHeight:       6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_percentage * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color:    _gradeColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── إحصائيات ─────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon:  '❓',
                          label: 'result.stat_questions'.tr(),
                          value: '${widget.totalQuestions}',
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon:  '🎯',
                          label: 'result.stat_level'.tr(),
                          value: '${widget.difficultyReached}',
                          color: _difficultyColor(widget.difficultyReached),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon:  '📈',
                          label: 'result.stat_percent'.tr(),
                          value: '${(_percentage * 100).toStringAsFixed(0)}%',
                          color: _gradeColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ─── الأزرار ────────────────────────────────────────────
                  Row(
                    children: [
                      // زر الرئيسية
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HomeScreen()),
                            (_) => false,
                          ),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              color: _cSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              'dual_result.home_btn'.tr(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color:      Colors.white70,
                                fontSize:   15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // زر العب مجدداً (gradient)
                      Expanded(
                        child: GestureDetector(
                          onTap: _checkEnergyAndPlayAgain,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _cCyan.withValues(alpha: 0.85),
                                  _cIndigo,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:      _cCyan.withValues(alpha: 0.2),
                                  blurRadius: 14,
                                  offset:     const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🎮', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  'dual_result.play_again'.tr(),
                                  style: const TextStyle(
                                    color:      Colors.white,
                                    fontSize:   15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _difficultyColor(int d) {
    if (d <= 3) return Colors.greenAccent;
    if (d <= 6) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  // ─── Bottom Navigation ────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _cNavBg,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset:     const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon:     Icons.home_rounded,
                label:    'home.nav_home'.tr(),
                isActive: false,
                onTap:    () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (_) => false),
              ),
              _NavItem(
                icon:     Icons.leaderboard_rounded,
                label:    'home.nav_ranking'.tr(),
                isActive: false,
                onTap:    () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen())),
              ),
              _NavItem(
                icon:     Icons.people_rounded,
                label:    'home.nav_friends'.tr(),
                isActive: false,
                onTap:    () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const FriendsScreen())),
              ),
              _NavItem(
                icon:     Icons.person_rounded,
                label:    'home.nav_profile'.tr(),
                isActive: false,
                onTap:    () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProfileScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── بطاقة إحصائية ───────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color  color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color:        _cCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color:      color,
              fontSize:   18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color:    Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Nav Item ─────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final bool         isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _cCyan : Colors.white38;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Container(
                width: 28, height: 3,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: _cCyan,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color:      _cCyan.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color:      color,
                fontSize:   10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
