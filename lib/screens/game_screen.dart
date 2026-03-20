import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../models/category_model.dart';
import '../models/question_model.dart';
import '../providers/user_provider.dart';
import '../services/game_service.dart';
import '../services/sound_service.dart';
import '../services/ad_service.dart';
import 'thankyou_screen.dart';

// ─── Design tokens (Neon-Glass Editorial) ────────────────────────────────────
const _cBg     = Color(0xFF0B1326);
const _cSurface= Color(0xFF131B2E);
const _cCard   = Color(0xFF171F33);
const _cCyan   = Color(0xFF00FBFB);
const _cIndigo = Color(0xFF6366F1);

class GameScreen extends StatefulWidget {
  final CategoryModel category;
  const GameScreen({super.key, required this.category});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {

  // ─── Services ────────────────────────────────────────────────────────────
  final _gameService  = GameService();
  final _soundService = SoundService();

  // ─── ثوابت ───────────────────────────────────────────────────────────────
  static const int _batchSize       = 3;
  static const int _streakToLevelUp = 2;
  static const int _totalDuration  = 60;  // مدة المسابقة الكلية بالثواني
  static const int _hintCost       = 50;  // تكلفة التلميح بالنقاط

  // ─── حالة اللعبة ─────────────────────────────────────────────────────────
  int  _currentDifficulty  = 1;
  int  _correctStreak      = 0;
  int  _questionIndex      = 0;
  int  _score              = 0;
  int  _difficultyReached  = 1;
  int  _correctAnswers     = 0;
  int  _wrongAnswers       = 0;

  // المؤقت الإجمالي (مثل التحدي الثنائي)
  int    _matchTimeLeft = _totalDuration;
  Timer? _matchTimer;
  bool   _timerStarted = false;

  // Hint per question
  bool _hintUsed        = false;
  int? _eliminatedIndex;

  List<QuestionModel> _batch      = [];
  int                 _batchIndex = 0;

  bool _isLoading       = true;
  bool _showCelebration = false;
  bool _isFinishing     = false;
  int? _selected;

  // ─── Controllers ─────────────────────────────────────────────────────────
  late ConfettiController _confettiCtrl;

  QuestionModel? get _current =>
      _batchIndex < _batch.length ? _batch[_batchIndex] : null;

  // ─── Init ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(
        duration: const Duration(milliseconds: 1200));
    _initGame();
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    _confettiCtrl.dispose();
    super.dispose();
  }

  // ─── تهيئة اللعبة ────────────────────────────────────────────────────────
  Future<void> _initGame() async {
    final token = context.read<UserProvider>().token;
    if (token != null) {
      try {
        final level = await _gameService.getUserLevel(
          categoryId: widget.category.id,
          token: token,
        );
        _currentDifficulty = level;
        _difficultyReached = level;
      } catch (_) {
        _currentDifficulty = 1;
        _difficultyReached = 1;
      }
    }
    _loadNextBatch();
  }

  // ─── تحميل دفعة أسئلة ────────────────────────────────────────────────────
  Future<void> _loadNextBatch() async {
    setState(() => _isLoading = true);
    final lang = context.locale.languageCode;
    List<QuestionModel> questions = [];
    int tryDifficulty = _currentDifficulty;

    while (tryDifficulty >= 1 && questions.isEmpty) {
      questions = await _gameService.getQuestions(
        categoryId: widget.category.id,
        difficulty: tryDifficulty,
        limit: _batchSize,
        lang: lang,
      );
      if (questions.isEmpty) tryDifficulty--;
    }

    if (!mounted) return;

    if (questions.isEmpty) {
      _finishGame();
      return;
    }

    setState(() {
      _batch           = questions;
      _batchIndex      = 0;
      _isLoading       = false;
      _selected        = null;
      _hintUsed        = false;
      _eliminatedIndex = null;
    });

    // نبدأ المؤقت مرة واحدة فقط عند أول دفعة
    if (!_timerStarted) {
      _timerStarted = true;
      _startMatchTimer();
    }
  }

  // ─── المؤقت الإجمالي (مثل التحدي الثنائي) ───────────────────────────────
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

  // ─── اختيار إجابة (بلا retry - مثل التحدي الثنائي) ─────────────────────
  void _answer(int index) {
    if (_showCelebration ||        _current == null || _isLoading || _selected != null) return;
    if (index == _eliminatedIndex) return;

    final correct = index == _current!.correctIndex;
    setState(() => _selected = index);

    if (correct) {
      _soundService.playCorrect();
      final earned = _current!.points;
      _score += earned;
      _correctStreak++;
      _correctAnswers++;

      if (_correctStreak >= _streakToLevelUp && _currentDifficulty < 10) {
        _currentDifficulty++;
        _correctStreak = 0;
        if (_currentDifficulty > _difficultyReached) {
          _difficultyReached = _currentDifficulty;
        }
      }
      _saveScoreLocally();
      _showCelebrationOverlay(earned);
    } else {
      // ❌ خطأ → لا خصم، لا إعادة محاولة - ننتقل للسؤال التالي بعد 0.8 ث
      _soundService.playWrong();
      _correctStreak = 0;
      _wrongAnswers++;
      _saveScoreLocally();

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && !_isFinishing) {
          setState(() => _selected = null);
          _nextQuestion();
        }
      });
    }
  }

  // ─── التلميح ─────────────────────────────────────────────────────────────
  void _useHint() {
    if (_hintUsed || _current == null || _showCelebration) return;

    if (_score >= _hintCost) {
      setState(() => _score -= _hintCost);
      _grantHint();
    } else {
      // نقاط غير كافية → شاهد إعلاناً
      AdService().showRewarded(onRewarded: () {
        if (mounted) _grantHint();
      });
    }
  }

  void _grantHint() {
    if (_current == null || _hintUsed) return;
    // نختار عشوائياً إجابة خاطئة لإزالتها
    final wrongIndices = List.generate(_current!.options.length, (i) => i)
      ..removeWhere((i) => i == _current!.correctIndex);
    wrongIndices.shuffle();
    setState(() {
      _hintUsed        = true;
      _eliminatedIndex = wrongIndices.first;
    });
  }

  // ─── Celebration ─────────────────────────────────────────────────────────
  void _showCelebrationOverlay(int earned) {
    setState(() => _showCelebration = true);
    _confettiCtrl.play();

    // احتفال سريع (800ms) ثم سؤال جديد مباشرة بدون overlay انتقال
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _showCelebration = false;
        _selected        = null;
      });
      _nextQuestion();
    });
  }

  void _nextQuestion() {
    if (_isFinishing) return;
    _questionIndex++;
    _batchIndex++;

    setState(() {
      _selected        = null;
      _hintUsed        = false;
      _eliminatedIndex = null;
    });

    if (_batchIndex >= _batch.length) {
      _loadNextBatch();
    }
    // لا نحتاج startTimer هنا - المؤقت الإجمالي يعمل باستمرار
  }

  // ─── إنهاء اللعبة ─────────────────────────────────────────────────────────
  Future<void> _finishGame() async {
    if (_isFinishing) return;
    _isFinishing = true;
    _matchTimer?.cancel();

    final provider     = context.read<UserProvider>();
    final token        = provider.token;
    final currentTotal = provider.user?.totalScore ?? 0;
    await provider.updateTotalScore(currentTotal + _score);

    if (token != null) {
      try {
        final serverTotal = await _gameService.submitScore(
          categoryId:        widget.category.id,
          score:             _score,
          difficultyReached: _difficultyReached,
          token:             token,
          correctAnswers:    _correctAnswers,
          wrongAnswers:      _wrongAnswers,
        );
        await provider.updateTotalScore(serverTotal);
        await _clearLocalScore();
      } catch (_) {}
    }

    if (!mounted) return;

    final score             = _score;
    final questionsAnswered = _questionIndex;
    final difficultyReached = _difficultyReached;
    final category          = widget.category;
    final ctx               = context;

    AdService().showInterstitialBeforeAction(
      onComplete: () {
        if (!ctx.mounted) return;
        Navigator.pushReplacement(
          ctx,
          MaterialPageRoute(
            builder: (_) => ThankYouScreen(
              score:             score,
              questionsAnswered: questionsAnswered,
              difficultyReached: difficultyReached,
              category:          category,
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveScoreLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pending_score', _score);
      await prefs.setInt('pending_category', widget.category.id);
      await prefs.setInt('pending_difficulty', _difficultyReached);
    } catch (_) {}
  }

  Future<void> _clearLocalScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_score');
      await prefs.remove('pending_category');
      await prefs.remove('pending_difficulty');
    } catch (_) {}
  }

  // ─── حالة زرار الإجابة ───────────────────────────────────────────────────
  _OptionState _getOptionState(int index) {
    if (index == _eliminatedIndex) return _OptionState.eliminated;
    if (_selected == null) return _OptionState.normal;
    if (index == _selected) {
      return (index == _current!.correctIndex)
          ? _OptionState.correct
          : _OptionState.wrong;
    }
    return _OptionState.normal;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //                              BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _cBg,
        body: Center(
          child: CircularProgressIndicator(color: _cCyan, strokeWidth: 2),
        ),
      );
    }

    final question = _current;
    if (question == null) {
      return const Scaffold(
        backgroundColor: _cBg,
        body: Center(
          child: CircularProgressIndicator(color: _cCyan, strokeWidth: 2),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finishGame();
      },
      child: Scaffold(
        backgroundColor: _cBg,
        body: Stack(
          children: [

            // ─── Main content ─────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [

                  // ─── Header ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        // Back button
                        GestureDetector(
                          onTap: _finishGame,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _cCyan.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: _cCyan,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Question counter
                        Text(
                          'game.question'.tr(
                              namedArgs: {'num': '${_questionIndex + 1}'}),
                          style: const TextStyle(
                            color:      _cCyan,
                            fontSize:   15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        // XP Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color:        _cCard,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: _cCyan.withValues(alpha: 0.25),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color:      _cCyan.withValues(alpha: 0.12),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'XP ${_formatScore(_score)}',
                                style: const TextStyle(
                                  color:      Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize:   14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.star_rounded,
                                  color: _cCyan, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  // ─── Question Card ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color:        _cSurface,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          // Timer row (مؤقت إجمالي)
                          Builder(builder: (_) {
                            final isUrgent = _matchTimeLeft <= 10;
                            final fraction = _matchTimeLeft / _totalDuration;
                            return Row(
                              children: [
                                // Progress bar
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: fraction,
                                      backgroundColor: Colors.white12,
                                      valueColor: AlwaysStoppedAnimation(
                                        isUrgent ? Colors.redAccent : _cCyan,
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Circular timer
                                SizedBox(
                                  width:  52,
                                  height: 52,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value:           fraction,
                                        backgroundColor: Colors.white12,
                                        color: isUrgent
                                            ? Colors.redAccent
                                            : _cCyan,
                                        strokeWidth: 3,
                                      ),
                                      Text(
                                        '${_matchTimeLeft}s',
                                        style: TextStyle(
                                          color: isUrgent
                                              ? Colors.redAccent
                                              : Colors.white,
                                          fontSize:   13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }),

                          const SizedBox(height: 18),

                          // Question text
                          Text(
                            question.questionText,
                            textAlign:     TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              color:      Colors.white,
                              fontSize:   20,
                              fontWeight: FontWeight.bold,
                              height:     1.5,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Subtitle
                          Text(
                            'game.select_answer'.tr().toUpperCase(),
                            style: TextStyle(
                              color:         Colors.white.withValues(alpha: 0.4),
                              fontSize:      11,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  const SizedBox(height: 8),

                  // ─── Answer Options ────────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: question.options.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final key = question.options[i]['key'] ?? '?';
                          // Arabic letter badges: أ ب ج د
                          final badge = _letterBadge(i);
                          return _OptionTile(
                            text:    question.options[i]['text'] ?? '',
                            badge:   badge,
                            keyLabel: key.toUpperCase(),
                            state:   _getOptionState(i),
                            onTap:   (_showCelebration ||
                                    _getOptionState(i) ==
                                        _OptionState.eliminated)
                                ? null
                                : () => _answer(i),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ─── Hint Button ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width:  double.infinity,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: _hintUsed
                              ? null
                              : const LinearGradient(
                                  colors: [_cCyan, _cIndigo],
                                  begin: Alignment.centerLeft,
                                  end:   Alignment.centerRight,
                                ),
                          color: _hintUsed
                              ? Colors.white10
                              : null,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: _hintUsed
                              ? []
                              : [
                                  BoxShadow(
                                    color:      _cCyan.withValues(alpha: 0.25),
                                    blurRadius: 16,
                                    offset:     const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _hintUsed || _showCelebration ||
                                  _selected != null
                              ? null
                              : _useHint,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:         Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            shadowColor:             Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                            elevation: 0,
                          ),
                          icon: Icon(
                            Icons.flash_on_rounded,
                            color: _hintUsed
                                ? Colors.white30
                                : Colors.black,
                            size: 20,
                          ),
                          label: Text(
                            _hintUsed
                                ? '─'
                                : (_score >= _hintCost
                                    ? 'game.hint_btn'.tr()
                                    : 'game.hint_no_xp'.tr()),
                            style: TextStyle(
                              color: _hintUsed
                                  ? Colors.white30
                                  : Colors.black,
                              fontSize:   15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Confetti ─────────────────────────────────────────────────
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiCtrl,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 28,
                gravity: 0.25,
                colors: const [
                  _cCyan, _cIndigo, Color(0xFFFFD700),
                  Colors.white, Colors.pinkAccent,
                ],
              ),
            ),

            // ─── Celebration Overlay ───────────────────────────────────────
            if (_showCelebration)
              _CelebrationOverlay(points: _current?.points ?? 0),

            // _TransitionOverlay removed - no delay between questions
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  String _letterBadge(int i) {
    // Arabic letter badges: أ ب ج د
    const badges = ['أ', 'ب', 'ج', 'د'];
    return i < badges.length ? badges[i] : '${i + 1}';
  }

  String _formatScore(int n) {
    if (n < 1000) return '$n';
    final s   = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ─── Option States ────────────────────────────────────────────────────────────
enum _OptionState { normal, correct, wrong, eliminated }

// ─── Option Tile (pill-shaped) ────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final String        text;
  final String        badge;
  final String        keyLabel;
  final _OptionState  state;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.text,
    required this.badge,
    required this.keyLabel,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = switch (state) {
      _OptionState.correct    => const Color(0xFF1B4332),
      _OptionState.wrong      => const Color(0xFF3B1B1B),
      _OptionState.eliminated => Colors.white.withValues(alpha: 0.03),
      _OptionState.normal     => _cCard,
    };

    final Color borderColor = switch (state) {
      _OptionState.correct    => const Color(0xFF4CAF50),
      _OptionState.wrong      => Colors.redAccent,
      _OptionState.eliminated =>
          Colors.white.withValues(alpha: 0.08),
      _OptionState.normal     =>
          Colors.white.withValues(alpha: 0.08),
    };

    final Color badgeColor = switch (state) {
      _OptionState.correct    => const Color(0xFF4CAF50),
      _OptionState.wrong      => Colors.redAccent,
      _OptionState.eliminated => Colors.white24,
      _OptionState.normal     => _cCyan,
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: state == _OptionState.correct
              ? [
                  BoxShadow(
                    color:      const Color(0xFF4CAF50)
                        .withValues(alpha: 0.25),
                    blurRadius: 12,
                  )
                ]
              : [],
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              // Answer text (RTL inside LTR row)
              Expanded(
                child: Text(
                  text,
                  textDirection: TextDirection.rtl,
                  textAlign:     TextAlign.right,
                  maxLines:      2,
                  overflow:      TextOverflow.ellipsis,
                  style: TextStyle(
                    color:      state == _OptionState.eliminated
                        ? Colors.white24
                        : Colors.white,
                    fontSize:   15,
                    fontWeight: FontWeight.w500,
                    height:     1.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Letter badge
              Container(
                width:  36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeColor, width: 2),
                  color: badgeColor.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: Text(
                    badge,
                    style: TextStyle(
                      color:      badgeColor,
                      fontSize:   14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Celebration Overlay ──────────────────────────────────────────────────────
class _CelebrationOverlay extends StatelessWidget {
  final int points;
  const _CelebrationOverlay({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.60),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✅', style: TextStyle(fontSize: 90)),
            const SizedBox(height: 20),
            Text(
              'game.correct'.tr(),
              style: const TextStyle(
                color:      Colors.white,
                fontSize:   28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color:        _cCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(30),
                border:       Border.all(color: _cCyan, width: 2),
              ),
              child: Text(
                'game.points_earned'
                    .tr(namedArgs: {'points': '$points'}),
                style: const TextStyle(
                  color:      _cCyan,
                  fontSize:   22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Transition Overlay ───────────────────────────────────────────────────────
class _TransitionOverlay extends StatefulWidget {
  const _TransitionOverlay();

  @override
  State<_TransitionOverlay> createState() => _TransitionOverlayState();
}

class _TransitionOverlayState extends State<_TransitionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎯', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 20),
              Text(
                'game.next_question'.tr(),
                style: const TextStyle(
                  color:         Colors.white70,
                  fontSize:      22,
                  fontWeight:    FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(
                width:  40,
                height: 40,
                child:  CircularProgressIndicator(
                  color:       _cCyan,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
