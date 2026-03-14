import 'package:flutter/material.dart';
import '../models/category_model.dart';
import 'home_screen.dart';
import 'categories_screen.dart';

class ThankYouScreen extends StatelessWidget {
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
                width: 130,
                height: 130,
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

              const SizedBox(height: 32),

              // ─── عنوان الشكر ────────────────────────────────────────────
              const Text(
                'أحسنت! 🎉',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'لعبت قسم ${category.nameAr}',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),

              const SizedBox(height: 40),

              // ─── الإحصائيات ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _InfoCard(
                    icon: '⭐',
                    label: 'النقاط',
                    value: '$score',
                    color: const Color(0xFFFFD700),
                  ),
                  _InfoCard(
                    icon: '❓',
                    label: 'الأسئلة',
                    value: '$questionsAnswered',
                    color: Colors.white,
                  ),
                  _InfoCard(
                    icon: '🎯',
                    label: 'أعلى مستوى',
                    value: '$difficultyReached',
                    color: _levelColor(difficultyReached),
                  ),
                ],
              ),

              const SizedBox(height: 52),

              // ─── الأزرار ────────────────────────────────────────────────
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
                        padding:
                            const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'الرئيسية 🏠',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CategoriesScreen()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding:
                            const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'العب مجدداً 🎮',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
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

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
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
