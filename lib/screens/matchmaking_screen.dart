import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../models/question_model.dart';
import '../models/room_model.dart';
import '../providers/user_provider.dart';
import '../services/socket_service.dart';
import 'dual_game_screen.dart';

/// شاشة البحث التلقائي عن خصم
class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  final _socket = SocketService();

  int     _seconds    = 0;
  int     _queuePos   = 0;
  bool    _searching  = true;
  bool    _found      = false;
  Timer?  _timer;

  @override
  void initState() {
    super.initState();
    // نستخدم addPostFrameCallback لأن context.locale يحتاج InheritedWidget
    // لا يُسمح باستدعائه داخل initState مباشرةً
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSearch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_searching) _socket.cancelMatch();
    _socket.onMatchFound = null;
    _socket.onInQueue    = null;
    _socket.onError      = null;
    super.dispose();
  }

  void _startSearch() {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    // بدء العداد
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });

    // الاتصال والبحث
    _socket.connect();

    _socket.onInQueue = (data) {
      if (!mounted) return;
      setState(() => _queuePos = data['position'] ?? 1);
    };

    _socket.onMatchFound = (data) {
      if (!mounted || _found) return;
      _timer?.cancel();
      setState(() { _found = true; _searching = false; });

      // بناء RoomModel من بيانات الـ Match
      final role         = data['role'] as String;          // 'host' أو 'guest'
      final opponentName = data['opponent_name'] as String? ?? 'opponent';
      final roomId       = data['room_id'] as int;
      final roomCode     = data['room_code'] as String;
      final categoryId   = data['category_id'] as int;

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

      // الأسئلة جاهزة من السيرفر
      final initialQuestions = {
        'questions': data['questions'],
        'total':     data['total'],
      };

      // انتقل للعبة بعد ثانية احتفالاً بإيجاد الخصم
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DualGameScreen(
              room:             room,
              role:             role,
              myName:           user.name,
              guestName:        opponentName,
              initialQuestions: initialQuestions,
            ),
          ),
        );
      });
    };

    _socket.onError = (msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
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
    return m > 0 ? '${m}:${s.toString().padLeft(2, '0')}' : '$_seconds ث';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _searching
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: _cancel,
              )
            : null,
        title: Text(
          'matchmaking.title'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _found ? _buildFound() : _buildSearching(),
        ),
      ),
    );
  }

  // ─── شاشة البحث ───────────────────────────────────────────────────────────
  Widget _buildSearching() {
    final user = context.read<UserProvider>().user;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // أفاتار اللاعب
        CircleAvatar(
          radius: 50,
          backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.3),
          child: Text(
            user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '؟',
            style: const TextStyle(
              color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold,
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .scaleXY(begin: 1.0, end: 1.08, duration: 900.ms)
            .then()
            .scaleXY(begin: 1.08, end: 1.0, duration: 900.ms),

        const SizedBox(height: 24),

        // ─── VS ────────────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '⚔️',
              style: TextStyle(fontSize: 32),
            )
                .animate(onPlay: (c) => c.repeat())
                .rotate(duration: 1500.ms, begin: -0.05, end: 0.05)
                .then()
                .rotate(begin: 0.05, end: -0.05),
          ],
        ),

        const SizedBox(height: 12),

        // أفاتار خصم مجهول
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          child: const Text('?', style: TextStyle(color: Colors.white38, fontSize: 40)),
        )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 1200.ms, color: Colors.white24),

        const SizedBox(height: 32),

        Text(
          'matchmaking.searching'.tr(),
          style: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'matchmaking.timer'.tr(namedArgs: {'time': _timeStr}),
          style: const TextStyle(color: Colors.white38, fontSize: 14),
        ),

        if (_queuePos > 0) ...[
          const SizedBox(height: 4),
          Text(
            'matchmaking.in_queue'.tr(),
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],

        const SizedBox(height: 32),

        // ─── Loading dots ───────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) =>
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 10, height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF6C63FF),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scaleXY(
                  begin: 0.5, end: 1.0,
                  duration: 600.ms,
                  delay: (i * 200).ms,
                )
                .then()
                .scaleXY(begin: 1.0, end: 0.5, duration: 600.ms),
          ),
        ),

        const SizedBox(height: 40),

        // ─── إلغاء ─────────────────────────────────────────────────────────
        OutlinedButton.icon(
          onPressed: _cancel,
          icon: const Icon(Icons.close, color: Colors.white54),
          label: Text('matchmaking.cancel'.tr(), style: const TextStyle(color: Colors.white54)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  // ─── تم إيجاد خصم ────────────────────────────────────────────────────────
  Widget _buildFound() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🔥', style: TextStyle(fontSize: 80))
            .animate()
            .scale(duration: 400.ms, curve: Curves.elasticOut),
        const SizedBox(height: 20),
        Text(
          'matchmaking.found'.tr(),
          style: const TextStyle(
            color: Colors.greenAccent, fontSize: 26, fontWeight: FontWeight.bold,
          ),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 8),
        Text(
          'matchmaking.entering'.tr(),
          style: const TextStyle(color: Colors.white54, fontSize: 15),
        ).animate().fadeIn(delay: 300.ms),
        const SizedBox(height: 24),
        const CircularProgressIndicator(color: Color(0xFF6C63FF)),
      ],
    );
  }
}
