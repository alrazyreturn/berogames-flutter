import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../models/question_model.dart';
import '../models/room_model.dart';
import '../providers/user_provider.dart';
import '../services/friends_service.dart';
import '../services/room_service.dart';
import '../services/socket_service.dart';
import '../services/sound_service.dart';
import '../services/webrtc_service.dart';
import 'dual_result_screen.dart';
import 'leaderboard_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';

// ─── Design tokens (Neon-Glass Editorial) ────────────────────────────────────
const _cBg      = Color(0xFF0B1326);
const _cSurface = Color(0xFF131B2E);
const _cCard    = Color(0xFF171F33);
const _cCyan    = Color(0xFF00FBFB);
// Nav uses Galactic Play colors (matches profile_screen)
const _cNavBg   = Color(0xFF10102B);

/// شاشة اللعب الثنائي — Neon-Glass Editorial Design
class DualGameScreen extends StatefulWidget {
  final RoomModel room;
  final String    role;            // 'host' أو 'guest'
  final String    myName;
  final String    guestName;
  final int?      opponentId;
  final Map<String, dynamic>? initialQuestions;
  // بيانات الخصم الإضافية للهيدر
  final String?   opponentAvatar;
  final int       opponentLevel;
  final bool      isBot;

  const DualGameScreen({
    super.key,
    required this.room,
    required this.role,
    required this.myName,
    required this.guestName,
    this.opponentId,
    this.initialQuestions,
    this.opponentAvatar,
    this.opponentLevel = 1,
    this.isBot = false,
  });

  @override
  State<DualGameScreen> createState() => _DualGameScreenState();
}

class _DualGameScreenState extends State<DualGameScreen> {
  // ─── مدة المسابقة ────────────────────────────────────────────────────────
  static const int _matchDuration = 60;

  final _socket         = SocketService();
  final _roomService    = RoomService();
  final _friendsService = FriendsService();
  final _sound          = SoundService();

  List<QuestionModel> _questions      = [];
  int  _currentIndex    = 0;
  int  _myScore         = 0;
  int  _opponentScore   = 0;
  bool _answered        = false;
  int? _selected;
  bool _isLoading       = true;
  bool _iFinished       = false;
  bool _opponentFinished = false;
  int  _questionCount   = 0; // عداد الأسئلة للعرض

  // ─── حالة المتابعة ────────────────────────────────────────────────────────
  String _followStatus  = 'loading';
  bool   _followLoading = false;

  // ─── WebRTC ───────────────────────────────────────────────────────────────
  WebRtcService? _webRtc;
  bool _micOn         = false;
  bool _opponentMicOn = false;
  bool _webRtcReady   = false;

  // ─── مؤقت المسابقة ────────────────────────────────────────────────────────
  int    _matchTimeLeft = _matchDuration;
  Timer? _matchTimer;

