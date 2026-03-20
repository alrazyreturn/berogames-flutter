import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../models/category_model.dart';
import '../providers/user_provider.dart';
import '../services/energy_service.dart';
import '../services/game_service.dart';
import '../services/ad_service.dart';
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
const _cOrange  = Color(0xFFFF9500);

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

class _ThankYouScreenState extends State<ThankYouScreen>
    with SingleTickerProviderStateMixin {
  final _energyService = EnergyService();
  final _gameService   = GameService();

  late ConfettiController _confetti;
  late AnimationController _scaleCtrl;
  late Animation<double>   _scaleAnim;

  late int _displayScore;
  bool     _isDoubled  = false;
  bool     _isDoubling = false;

  bool get _isPassed => widget.score > 0;

  String get _gradeLabel {
    if (!_isPassed)            return 'result.grade_try_again'.tr();
    if (widget.difficultyReached >= 8) return 'result.grade_excellent'.tr();
    if (widget.difficultyReached >= 5) return 'result.grade_very_good'.tr();
    return 'result.grade_good'.tr();
  }

  String get _gradeEmoji {
    if (!_isPassed)                    return '💪';
    if (widget.difficultyReached >= 8) return '🏆';
    if (widget.difficultyReached >= 5) return '⭐';
    return '👍';
  }

  Color get _gradeColor {
    if (!_isPassed)                    return Colors.orangeAccent;
    if (widget.difficultyReached >= 8) return const Color(0xFFFFD700);
    if (widget.difficultyReached >= 5) return _cCyan;
    return Colors.greenAccent;
  }

  @override
  void initState() {
    super.initState();
    _displayScore = widget.score;

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
            bonusScore: widget.score,
            token:      token,
          );
          if (!mounted) return;
          await context.read<UserProvider>().updateTotalScore(newTotal);
          setState(() {
            _displayScore = widget.score * 2;
            _isDoubled    = true;
            _isDoubling   = false;
          });
          _confetti.play();
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
        backgroundColor: _cCard,
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
            child: Text('common.cancel'.tr(),
                style: const TextStyle(color: Colors.white38)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cIndigo,
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
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: _cBg,
      bottomNavigationBar: _buildBottomNav(),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          // ─── Confetti ──────────────────────────────────────────────────
          ConfettiWidget(
            confettiController:  _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles:   30,
            colors: [_cCyan, _cIndigo, Colors.amber, Colors.white],
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ─── AppBar row ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: _cCard,
                          backgroundImage: user?.avatar != null
                              ? NetworkImage(user!.avatar!) as ImageProvider
                              : null,
                          child: user?.avatar == null
                              ? Text(
                                  user?.name.isNotEmpty == true
                                      ? user!.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: _cCyan, fontSize: 16),
                                )
                              : null,
                        ),
                        const Expanded(
                          child: Text(
                            'Mind Crush',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:         _cCyan,
                              fontSize:      20,
                              fontWeight:    FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Icon(Icons.menu_rounded,
                            color: Colors.white54, size: 26),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ─── Trophy / emoji with glow ────────────────────────
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:        _gradeColor.withValues(alpha: 0.55),
                            blurRadius:   70,
                            spreadRadius: 18,
                          ),
                          BoxShadow(
                            color:        _gradeColor.withValues(alpha: 0.25),
                            blurRadius:   120,
                            spreadRadius: 30,
                          ),
                        ],
                      ),
                      child: Text(
                        _gradeEmoji,
                        style: const TextStyle(fontSize: 90),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── عنوان النتيجة ───────────────────────────────────
                  Text(
                    _isDoubled
                        ? 'result.doubled'.tr()
                        : _gradeLabel,
                    style: TextStyle(
                      color:         _cCyan,
                      fontSize:      36,
                      fontWeight:    FontWeight.bold,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          color:      _cCyan.withValues(alpha: 0.35),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ─── اسم القسم ───────────────────────────────────────
                  Text(
                    'result.played'.tr(namedArgs: {
                      'category': widget.category
                          .localizedName(context.locale.languageCode),
                    }),
                    style: TextStyle(
                      color:    Colors.white.withValues(alpha: 0.45),
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── بطاقات الإحصائيات ───────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon:      Icons.track_changes_rounded,
                          iconColor: _cIndigo,
                          value:     '${widget.difficultyReached}',
                          label:     'result.stat_level'.tr(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon:      Icons.quiz_rounded,
                          iconColor: Colors.white54,
                          value:     '${widget.questionsAnswered}',
                          label:     'result.stat_questions'.tr(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          icon:      Icons.star_rounded,
                          iconColor: _isDoubled ? Colors.amber : _cCyan,
                          value:     '$_displayScore',
                          label:     'common.points_unit'.tr(),
                          glow:      _isDoubled,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ─── زر مضاعفة النقاط ────────────────────────────────
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
                                    color:
                                        Colors.amber.withValues(alpha: 0.4)),
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
                                      color:      Colors.amber,
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
                                padding: const EdgeInsets.symmetric(
                                    vertical: 18, horizontal: 20),
                                decoration: BoxDecoration(
                                  color: _cOrange,
                                  borderRadius: BorderRadius.circular(48),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _cOrange.withValues(alpha: 0.40),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: _isDoubling
                                    ? const Center(
                                        child: SizedBox(
                                          width: 22, height: 22,
                                          child: CircularProgressIndicator(
                                            color:       Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 32, height: 32,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white
                                                  .withValues(alpha: 0.2),
                                            ),
                                            child: const Icon(
                                              Icons.play_arrow_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'result.double_btn'.tr(
                                                      namedArgs: {
                                                        'score':
                                                            '${widget.score * 2}',
                                                      }),
                                                  style: const TextStyle(
                                                    color:      Colors.white,
                                                    fontSize:   16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'result.watch_ad'.tr(),
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.75),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.card_giftcard_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                    ),

                  const SizedBox(height: 16),

                  // ─── الأزرار السفلية ─────────────────────────────────
                  Row(
                    children: [
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
                                const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _cSurface,
                              borderRadius: BorderRadius.circular(48),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              'result.home_btn'.tr(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color:      Colors.white,
                                fontSize:   16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: GestureDetector(
                          onTap: _checkEnergyAndPlayAgain,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _cIndigo,
                              borderRadius: BorderRadius.circular(48),
                              boxShadow: [
                                BoxShadow(
                                  color: _cIndigo.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              'result.play_again'.tr(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color:      Colors.white,
                                fontSize:   16,
                                fontWeight: FontWeight.bold,
                              ),
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
                    MaterialPageRoute(
                        builder: (_) => const FriendsScreen())),
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
  final IconData icon;
  final Color    iconColor;
  final String   value;
  final String   label;
  final bool     glow;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      decoration: BoxDecoration(
        color:        _cCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: glow
              ? Colors.amber.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.06),
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color:      Colors.amber.withValues(alpha: 0.2),
                  blurRadius: 14,
                ),
              ]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color:    Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
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
