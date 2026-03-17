import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../services/ad_service.dart';
import '../services/energy_service.dart';
import '../providers/user_provider.dart';
import 'home_screen.dart';
import 'categories_screen.dart';

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

class _ResultScreenState extends State<ResultScreen> {
  late ConfettiController _confetti;
  final _energyService = EnergyService();

  // أقصى نقاط ممكنة لو كل إجابة صح بصعوبة 10
  int get _maxPossible => widget.totalQuestions * 100;
  double get _percentage =>
      _maxPossible > 0 ? widget.score / _maxPossible : 0;
  bool get _isPassed => widget.score > 0;

  String get _grade {
    if (_percentage >= 0.8) return 'ممتاز 🏆';
    if (_percentage >= 0.6) return 'جيد جداً ⭐';
    if (_percentage >= 0.4) return 'جيد 👍';
    return 'حاول مجدداً 💪';
  }

  Color get _gradeColor {
    if (_percentage >= 0.8) return const Color(0xFFFFD700);
    if (_percentage >= 0.6) return const Color(0xFF6C63FF);
    if (_percentage >= 0.4) return Colors.greenAccent;
    return Colors.orangeAccent;
  }

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    if (_isPassed) _confetti.play();
    // ─── Interstitial بعد كل 3 مباريات (بعد اكتمال بناء الشاشة) ─────────
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService().onGameComplete();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
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
        // استهلاك الطاقة ثم اللعب
        final consumeRes = await _energyService.consumeEnergy(token);
        if (!mounted) return;
        if (consumeRes['can_play'] == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CategoriesScreen()),
          );
        }
      } else {
        // الطاقة = 0 → اعرض dialog
        _showNoEnergyDialog(token);
      }
    } catch (_) {
      // خطأ في الشبكة → اسمح باللعب
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
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
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
                    // بعد الشحن، العب مجدداً
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
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          // ─── Confetti ────────────────────────────────────────────────────
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            colors: const [
              Color(0xFF6C63FF),
              Color(0xFFFF6584),
              Color(0xFFFFD700),
              Colors.white,
            ],
          ),

          // ─── المحتوى ──────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  // ─── التقدير ──────────────────────────────────────────────
                  Text(
                    _grade,
                    style: TextStyle(
                      color: _gradeColor,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    widget.category.nameAr,
                    style: const TextStyle(color: Colors.white54, fontSize: 15),
                  ),

                  const SizedBox(height: 32),

                  // ─── دائرة النقاط ─────────────────────────────────────────
                  Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _gradeColor, width: 5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${widget.score}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 46,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'نقطة',
                          style: TextStyle(
                            color: _gradeColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ─── إحصائيات ─────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatCard(
                        icon: '❓',
                        label: 'الأسئلة',
                        value: '${widget.totalQuestions}',
                      ),
                      _StatCard(
                        icon: '🎯',
                        label: 'أعلى مستوى',
                        value: '${widget.difficultyReached}',
                        color: _difficultyColor(widget.difficultyReached),
                      ),
                      _StatCard(
                        icon: '📈',
                        label: 'النسبة',
                        value: '${(_percentage * 100).toStringAsFixed(0)}%',
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // ─── الأزرار ──────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HomeScreen()),
                            (_) => false,
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
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
                          // ✅ check الطاقة قبل اللعب مجدداً
                          onPressed: () => _checkEnergyAndPlayAgain(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'العب مجدداً',
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

  Color _difficultyColor(int d) {
    if (d <= 3) return Colors.greenAccent;
    if (d <= 6) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}

// ─── بطاقة إحصائية صغيرة ─────────────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