  @override
  void initState() {
    super.initState();
    _setupSocket();
    if (widget.initialQuestions != null) {
      _onGameStarted(widget.initialQuestions!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFollowStatus());
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    _webRtc?.dispose();
    _socket.clearCallbacks();
    super.dispose();
  }

  // ─── جلب حالة المتابعة ────────────────────────────────────────────────────
  Future<void> _loadFollowStatus() async {
    // لا نجلب حالة المتابعة للبوت
    if (widget.isBot || widget.opponentId == null) {
      if (mounted) setState(() => _followStatus = 'none');
      return;
    }
    final token = context.read<UserProvider>().token;
    if (token == null) { if (mounted) setState(() => _followStatus = 'none'); return; }
    try {
      final res = await _friendsService.getFollowStatus(widget.opponentId!, token);
      if (mounted) setState(() => _followStatus = res['status'] as String? ?? 'none');
    } catch (_) {
      if (mounted) setState(() => _followStatus = 'none');
    }
  }

  // ─── الضغط على زر المتابعة ────────────────────────────────────────────────
  Future<void> _onFollowTap() async {
    if (widget.opponentId == null || _followLoading) return;
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    setState(() => _followLoading = true);
    try {
      final result = await _friendsService.followByUserId(widget.opponentId!, token);
      final newStatus = result['status'] as String? ?? 'pending_sent';
      if (!mounted) return;
      setState(() => _followStatus = newStatus);
      final msg = newStatus == 'accepted' ? '🎉 أصبحتما أصدقاء!' : '✅ تم إرسال طلب المتابعة';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: newStatus == 'accepted'
              ? Colors.greenAccent.withValues(alpha: 0.9)
              : const Color(0xFF6366F1).withValues(alpha: 0.9),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (msg.contains('accepted') || msg.contains('أصدقاء')) {
        setState(() => _followStatus = 'accepted');
      } else if (msg.contains('pending') || msg.contains('مُرسَل')) {
        setState(() => _followStatus = 'pending_sent');
      }
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  // ─── إعداد Socket ─────────────────────────────────────────────────────────
  void _setupSocket() {
    _socket.onGameStarted = _onGameStarted;

    _socket.onFriendshipAccepted = (data) {
      if (!mounted) return;
      setState(() => _followStatus = 'accepted');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🎉 أصبحتما أصدقاء!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.greenAccent.withValues(alpha: 0.9),
          duration: const Duration(seconds: 2),
        ),
      );
    };

    _socket.onScoreUpdate = (data) {
      if (!mounted) return;
      setState(() {
        if (widget.role == 'host') {
          _myScore       = data['host_score']  ?? _myScore;
          _opponentScore = data['guest_score'] ?? _opponentScore;
        } else {
          _myScore       = data['guest_score'] ?? _myScore;
          _opponentScore = data['host_score']  ?? _opponentScore;
        }
      });
    };

    _socket.onOpponentFinished = (data) {
      if (!mounted) return;
      setState(() => _opponentFinished = true);
    };

    _socket.onGameOver = _onGameOver;

    _socket.onOpponentDisconnected = (data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${data['name'] ?? "الخصم"} قطع الاتصال 😔'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    };

    _socket.onWebRtcMicStatus = (micOn) {
      if (!mounted) return;
      setState(() => _opponentMicOn = micOn);
      _webRtc?.updateOpponentMicStatus(micOn);
    };
  }

  // ─── تهيئة WebRTC ────────────────────────────────────────────────────────
  Future<void> _initWebRtc() async {
    try {
      _webRtc = WebRtcService(
        socket:   _socket,
        roomCode: widget.room.roomCode,
        isHost:   widget.role == 'host',
      );
      await _webRtc!.init();
      if (mounted) setState(() => _webRtcReady = _webRtc!.isInitialized);
    } catch (e) {
      debugPrint('❌ WebRTC init error: $e');
    }
  }

  // ─── بدء اللعبة ───────────────────────────────────────────────────────────
  void _onGameStarted(Map<String, dynamic> data) {
    if (!mounted) return;
    final rawList = data['questions'] as List;
    final qs = rawList
        .map((q) => QuestionModel.fromJson(Map<String, dynamic>.from(q)))
        .toList();
    setState(() {
      _questions = qs;
      _isLoading = false;
    });
    _startMatchTimer();
    _initWebRtc();
  }

  // ─── مؤقت المسابقة ────────────────────────────────────────────────────────
  void _startMatchTimer() {
    _matchTimer?.cancel();
    _matchTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_matchTimeLeft <= 1) {
        t.cancel();
        setState(() => _matchTimeLeft = 0);
        _finishGame();
      } else {
        setState(() => _matchTimeLeft--);
      }
    });
  }

  // ─── اختيار إجابة ─────────────────────────────────────────────────────────
  void _onAnswerTap(int index) {
    if (_answered || _iFinished) return;

    final q         = _questions[_currentIndex];
    final correct   = _optionIndex(q.correctOption);
    final isCorrect = index == correct;
    final earned    = isCorrect ? 10 * q.difficulty : 0;

    isCorrect ? _sound.playCorrect() : _sound.playWrong();

    setState(() {
      _answered      = true;
      _selected      = index;
      _myScore      += earned;
      _questionCount++;
    });

    _socket.submitAnswer(
      roomCode:    widget.room.roomCode,
      isCorrect:   isCorrect,
      scoreEarned: earned,
    );

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted || _iFinished) return;
      setState(() {
        _answered     = false;
        _selected     = null;
        _currentIndex = (_currentIndex + 1) % _questions.length;
      });
    });
  }

  // ─── إنهاء المسابقة ───────────────────────────────────────────────────────
  void _finishGame() {
    if (_iFinished) return;
    setState(() => _iFinished = true);
    _matchTimer?.cancel();

    _socket.playerFinished(
      roomCode:   widget.room.roomCode,
      finalScore: _myScore,
    );

    final token    = context.read<UserProvider>().token;
    final provider = context.read<UserProvider>();
    if (token != null) {
      _roomService.finishRoom(
        roomId: widget.room.roomId,
        score:  _myScore,
        token:  token,
      ).then((newTotal) {
        provider.updateTotalScore(newTotal);
      }).catchError((_) {});
    }
  }

  void _onGameOver(Map<String, dynamic> data) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DualResultScreen(
          myName:       widget.myName,
          opponentName: widget.role == 'host'
              ? (data['guest_name'] ?? widget.guestName)
              : (data['host_name']  ?? widget.room.host.name),
          myScore:      widget.role == 'host'
              ? data['host_score']  ?? _myScore
              : data['guest_score'] ?? _myScore,
          opponentScore: widget.role == 'host'
              ? data['guest_score'] ?? _opponentScore
              : data['host_score']  ?? _opponentScore,
          winner:       data['winner'] ?? 'draw',
          myRole:       widget.role,
        ),
      ),
    );
  }

  // ─── تبديل الميكروفون ────────────────────────────────────────────────────
  Future<void> _toggleMic() async {
    if (_webRtc == null || !_webRtcReady) return;
    await _webRtc!.toggleMic();
    if (mounted) setState(() => _micOn = _webRtc!.micEnabled);
  }

  int    _optionIndex(String opt) => ['a', 'b', 'c', 'd'].indexOf(opt.toLowerCase());
  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ─── البناء الرئيسي ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading)      return _buildLoadingScreen();
    if (_iFinished)      return _buildWaitingScreen();
    if (_questions.isEmpty) {
      return const Scaffold(
        backgroundColor: _cBg,
        body: Center(child: Text('لا توجد أسئلة', style: TextStyle(color: Colors.white))),
      );
    }

    final q        = _questions[_currentIndex];
    final isUrgent = _matchTimeLeft <= 10;

    return Scaffold(
      backgroundColor: _cBg,
      body: Column(
        children: [
          // ── Header: scores + timer ────────────────────────────────────────
          _buildHeader(isUrgent),

          // ── Content: question + options ───────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  _buildQuestionCard(q),
                  const SizedBox(height: 14),
                  ...List.generate(4, (i) => _buildOption(i, q)),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),

          // ── Bottom actions: follow + mic ──────────────────────────────────
          _buildBottomActions(),

          // ── Bottom Navigation ─────────────────────────────────────────────
          _buildBottomNav(),
        ],
      ),
    );
  }

  // ─── Loading Screen ────────────────────────────────────────────────────────
  Widget _buildLoadingScreen() => Scaffold(
    backgroundColor: _cBg,
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _cCyan.withValues(alpha: 0.1),
              border: Border.all(color: _cCyan.withValues(alpha: 0.4), width: 2),
              boxShadow: [BoxShadow(color: _cCyan.withValues(alpha: 0.15), blurRadius: 24)],
            ),
            child: const Center(child: Text('⚔️', style: TextStyle(fontSize: 36))),
          ),
          const SizedBox(height: 24),
          CircularProgressIndicator(color: _cCyan, strokeWidth: 2),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل الأسئلة...',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
          ),
        ],
      ),
    ),
  );

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isUrgent) {
    final opponentName = widget.role == 'host' ? widget.guestName : widget.room.host.name;

    return SafeArea(
      bottom: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _cSurface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Opponent ──────────────────────────────────────────────────
            Expanded(
              child: _buildPlayerSide(
                name:            opponentName,
                score:           _opponentScore,
                isMe:            false,
                isFinished:      _opponentFinished,
                showOpponentMic: _webRtcReady,
                opponentMicOn:   _opponentMicOn,
              ),
            ),

            // ── Center: Timer + progress bar ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'vs',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isUrgent
                          ? Colors.redAccent.withValues(alpha: 0.12)
                          : _cCyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isUrgent
                            ? Colors.redAccent.withValues(alpha: 0.5)
                            : _cCyan.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isUrgent ? Colors.redAccent : _cCyan).withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      _formatTime(_matchTimeLeft),
                      style: TextStyle(
                        color: isUrgent ? Colors.redAccent : _cCyan,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 60,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _matchTimeLeft / _matchDuration,
                        backgroundColor: Colors.white.withValues(alpha: 0.07),
                        valueColor: AlwaysStoppedAnimation(
                          isUrgent ? Colors.redAccent : _cCyan,
                        ),
                        minHeight: 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── My side ───────────────────────────────────────────────────
            Expanded(
              child: _buildPlayerSide(
                name:            widget.myName,
                score:           _myScore,
                isMe:            true,
                isFinished:      _iFinished,
                showOpponentMic: false,
                opponentMicOn:   false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSide({
    required String name,
    required int    score,
    required bool   isMe,
    required bool   isFinished,
    required bool   showOpponentMic,
    required bool   opponentMicOn,
  }) {
    final color    = isMe ? _cCyan : const Color(0xFFFF6B8A);
    final subtitle = isMe ? 'نقاطك' : 'الخصم';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
                border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 10),
                ],
              ),
              child: Icon(Icons.person_rounded, color: color, size: 22),
            ),
            if (showOpponentMic)
              Positioned(
                top: -3, right: -3,
                child: Container(
                  width: 17, height: 17,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: opponentMicOn
                        ? Colors.greenAccent.withValues(alpha: 0.9)
                        : _cSurface,
                    border: Border.all(color: _cBg, width: 1.5),
                  ),
                  child: Icon(
                    opponentMicOn ? Icons.mic : Icons.mic_off,
                    size: 9,
                    color: opponentMicOn ? _cBg : Colors.white38,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10),
        ),
        const SizedBox(height: 1),
        Text(
          name,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$score',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isFinished) ...[
              const SizedBox(width: 4),
              const Text('✅', style: TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ],
    );
  }


  // ─── Question Card ─────────────────────────────────────────────────────────
  Widget _buildQuestionCard(QuestionModel q) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _cCyan.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top row: category dot + challenge badge
          Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Category
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _cCyan,
                        boxShadow: [
                          BoxShadow(color: _cCyan.withValues(alpha: 0.5), blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'ثقافة عامة',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                // Challenge number
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _cCyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _cCyan.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'التحدي #${_questionCount + 1}',
                    style: TextStyle(
                      color: _cCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Question text
          Text(
            q.questionText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Answer Option ─────────────────────────────────────────────────────────
  Widget _buildOption(int index, QuestionModel q) {
    final options = [q.optionA, q.optionB, q.optionC, q.optionD];
    final labels  = ['A', 'B', 'C', 'D'];
    final correct = _optionIndex(q.correctOption);

    Color borderColor = Colors.white.withValues(alpha: 0.08);
    Color bgColor     = _cCard;
    Color badgeBg     = Colors.white.withValues(alpha: 0.1);
    Color badgeFg     = Colors.white54;
    Color textColor   = Colors.white70;
    List<BoxShadow>? glow;

    if (_answered) {
      if (index == correct) {
        borderColor = Colors.greenAccent.withValues(alpha: 0.7);
        bgColor     = Colors.greenAccent.withValues(alpha: 0.08);
        badgeBg     = Colors.greenAccent;
        badgeFg     = _cBg;
        textColor   = Colors.greenAccent;
        glow = [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.12), blurRadius: 14)];
      } else if (index == _selected) {
        borderColor = Colors.redAccent.withValues(alpha: 0.7);
        bgColor     = Colors.redAccent.withValues(alpha: 0.08);
        badgeBg     = Colors.redAccent;
        badgeFg     = Colors.white;
        textColor   = Colors.redAccent;
      }
    }

    return GestureDetector(
      onTap: () => _onAnswerTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin:   const EdgeInsets.only(bottom: 12),
        padding:  const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        decoration: BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: borderColor, width: 1.5),
          boxShadow:    glow,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              // Letter badge (left side)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badgeBg,
                ),
                child: Center(
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      color:      badgeFg,
                      fontWeight: FontWeight.bold,
                      fontSize:   14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Answer text (right side, Arabic)
              Expanded(
                child: Text(
                  options[index],
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color:      textColor,
                    fontSize:   15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Bottom Actions ────────────────────────────────────────────────────────
  Widget _buildBottomActions() {
    final bool isAccepted = _followStatus == 'accepted';
    final bool isPending  = _followStatus == 'pending_sent' || _followStatus == 'pending_received';
    final bool canFollow  = _followStatus == 'none';

    final Color followColor = isAccepted
        ? Colors.greenAccent
        : isPending
            ? Colors.white38
            : _cCyan;

    final IconData followIcon = isAccepted
        ? Icons.people_rounded
        : isPending
            ? Icons.hourglass_top_rounded
            : Icons.person_add_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Follow ────────────────────────────────────────────────────────
          if (widget.opponentId != null) ...[
            _CircleAction(
              icon:    followIcon,
              color:   followColor,
              loading: _followLoading,
              onTap:   canFollow && !_followLoading ? _onFollowTap : null,
            ),
            const SizedBox(width: 20),
          ],

          // ── My Mic toggle ─────────────────────────────────────────────────
          _CircleAction(
            icon:  _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            color: _micOn
                ? Colors.greenAccent
                : (_webRtcReady ? Colors.white54 : Colors.white24),
            onTap: _webRtcReady ? _toggleMic : null,
          ),

          const SizedBox(width: 20),

          // ── Opponent mic status (read-only indicator) ─────────────────────
          _CircleAction(
            icon:  _opponentMicOn ? Icons.hearing_rounded : Icons.hearing_disabled_rounded,
            color: _opponentMicOn ? Colors.greenAccent : Colors.white24,
            onTap: null,
          ),
        ],
      ),
    );
  }

  // ─── Bottom Navigation (matches profile_screen.dart exactly) ─────────────
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
                onTap:    () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
              _NavItem(
                icon:     Icons.leaderboard_rounded,
                label:    'home.nav_ranking'.tr(),
                isActive: false,
                onTap:    () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
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
                    MaterialPageRoute(builder: (_) => const ProfileScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Waiting Screen ────────────────────────────────────────────────────────
  Widget _buildWaitingScreen() => Scaffold(
    backgroundColor: _cBg,
    bottomNavigationBar: _buildBottomNav(),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _cCyan.withValues(alpha: 0.1),
                border: Border.all(color: _cCyan.withValues(alpha: 0.4), width: 2),
                boxShadow: [BoxShadow(color: _cCyan.withValues(alpha: 0.2), blurRadius: 28)],
              ),
              child: const Center(child: Text('⏰', style: TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 24),
            const Text(
              'انتهى وقت المسابقة!',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'نقاطك: $_myScore',
              style: TextStyle(color: _cCyan, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Text(
              'في انتظار النتيجة النهائية...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
            ),
            const SizedBox(height: 20),
            CircularProgressIndicator(color: _cCyan, strokeWidth: 2),
          ],
        ),
      ),
    ),
  );
}

// ─── Circle Action Button ──────────────────────────────────────────────────────
class _CircleAction extends StatelessWidget {
  final IconData      icon;
  final Color         color;
  final bool          loading;
  final VoidCallback? onTap;

  const _CircleAction({
    required this.icon,
    required this.color,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),
        border: Border.all(
          color: color.withValues(alpha: onTap != null ? 0.5 : 0.2),
          width: 1.5,
        ),
        boxShadow: onTap != null
            ? [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 10)]
            : null,
      ),
      child: loading
          ? Center(
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
              ),
            )
          : Icon(icon, color: color, size: 22),
    ),
  );
}

// ─── Bottom Nav Item (matches profile_screen.dart) ────────────────────────────
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

  static const _activeCyan = Color(0xFF00E3FD); // Galactic Play cyan = profile screen

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:  isActive ? _activeCyan.withValues(alpha: 0.15) : Colors.transparent,
            shape:  BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isActive ? _activeCyan : Colors.white38,
            size:  24,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color:      isActive ? _activeCyan : Colors.white38,
            fontSize:   10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}
