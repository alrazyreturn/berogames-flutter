import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../models/room_model.dart';
import '../providers/user_provider.dart';
import '../services/socket_service.dart';
import 'dual_game_screen.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const _cBg      = Color(0xFF0B1326);
const _cSurface = Color(0xFF131B2E);
const _cCard    = Color(0xFF171F33);
const _cCyan    = Color(0xFF00FBFB);
const _cIndigo  = Color(0xFF6366F1);

/// شاشة البحث التلقائي عن خصم
class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen>
    with TickerProviderStateMixin {
  final _socket = SocketService();

  int    _seconds   = 0;
  int    _queuePos  = 0;
  bool   _searching = true;
  bool   _found     = false;
  Timer? _timer;

  late AnimationController _pulseCtrl;
  late AnimationController _rotCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSearch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _rotCtrl.dispose();
    if (_searching) _socket.cancelMatch();
    _socket.onMatchFound = null;
    _socket.onInQueue    = null;
    _socket.onError      = null;
    super.dispose();
  }

  void _startSearch() {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });

    _socket.connect();

    _socket.onInQueue = (data) {
      if (!mounted) return;
      setState(() => _queuePos = data['position'] ?? 1);
    };

    _socket.onMatchFound = (data) {
      if (!mounted || _found) return;
      _timer?.cancel();
      setState(() { _found = true; _searching = false; });

      final role           = data['role'] as String;
      final opponentName   = data['opponent_name'] as String? ?? 'opponent';
      final opponentId     = data['opponent_id'] as int?;
      final opponentAvatar = data['opponent_avatar'] as String?;
      final opponentLevel  = (data['opponent_level'] as int?) ?? 1;
      final roomId         = data['room_id'] as int;
      final roomCode       = data['room_code'] as String;
      final categoryId     = data['category_id'] as int;

      final room = RoomModel(
        roomId:     roomId,
        roomCode:   roomCode,
        categoryId: categoryId,
        host: RoomPlayerModel(
          id:   role == 'host' ? user.id : 0,
          name: role == 'host' ? user.name : opponentName,
        ),
        guest: RoomPlayerModel(
          id:   role == 'guest' ? user.id : 0,
          name: role == 'guest' ? user.name : opponentName,
        ),
      );

      final initialQuestions = {
        'questions': data['questions'],
        'total':     data['total'],
      };

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DualGameScreen(
              room:             room,
              role:             role,
              myName:           user.name,
              guestName:        opponentName,
              opponentId:       opponentId,
              initialQuestions: initialQuestions,
              opponentAvatar:   opponentAvatar,
              opponentLevel:    opponentLevel,
            ),
          ),
        );
      });
    };

    _socket.onError = (msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: _cSurface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    };

    _socket.findMatch(
      userId:   user.id,
      userName: user.name,
      lang:     context.locale.languageCode,
    );
  }

  void _cancel() {
    _socket.cancelMatch();
    Navigator.pop(context);
  }

  String get _timeStr {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '$_seconds ث';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      body: Stack(
        children: [
          // ─── خلفية متوهجة ─────────────────────────────────────────────────
          Positioned(
            top: -80, left: -80,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child2) => Container(
                width: 320, height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _cCyan.withValues(alpha: 0.07 + 0.04 * _pulseCtrl.value),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80, right: -80,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child2) => Container(
                width: 320, height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _cIndigo.withValues(alpha: 0.09 + 0.04 * _pulseCtrl.value),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),

          // ─── المحتوى الرئيسي ───────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: _found ? _buildFound() : _buildSearching(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (_searching)
            GestureDetector(
              onTap: _cancel,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _cSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white60, size: 20),
              ),
            )
          else
            const SizedBox(width: 36),
          const Spacer(),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [_cCyan, _cIndigo],
            ).createShader(r),
            child: Text(
              'matchmaking.title'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  // ─── شاشة البحث ────────────────────────────────────────────────────────────
  Widget _buildSearching() {
    final user = context.read<UserProvider>().user;
    final initial = user?.name.isNotEmpty == true
        ? user!.name[0].toUpperCase()
        : '؟';
    final avatar = (user as dynamic).avatar as String?;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [

        // ── أفاتار اللاعب ──────────────────────────────────────────────────
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, child) => Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_cCyan, _cIndigo],
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _cCyan.withValues(
                      alpha: 0.35 + 0.2 * _pulseCtrl.value),
                  blurRadius: 24 + 10 * _pulseCtrl.value,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
          child: CircleAvatar(
            radius: 58,
            backgroundColor: _cCard,
            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
            child: avatar == null
                ? Text(
                    initial,
                    style: const TextStyle(
                      color: _cCyan,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ),

        const SizedBox(height: 20),

        // ── شريط VS ────────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // خط يسار
            Expanded(
              child: Container(
                height: 1.5,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    _cCyan.withValues(alpha: 0.5),
                  ]),
                ),
              ),
            ),
            // VS badge
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child2) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 8),
                decoration: BoxDecoration(
                  color: _cCard,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _cCyan.withValues(
                        alpha: 0.4 + 0.2 * _pulseCtrl.value),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _cCyan.withValues(
                          alpha: 0.15 + 0.1 * _pulseCtrl.value),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: _cCyan,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                    shadows: [
                      Shadow(
                        color: _cCyan.withValues(alpha: 0.8),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // خط يمين
            Expanded(
              child: Container(
                height: 1.5,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _cIndigo.withValues(alpha: 0.5),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── أفاتار الخصم المجهول ───────────────────────────────────────────
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, child) => Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _cIndigo.withValues(alpha: 0.6),
                  Colors.white24,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _cIndigo.withValues(
                      alpha: 0.3 + 0.2 * _pulseCtrl.value),
                  blurRadius: 22 + 10 * _pulseCtrl.value,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
          child: CircleAvatar(
            radius: 58,
            backgroundColor: _cSurface,
            child: const Text(
              '?',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 44,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(
              duration: 1600.ms,
              color: _cIndigo.withValues(alpha: 0.25),
            ),

        const SizedBox(height: 36),

        // ── نص البحث ───────────────────────────────────────────────────────
        Text(
          'matchmaking.searching'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 10),

        // ── العداد ─────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: _cSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cCyan.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, color: _cCyan, size: 16),
              const SizedBox(width: 6),
              Text(
                'matchmaking.timer'.tr(namedArgs: {'time': _timeStr}),
                style: const TextStyle(
                  color: _cCyan,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        if (_queuePos > 0) ...[
          const SizedBox(height: 8),
          Text(
            'matchmaking.in_queue'.tr(),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 13),
          ),
        ],

        const SizedBox(height: 32),

        // ── نقاط متحركة ────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) =>
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == 0
                    ? _cCyan
                    : i == 1
                        ? _cIndigo
                        : _cCyan.withValues(alpha: 0.6),
                boxShadow: [
                  BoxShadow(
                    color: (i == 1 ? _cIndigo : _cCyan)
                        .withValues(alpha: 0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scaleXY(
                  begin: 0.4, end: 1.1,
                  duration: 600.ms,
                  delay: (i * 220).ms,
                  curve: Curves.easeInOut,
                )
                .then()
                .scaleXY(begin: 1.1, end: 0.4, duration: 600.ms),
          ),
        ),

        const SizedBox(height: 44),

        // ── زر الإلغاء ─────────────────────────────────────────────────────
        OutlinedButton.icon(
          onPressed: _cancel,
          icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
          label: Text(
            'matchmaking.cancel'.tr(),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 28),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  // ─── تم إيجاد خصم ──────────────────────────────────────────────────────────
  Widget _buildFound() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // دائرة إشعاع خارجية
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              Colors.greenAccent.withValues(alpha: 0.15),
              Colors.transparent,
            ]),
          ),
          child: Center(
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _cCard,
                border: Border.all(color: Colors.greenAccent, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withValues(alpha: 0.4),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Center(
                child: Text('🔥', style: TextStyle(fontSize: 52)),
              ),
            ),
          ),
        )
            .animate()
            .scale(
              duration: 500.ms,
              curve: Curves.elasticOut,
              begin: const Offset(0.3, 0.3),
              end:   const Offset(1.0, 1.0),
            ),

        const SizedBox(height: 28),

        Text(
          'matchmaking.found'.tr(),
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            shadows: [
              Shadow(color: Colors.greenAccent, blurRadius: 16),
            ],
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.3, end: 0),

        const SizedBox(height: 12),

        Text(
          'matchmaking.entering'.tr(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 15,
          ),
        ).animate().fadeIn(delay: 300.ms),

        const SizedBox(height: 32),

        // Loading bar
        Container(
          width: 180,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: _cSurface,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                    colors: [_cCyan, Colors.greenAccent]),
                boxShadow: [
                  BoxShadow(
                    color: _cCyan.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            )
                .animate()
                .custom(
                  duration: 1200.ms,
                  curve: Curves.easeInOut,
                  builder: (context, value, child) => SizedBox(
                    width: 180 * value,
                    child: child,
                  ),
                ),
          ),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }
}
