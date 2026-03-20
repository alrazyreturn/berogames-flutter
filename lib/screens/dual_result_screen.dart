import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../services/ad_service.dart';
import 'home_screen.dart';
import 'dual_menu_screen.dart';
import 'leaderboard_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';

// ─── Design tokens (Neon-Glass Editorial — matches dual_game_screen) ──────────
const _cBg      = Color(0xFF0B1326);
const _cSurface = Color(0xFF131B2E);
const _cCard    = Color(0xFF171F33);
const _cCyan    = Color(0xFF00FBFB);
const _cNavBg   = Color(0xFF10102B);
const _cPink    = Color(0xFFFF6B8A);

/// شاشة النتيجة النهائية للعب الثنائي
class DualResultScreen extends StatefulWidget {
  final String myName;
  final String opponentName;
  final int    myScore;
  final int    opponentScore;
  final String winner;   // 'host' | 'guest' | 'draw'
  final String myRole;   // 'host' | 'guest'

  const DualResultScreen({
    super.key,
    required this.myName,
    required this.opponentName,
    required this.myScore,
    required this.opponentScore,
    required this.winner,
    required this.myRole,
  });

  @override
  State<DualResultScreen> createState() => _DualResultScreenState();
}

class _DualResultScreenState extends State<DualResultScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confetti;
  late AnimationController _scaleCtrl;
  late Animation<double>   _scaleAnim;

  bool get _iWon  => widget.myRole == widget.winner;
  bool get _isDraw => widget.winner == 'draw';

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 5));
    if (_iWon || _isDraw) _confetti.play();

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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

  @override
  Widget build(BuildContext context) {
    final resultColor = _isDraw
        ? Colors.amber
        : (_iWon ? _cCyan : _cPink);

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
            colors: [_cCyan, _cPink, Colors.amber, Colors.white],
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ─── أيقونة النتيجة ──────────────────────────────────────
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: resultColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: resultColor.withValues(alpha: 0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: resultColor.withValues(alpha: 0.25),
                            blurRadius: 32,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _isDraw ? '🤝' : (_iWon ? '🏆' : '😔'),
                          style: const TextStyle(fontSize: 52),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── عنوان النتيجة ───────────────────────────────────────
                  Text(
                    _isDraw
                        ? 'dual_result.draw'.tr()
                        : (_iWon
                            ? 'dual_result.won'.tr()
                            : 'dual_result.lost'.tr()),
                    style: TextStyle(
                      color:      resultColor,
                      fontSize:   30,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color:      resultColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ─── بطاقة المقارنة ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
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
                    child: Row(
                      children: [
                        // أنا
                        Expanded(
                          child: _PlayerResult(
                            name:     widget.myName,
                            score:    widget.myScore,
                            isWinner: _iWon,
                            color:    _cCyan,
                          ),
                        ),

                        // VS
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'VS',
                                style: TextStyle(
                                  color:      Colors.white.withValues(alpha: 0.2),
                                  fontSize:   16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // الخصم
                        Expanded(
                          child: _PlayerResult(
                            name:     widget.opponentName,
                            score:    widget.opponentScore,
                            isWinner: !_iWon && !_isDraw,
                            color:    _cPink,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

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
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const DualMenuScreen()),
                          ),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _cCyan.withValues(alpha: 0.85),
                                  const Color(0xFF6366F1),
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
                                const Text('⚔️', style: TextStyle(fontSize: 14)),
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

// ─── بطاقة نتيجة لاعب ────────────────────────────────────────────────────────
class _PlayerResult extends StatelessWidget {
  final String name;
  final int    score;
  final bool   isWinner;
  final Color  color;

  const _PlayerResult({
    required this.name,
    required this.score,
    required this.isWinner,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // تاج الفائز
        if (isWinner)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '👑',
              style: const TextStyle(fontSize: 20),
            ),
          )
        else
          const SizedBox(height: 24),

        // اسم اللاعب
        Text(
          name,
          style: TextStyle(
            color:      color,
            fontWeight: FontWeight.bold,
            fontSize:   13,
          ),
          overflow:  TextOverflow.ellipsis,
          maxLines:  1,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 10),

        // النقاط
        Text(
          '$score',
          style: TextStyle(
            color:      Colors.white,
            fontSize:   34,
            fontWeight: FontWeight.bold,
            shadows: isWinner
                ? [Shadow(color: color.withValues(alpha: 0.4), blurRadius: 10)]
                : null,
          ),
        ),

        Text(
          'common.points_unit'.tr(),
          style: TextStyle(
            color:    Colors.white.withValues(alpha: 0.35),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ─── Nav Item ─────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     isActive;
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
                    BoxShadow(color: _cCyan.withValues(alpha: 0.5), blurRadius: 6),
                  ],
                ),
              ),
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color:    color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
