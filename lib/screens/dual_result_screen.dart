import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'home_screen.dart';
import 'dual_menu_screen.dart';

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

class _DualResultScreenState extends State<DualResultScreen> {
  late ConfettiController _confetti;

  bool get _iWon => (widget.myRole == widget.winner);
  bool get _isDraw => widget.winner == 'draw';

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
    if (_iWon || _isDraw) _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          // ─── Confetti ──────────────────────────────────────────────────
          ConfettiWidget(
            confettiController:  _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles:   30,
            colors: const [
              Color(0xFF6C63FF), Color(0xFFFF6584),
              Color(0xFFFFD700), Colors.white,
            ],
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ─── رمز النتيجة ────────────────────────────────────────
                  Text(
                    _isDraw ? '🤝' : (_iWon ? '🏆' : '😔'),
                    style: const TextStyle(fontSize: 80),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isDraw
                        ? 'تعادل!'
                        : (_iWon ? 'فزت! 🎉' : 'خسرت!'),
                    style: TextStyle(
                      color: _isDraw
                          ? Colors.amber
                          : (_iWon ? Colors.greenAccent : Colors.redAccent),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ─── بطاقة المقارنة ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color:        Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                      border:       Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        // أنا
                        Expanded(child: _PlayerResult(
                          name:    widget.myName,
                          score:   widget.myScore,
                          isWinner: _iWon,
                          color:   const Color(0xFF6C63FF),
                        )),

                        // VS
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white38, fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // الخصم
                        Expanded(child: _PlayerResult(
                          name:    widget.opponentName,
                          score:   widget.opponentScore,
                          isWinner: !_iWon && !_isDraw,
                          color:   const Color(0xFFFF6584),
                        )),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ─── الأزرار ──────────────────────────────────────────────
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text(
                            'الرئيسية',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const DualMenuScreen()),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text(
                            'العب مجدداً ⚔️',
                            style: TextStyle(color: Colors.white),
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
      children: [
        if (isWinner)
          const Text('👑', style: TextStyle(fontSize: 22)),
        Text(
          name,
          style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '$score',
          style: const TextStyle(
            color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold,
          ),
        ),
        const Text('نقطة', style: TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }
}
