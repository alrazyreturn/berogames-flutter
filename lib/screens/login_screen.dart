import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../services/auth_service.dart';
import '../providers/user_provider.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();

  bool _loadingGoogle = false;

  Future<void> _loginWithGoogle() async {
    setState(() => _loadingGoogle = true);
    final provider = context.read<UserProvider>();
    try {
      final result = await _auth.loginWithGoogle();
      await provider.setUser(result['user'], result['token']);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('login.google_failed'.tr());
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1326),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ─── Logo ──────────────────────────────────────────────
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF3D5AF1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🎮', style: TextStyle(fontSize: 48)),
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  'login.welcome'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'login.subtitle'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),

                const SizedBox(height: 56),

                // ─── زر Google ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loadingGoogle ? null : _loginWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1F1F1F),
                      elevation: 3,
                      shadowColor: Colors.black38,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    child: _loadingGoogle
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                              color: Color(0xFF6366F1), strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 28, height: 28,
                                child: CustomPaint(
                                  painter: _GoogleLogoPainter(),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'login.google_btn'.tr(),
                                style: const TextStyle(
                                  color: Color(0xFF1F1F1F),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── شعار Google الحقيقي بالألوان ────────────────────────────────────────────
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.42;

    // الدائرة الكاملة (رمادي فاتح خلفية)
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r, bgPaint);

    // قطاعات الألوان
    final segments = [
      (0.0,         math.pi / 2,  const Color(0xFF4285F4)), // أزرق
      (math.pi / 2, math.pi,      const Color(0xFF34A853)), // أخضر
      (math.pi,     3*math.pi/2,  const Color(0xFFFBBC05)), // أصفر
      (3*math.pi/2, 2*math.pi,    const Color(0xFFEA4335)), // أحمر
    ];

    for (final seg in segments) {
      final paint = Paint()..color = seg.$3;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        seg.$1 - math.pi / 2,
        seg.$2 - seg.$1,
        true,
        paint,
      );
    }

    // الفراغ الداخلي الأبيض
    canvas.drawCircle(Offset(cx, cy), r * 0.6, Paint()..color = Colors.white);

    // شريط أزرق أفقي (الـ G)
    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.18, r * 0.95, r * 0.36),
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}
