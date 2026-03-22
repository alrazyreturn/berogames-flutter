import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../providers/user_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';

// ─── Palette (matches Neon-Glass system) ──────────────────────────────────────
const _cBg      = Color(0xFF080E1C);
const _cCyan    = Color(0xFF00FBFB);
const _cCyanDim = Color(0xFF00C8C8);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<double>   _scale;
  late Animation<double>   _slideUp;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1600),
    );

    _fade    = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeIn));
    _scale   = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack));
    _slideUp = CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut));

    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;
    final loggedIn = context.read<UserProvider>().isLoggedIn;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => loggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _cBg,
      body: Stack(
        children: [
          // ── Background radial glow ──────────────────────────────────────────
          Positioned(
            top:  size.height * 0.18,
            left: size.width  * 0.5 - 180,
            child: Container(
              width:  360,
              height: 360,
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

          // ── Corner brackets ─────────────────────────────────────────────────
          const _CornerBrackets(),

          // ── Main content ────────────────────────────────────────────────────
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brain image
                  ScaleTransition(
                    scale: _scale,
                    child: Container(
                      width:  180,
                      height: 180,
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
                  ),

                  const SizedBox(height: 36),

                  // MIND CRUSH title
                  AnimatedBuilder(
                    animation: _slideUp,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, 30 * (1 - _slideUp.value)),
                      child: child,
                    ),
                    child: Column(
                      children: [
                        // Title
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

                        // Tagline
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

                        const SizedBox(height: 28),

                        // Divider line
                        Container(
                          width:  60,
                          height: 2,
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom branding ─────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left:   0,
            right:  0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: FadeTransition(
                  opacity: _fade,
                  child: Column(
                    children: [
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Corner bracket decorations ───────────────────────────────────────────────
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
