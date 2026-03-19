import 'dart:async';
import 'package:flutter/material.dart';
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

/// شاشة اللعب الثنائي — مسابقة بالوقت الإجمالي
/// كل لاعب يجيب بسرعته، الأسئلة تتغير فقط عند الإجابة
/// المسابقة تنتهي عند انتهاء الوقت الإجمالي
class DualGameScreen extends StatefulWidget {
  final RoomModel room;
  final String    role;         // 'host' أو 'guest'
  final String    myName;
  final String    guestName;
  final int?      opponentId;   // ID الخصم لزر المتابعة
  final Map<String, dynamic>? initialQuestions;

  const DualGameScreen({
    super.key,
    required this.room,
    required this.role,
    required this.myName,
    required this.guestName,
    this.opponentId,
    this.initialQuestions,
  });

  @override
  State<DualGameScreen> createState() => _DualGameScreenState();
}

class _DualGameScreenState extends State<DualGameScreen> {
  // ─── مدة المسابقة الإجمالية ───────────────────────────────────────────────
  static const int _matchDuration = 60; // بالثواني — غيّرها حسب الحاجة

  final _socket         = SocketService();
  final _roomService    = RoomService();
  final _friendsService = FriendsService();
  final _sound          = SoundService();

  List<QuestionModel> _questions     = [];
  int  _currentIndex    = 0;
  int  _myScore         = 0;
  int  _opponentScore   = 0;
  bool _answered        = false;
  int? _selected;
  bool _isLoading       = true;
  bool _iFinished       = false;
  bool _opponentFinished = false;

  // ─── حالة زر المتابعة ──────────────────────────────────────────────────
  // 'loading' | 'none' | 'pending_sent' | 'accepted'
  String _followStatus = 'loading';
  bool   _followLoading = false;

  // ─── WebRTC (Voice Chat) ────────────────────────────────────────────────
  WebRtcService? _webRtc;
  bool _micOn         = false;   // ميكروفوني
  bool _opponentMicOn = false;   // ميكروفون الخصم (يُحدَّث عبر socket)
  bool _webRtcReady   = false;

  // ── مؤقت المسابقة الإجمالي (يُعرض للاعبين) ──────────────────────────────
  int    _matchTimeLeft = _matchDuration;
  Timer? _matchTimer;

