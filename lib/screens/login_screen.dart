import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import '../providers/user_provider.dart';
import 'home_screen.dart';

// ─── Palette (matches Neon-Glass / Splash) ────────────────────────────────────
const _cBg      = Color(0xFF080E1C);
const _cCyan    = Color(0xFF00FBFB);
const _cCyanDim = Color(0xFF00C8C8);

// ─── Google G official SVG mark ───────────────────────────────────────────────
const _googleGSvg = '''
<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
  <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';

// ─────────────────────────────────────────────────────────────────────────────
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _cBg,
      body: Stack(
        children: [
          // ── Radial glow background ───────────────────────────────────────
          Positioned(
            top:  size.height * 0.10,
            left: size.width  * 0.5 - 180,
            child: Container(
              width: 360, height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _cCyan.withValues(alpha: 0.07),
                    _cCyan.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ── Corner brackets ──────────────────────────────────────────────
          const _CornerBrackets(),

          // ── Main content ─────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 44),

                // ── Logo (brain image) ───────────────────────────────────
                Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color:      _cCyan.withValues(alpha: 0.18),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/logo_neon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── MIND CRUSH title ─────────────────────────────────────
                Text(
                  'MIND CRUSH',
                  style: TextStyle(
                    color:         _cCyan,
                    fontSize:      42,
                    fontWeight:    FontWeight.w900,
                    letterSpacing: 4,
                    shadows: [
                      Shadow(color: _cCyan.withValues(alpha: 0.9), blurRadius: 18),
                      Shadow(color: _cCyan.withValues(alpha: 0.5), blurRadius: 40),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'splash.tagline'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:         _cCyanDim.withValues(alpha: 0.75),
                    fontSize:      13,
                    fontWeight:    FontWeight.w500,
                    letterSpacing: 1.8,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Cyan divider ─────────────────────────────────────────
                Container(
                  width:  60, height: 2,
                  decoration: BoxDecoration(
                    color:        _cCyan,
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: [
                      BoxShadow(
                        color:     _cCyan.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Google sign-in button ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width:  double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loadingGoogle ? null : _loginWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1F1F1F),
                        elevation:   4,
                        shadowColor: Colors.black45,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      child: _loadingGoogle
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(
                                color: Color(0xFF4285F4), strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SvgPicture.string(
                                  _googleGSvg,
                                  width:  26,
                                  height: 26,
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  'login.google_btn'.tr(),
                                  style: const TextStyle(
                                    color:         Color(0xFF1F1F1F),
                                    fontSize:      16,
                                    fontWeight:    FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // ── Bottom branding ──────────────────────────────────────
                Text(
                  'B E R O G A M E S',
                  style: TextStyle(
                    color:         Colors.white.withValues(alpha: 0.85),
                    fontSize:      18,
                    fontWeight:    FontWeight.bold,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.psychology_rounded,
                        color: _cCyan.withValues(alpha: 0.45), size: 13),
                    const SizedBox(width: 5),
                    Text(
                      'OMNI-BRAIN INTERACTIVE',
                      style: TextStyle(
                        color:         _cCyan.withValues(alpha: 0.45),
                        fontSize:      10,
                        letterSpacing: 2.5,
                        fontWeight:    FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Corner bracket decorations (identical to SplashScreen) ───────────────────
class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(painter: _BracketPainter()),
    );
  }
}

class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = const Color(0xFF00FBFB).withValues(alpha: 0.45)
      ..strokeWidth = 2
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.square;

    const len    = 28.0;
    const margin = 20.0;

    // Top-left
    canvas.drawLine(Offset(margin, margin + len), Offset(margin, margin), paint);
    canvas.drawLine(Offset(margin, margin), Offset(margin + len, margin), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - margin - len, margin),
        Offset(size.width - margin, margin), paint);
    canvas.drawLine(Offset(size.width - margin, margin),
        Offset(size.width - margin, margin + len), paint);
    // Bottom-left
    canvas.drawLine(Offset(margin, size.height - margin - len),
        Offset(margin, size.height - margin), paint);
    canvas.drawLine(Offset(margin, size.height - margin),
        Offset(margin + len, size.height - margin), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - margin - len, size.height - margin),
        Offset(size.width - margin, size.height - margin), paint);
    canvas.drawLine(Offset(size.width - margin, size.height - margin - len),
        Offset(size.width - margin, size.height - margin), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