  @override
  void initState() {
    super.initState();
    _setupSocket();
    if (widget.initialQuestions != null) {
      _onGameStarted(widget.initialQuestions!);
    }
    // جلب حالة المتابعة مع الخصم
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFollowStatus());
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    _webRtc?.dispose();
    _socket.clearCallbacks();
    super.dispose();
  }

  // ─── جلب حالة المتابعة الأولية مع الخصم ─────────────────────────────────
  Future<void> _loadFollowStatus() async {
    if (widget.opponentId == null) {
      if (mounted) setState(() => _followStatus = 'none');
      return;
    }
    final token = context.read<UserProvider>().token;
    if (token == null) { if (mounted) setState(() => _followStatus = 'none'); return; }
    try {
      final status = await _friendsService.getFollowStatus(widget.opponentId!, token);
      if (mounted) setState(() => _followStatus = status);
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
      // رسالة تأكيد
      final msg = newStatus == 'accepted' ? '🎉 أصبحتما أصدقاء!' : '✅ تم إرسال طلب المتابعة';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: newStatus == 'accepted'
              ? Colors.greenAccent.withValues(alpha: 0.9)
              : const Color(0xFF6C63FF).withValues(alpha: 0.9),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // لو الخطأ "أصدقاء بالفعل" أو "مُرسَل" → حدّث الحالة بدون رسالة خطأ
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

    // عند قبول الصداقة من الطرف الآخر → حدّث الزر فوراً
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

    // ─── تحديث حالة ميك الخصم + إعادة حساب الـ track ────────────────────
    _socket.onWebRtcMicStatus = (micOn) {
      if (!mounted) return;
      setState(() => _opponentMicOn = micOn);
      // أخبر WebRtcService يعيد حساب هل الصوت يمشي أم لا
      _webRtc?.updateOpponentMicStatus(micOn);
    };
  }

  // ─── تهيئة WebRTC بعد بدء اللعبة ───────────────────────────────────────
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
      print('❌ WebRTC init error: $e');
    }
  }

  // ─── استقبال الأسئلة وبدء المؤقت ─────────────────────────────────────────
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
    _initWebRtc(); // بدء WebRTC عند انطلاق اللعبة
  }

  // ─── مؤقت المسابقة ────────────────────────────────────────────────────────
  void _startMatchTimer() {
    _matchTimer?.cancel();
    _matchTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_matchTimeLeft <= 1) {
        t.cancel();
        setState(() => _matchTimeLeft = 0);
        _finishGame(); // انتهى الوقت → أنهِ المسابقة
      } else {
        setState(() => _matchTimeLeft--);
      }
    });
  }

  // ─── اللاعب يختار إجابة ──────────────────────────────────────────────────
  void _onAnswerTap(int index) {
    if (_answered || _iFinished) return;

    final q         = _questions[_currentIndex];
    final correct   = _optionIndex(q.correctOption);
    final isCorrect = index == correct;
    final earned    = isCorrect ? 10 * q.difficulty : 0;

    isCorrect ? _sound.playCorrect() : _sound.playWrong();

    setState(() {
      _answered  = true;
      _selected  = index;
      _myScore  += earned;
    });

    // إرسال النتيجة للسيرفر
    _socket.submitAnswer(
      roomCode:    widget.room.roomCode,
      isCorrect:   isCorrect,
      scoreEarned: earned,
    );

    // بعد ثانية واحدة → السؤال التالي (تدوير لانهائي)
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted || _iFinished) return;
      setState(() {
        _answered     = false;
        _selected     = null;
        _currentIndex = (_currentIndex + 1) % _questions.length;
      });
    });
  }

  // ─── انتهاء المسابقة ──────────────────────────────────────────────────────
  void _finishGame() {
    if (_iFinished) return;
    setState(() => _iFinished = true);
    _matchTimer?.cancel();

    _socket.playerFinished(
      roomCode:   widget.room.roomCode,
      finalScore: _myScore,
    );

    // حفظ النقاط في DB
    final token = context.read<UserProvider>().token;
    if (token != null) {
      _roomService.finishRoom(
        roomId: widget.room.roomId,
        score:  _myScore,
        token:  token,
      ).then((newTotal) {
        context.read<UserProvider>().updateTotalScore(newTotal);
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

  // ─── زر المتابعة ──────────────────────────────────────────────────────────
  Widget _buildFollowButton() {
    if (widget.opponentId == null) return const SizedBox.shrink();

    // حالة التحميل الأولي
    if (_followStatus == 'loading') {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: SizedBox(
          height: 28,
          width: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white38,
          ),
        ),
      );
    }

    // تحديد شكل الزر حسب الحالة
    final bool isAccepted  = _followStatus == 'accepted';
    final bool isPending   = _followStatus == 'pending_sent' || _followStatus == 'pending_received';
    final bool canFollow   = _followStatus == 'none';
    final bool disabled    = isAccepted || isPending || _followLoading;

    // ألوان ذهبية للزر الرئيسي، رمادية للـ disabled، خضراء للأصدقاء
    const Color gold        = Color(0xFFFFD700);
    const Color goldLight   = Color(0xFFFFF176);

    final Color btnColor = isAccepted
        ? Colors.greenAccent.withValues(alpha: 0.15)
        : isPending
            ? Colors.white.withValues(alpha: 0.07)
            : gold.withValues(alpha: 0.15);

    final Color borderColor = isAccepted
        ? Colors.greenAccent.withValues(alpha: 0.7)
        : isPending
            ? Colors.white24
            : gold.withValues(alpha: 0.8);

    final String label = isAccepted
        ? '👥 أصدقاء'
        : isPending
            ? '✓ تمت المتابعة'
            : '⭐ تابع';

    final Color textColor = isAccepted
        ? Colors.greenAccent
        : isPending
            ? Colors.white38
            : goldLight;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        onTap: canFollow && !disabled ? _onFollowTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color:        btnColor,
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(color: borderColor, width: 1.2),
          ),
          child: _followLoading
              ? const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFFFD700)),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color:      textColor,
                    fontSize:   12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  // ─── تبديل الميكروفون ────────────────────────────────────────────────────
  // async لأن أول ضغطة تستدعي getUserMedia() داخلياً
  Future<void> _toggleMic() async {
    if (_webRtc == null || !_webRtcReady) return;
    await _webRtc!.toggleMic();
    if (mounted) setState(() => _micOn = _webRtc!.micEnabled);
  }

  int _optionIndex(String opt) =>
      ['a', 'b', 'c', 'd'].indexOf(opt.toLowerCase());

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ─── البناء ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('⚔️', style: TextStyle(fontSize: 60)),
              SizedBox(height: 16),
              CircularProgressIndicator(color: Color(0xFF6C63FF)),
              SizedBox(height: 12),
              Text('جاري تحميل الأسئلة...', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    if (_iFinished) return _buildWaitingScreen();

    if (_questions.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: Text('لا توجد أسئلة', style: TextStyle(color: Colors.white))),
      );
    }

    final q = _questions[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            // ─── هيدر: النقاط + المؤقت الإجمالي ─────────────────────────
            _buildScoresHeader(),

            // ─── زر المتابعة (أسفل الهيدر، قابل للضغط خلال اللعب) ───────
            _buildFollowButton(),

            const SizedBox(height: 6),

            // ─── رقم السؤال ───────────────────────────────────────────────
            Text(
              'سؤال ${_currentIndex + 1}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),

            const SizedBox(height: 10),

            // ─── السؤال والخيارات ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // نص السؤال
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color:        Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(18),
                        border:       Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        q.questionText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   17,
                          fontWeight: FontWeight.w600,
                          height:     1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // الخيارات الأربعة
                    ...List.generate(4, (i) => _buildOption(i, q)),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── هيدر النقاط مع المؤقت الإجمالي ────────────────────────────────────
  Widget _buildScoresHeader() {
    final isUrgent = _matchTimeLeft <= 10;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent
              ? Colors.redAccent.withValues(alpha: 0.6)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          // ── نقاطي ───────────────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.myName,
                  style: const TextStyle(
                    color: Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$_myScore',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // ── المنتصف: المؤقت + زر الميك ──────────────────────────────────
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: (isUrgent ? Colors.redAccent : const Color(0xFF6C63FF))
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isUrgent ? Colors.redAccent : const Color(0xFF6C63FF),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isUrgent ? '🔥' : '⏱',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      _formatTime(_matchTimeLeft),
                      style: TextStyle(
                        color:      isUrgent ? Colors.redAccent : Colors.white,
                        fontSize:   20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // ── زر الميكروفون ──────────────────────────────────────────
              GestureDetector(
                onTap: _webRtcReady ? _toggleMic : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width:  38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _micOn
                        ? Colors.greenAccent.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: _micOn
                          ? Colors.greenAccent
                          : (_webRtcReady ? Colors.white38 : Colors.white12),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    _micOn ? Icons.mic : Icons.mic_off,
                    size:  18,
                    color: _micOn
                        ? Colors.greenAccent
                        : (_webRtcReady ? Colors.white54 : Colors.white24),
                  ),
                ),
              ),
            ],
          ),

          // ── نقاط الخصم ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // اسم الخصم + أيقونة ميكه
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        widget.role == 'host' ? widget.guestName : widget.room.host.name,
                        style: const TextStyle(
                          color: Color(0xFFFF6584), fontWeight: FontWeight.bold, fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_webRtcReady) ...[
                      const SizedBox(width: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _opponentMicOn
                              ? Colors.greenAccent.withValues(alpha: 0.2)
                              : Colors.transparent,
                        ),
                        child: Icon(
                          _opponentMicOn ? Icons.mic : Icons.mic_off,
                          size:  12,
                          color: _opponentMicOn ? Colors.greenAccent : Colors.white24,
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_opponentScore',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_opponentFinished)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Text('✅', style: TextStyle(fontSize: 14)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── بطاقة الخيار ────────────────────────────────────────────────────────
  Widget _buildOption(int index, QuestionModel q) {
    final options = [q.optionA, q.optionB, q.optionC, q.optionD];
    final labels  = ['A', 'B', 'C', 'D'];
    final correct = _optionIndex(q.correctOption);

    Color borderColor = Colors.white12;
    Color bgColor     = Colors.white.withValues(alpha: 0.05);
    Color textColor   = Colors.white;

    if (_answered) {
      if (index == correct) {
        borderColor = Colors.greenAccent;
        bgColor     = Colors.greenAccent.withValues(alpha: 0.15);
        textColor   = Colors.greenAccent;
      } else if (index == _selected) {
        borderColor = Colors.redAccent;
        bgColor     = Colors.redAccent.withValues(alpha: 0.15);
        textColor   = Colors.redAccent;
      }
    }

    return GestureDetector(
      onTap: () => _onAnswerTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin:   const EdgeInsets.only(bottom: 12),
        padding:  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape:  BoxShape.circle,
                color:  borderColor.withValues(alpha: 0.2),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Text(
                  labels[index],
                  style: TextStyle(
                    color:      textColor,
                    fontWeight: FontWeight.bold,
                    fontSize:   13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                options[index],
                style: TextStyle(color: textColor, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── شاشة انتهاء الوقت ───────────────────────────────────────────────────
  Widget _buildWaitingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⏰', style: TextStyle(fontSize: 70)),
              const SizedBox(height: 20),
              const Text(
                'انتهى وقت المسابقة!',
                style: TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'نقاطك: $_myScore',
                style: const TextStyle(
                  color: Color(0xFF6C63FF), fontSize: 28, fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'في انتظار النتيجة النهائية...',
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: Color(0xFF6C63FF)),
            ],
          ),
        ),
      ),
    );
  }
}
