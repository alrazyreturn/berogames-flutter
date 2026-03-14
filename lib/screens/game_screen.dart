import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart';
import '../models/question_model.dart';
import '../providers/user_provider.dart';
import '../services/game_service.dart';
import '../services/sound_service.dart';
import 'thankyou_screen.dart';

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
  static const int _streakToLevelUp = 2;  // كل 2 صح متتالي → مستوى أصعب
  static const int _secondsPerQ    = 15;  // وقت كل سؤال

  // ─── حالة اللعبة ─────────────────────────────────────────────────────────
  int  _currentDifficulty  = 1;
  int  _correctStreak      = 0;
  int  _questionIndex      = 0;   // عدد الأسئلة التي تم الإجابة عليها صح
  int  _score              = 0;
  int  _difficultyReached  = 1;
  int  _correctAnswers     = 0;   // عداد الإجابات الصحيحة
  int  _wrongAnswers       = 0;   // عداد الإجابات الخاطئة

  List<QuestionModel> _batch      = [];
  int                 _batchIndex = 0;

  bool _isLoading          = true;
  bool _showCelebration    = false; // overlay الاحتفال عند الإجابة الصح
  bool _isTransitioning    = false; // فترة الانتظار بين الأسئلة
  bool _isWaitingForRetry  = false; // بعد خطأ → ينتظر إجابة صحيحة
  bool _isFinishing        = false; // لتفادي استدعاء _finishGame مرتين
  int? _selected;                   // الخيار المختار حالياً

  // ─── Controllers ─────────────────────────────────────────────────────────
  late AnimationController _timerCtrl;
  late ConfettiController  _confettiCtrl;

  // ─── Getter السؤال الحالي ────────────────────────────────────────────────
  QuestionModel? get _current =>
      _batchIndex < _batch.length ? _batch[_batchIndex] : null;

  // ─── Init ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _timerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _secondsPerQ),
    );
    _confettiCtrl = ConfettiController(
        duration: const Duration(milliseconds: 1200));
    _initGame();
  }

  @override
  void dispose() {
    _timerCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  // ─── تهيئة: نجيب مستوى اليوزر في هذا القسم ──────────────────────────────
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

  // ─── تحميل دفعة جديدة من الأسئلة ────────────────────────────────────────
  Future<void> _loadNextBatch() async {
    setState(() => _isLoading = true);

    List<QuestionModel> questions = [];
    int tryDifficulty = _currentDifficulty;

    while (tryDifficulty >= 1 && questions.isEmpty) {
      questions = await _gameService.getQuestions(
        categoryId: widget.category.id,
        difficulty: tryDifficulty,
        limit: _batchSize,
      );
      if (questions.isEmpty) tryDifficulty--;
    }

    if (!mounted) return;

    if (questions.isEmpty) {
      // خلصت الأسئلة في قاعدة البيانات
      _finishGame();
      return;
    }

    setState(() {
      _batch             = questions;
      _batchIndex        = 0;
      _isLoading         = false;
      _isWaitingForRetry = false;
      _selected          = null;
    });
    _startTimer();
  }

  // ─── Timer لكل سؤال على حدة ──────────────────────────────────────────────
  void _startTimer() {
    _timerCtrl.reset();
    _timerCtrl.forward().then((_) {
      if (mounted && !_showCelebration && !_isLoading) _onTimeUp();
    });
  }

  // ─── انتهى الوقت = مثل الإجابة الخاطئة ──────────────────────────────────
  void _onTimeUp() {
    if (_showCelebration || _isLoading) return;
    _soundService.playWrong();
    _deductScore();
    _wrongAnswers++;
    setState(() {
      _isWaitingForRetry = true;
      _selected          = null;
    });
    _startTimer(); // نعيد الـ timer عشان يحاول تاني
  }

  // ─── اختيار إجابة ────────────────────────────────────────────────────────
  void _answer(int index) {
    if (_showCelebration || _current == null || _isLoading) return;
    _timerCtrl.stop();

    final correct = index == _current!.correctIndex;
    setState(() => _selected = index);

    if (correct) {
      // ✅ إجابة صحيحة
      _soundService.playCorrect();

      final earned = _current!.points;
      _score += earned;
      _correctStreak++;
      _correctAnswers++;
      _isWaitingForRetry = false;

      // رفع الصعوبة بعد N صح متتالي
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
      // ❌ إجابة خاطئة → نخصم ونبقى في نفس السؤال
      _soundService.playWrong();
      _deductScore();
      _correctStreak = 0;
      _wrongAnswers++;
      _saveScoreLocally();

      // نظهر الإجابة محمرة ثانية ثم نعيد الـ timer
      setState(() => _isWaitingForRetry = true);

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && !_showCelebration) {
          setState(() => _selected = null);
          _startTimer();
        }
      });
    }
  }

  // ─── خصم نقاط (الحد الأدنى 0) ───────────────────────────────────────────
  void _deductScore() {
    final deduct = (_current?.difficulty ?? 1) * 5;
    setState(() => _score = (_score - deduct).clamp(0, 999999));
  }

  // ─── Celebration overlay عند الإجابة الصحيحة ────────────────────────────
  void _showCelebrationOverlay(int earned) {
    setState(() => _showCelebration = true);
    _confettiCtrl.play();

    // 1️⃣  ينتهي الاحتفال بعد 1.2 ثانية
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _showCelebration = false;
        _isTransitioning = true; // نبدأ فترة الانتقال
        _selected        = null;
      });

      // 2️⃣  ثانية إضافية قبل ظهور السؤال الجاي
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        setState(() => _isTransitioning = false);
        _nextQuestion();
      });
    });
  }

  // ─── الانتقال للسؤال الجاي ───────────────────────────────────────────────
  void _nextQuestion() {
    _questionIndex++;
    _batchIndex++;

    setState(() {
      _selected          = null;
      _isWaitingForRetry = false;
    });

    if (_batchIndex >= _batch.length) {
      _loadNextBatch(); // حمّل دفعة جديدة
    } else {
      _startTimer();
    }
  }

  // ─── إنهاء اللعبة ─────────────────────────────────────────────────────────
  Future<void> _finishGame() async {
    if (_isFinishing) return;
    _isFinishing = true;
    _timerCtrl.stop();

    final provider = context.read<UserProvider>();
    final token    = provider.token;

    // Optimistic update: نحدث السكور فوراً
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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ThankYouScreen(
          score:             _score,
          questionsAnswered: _questionIndex,
          difficultyReached: _difficultyReached,
          category:          widget.category,
        ),
      ),
    );
  }

  // ─── حفظ النتيجة الجارية محلياً بعد كل إجابة ────────────────────────────
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

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
      );
    }

    final question = _current;
    if (question == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finishGame();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Stack(
          children: [

            // ─── المحتوى الأساسي ────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [

                  // ─── Header ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios,
                              color: Colors.white54, size: 20),
                          onPressed: _finishGame,
                        ),
                        Text(
                          'سؤال ${_questionIndex + 1}  •  ${widget.category.nameAr}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                        const Spacer(),
                        // النقاط
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF)
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '$_score',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── مستوى الصعوبة ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text('المستوى: ',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 11)),
                        ...List.generate(
                            10,
                            (i) => Container(
                                  width: 16,
                                  height: 7,
                                  margin: const EdgeInsets.only(right: 3),
                                  decoration: BoxDecoration(
                                    color: i < _currentDifficulty
                                        ? _difficultyColor(
                                            _currentDifficulty)
                                        : Colors.white12,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                )),
                        const SizedBox(width: 6),
                        Text(
                          _difficultyLabel(_currentDifficulty),
                          style: TextStyle(
                            color: _difficultyColor(_currentDifficulty),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ─── Timer Bar ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AnimatedBuilder(
                      animation: _timerCtrl,
                      builder: (_, __) {
                        final remaining =
                            (_secondsPerQ * (1 - _timerCtrl.value)).ceil();
                        final isUrgent = remaining <= 5;
                        return Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: 1 - _timerCtrl.value,
                                backgroundColor: Colors.white12,
                                color: isUrgent
                                    ? Colors.redAccent
                                    : Colors.greenAccent,
                                minHeight: 7,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${remaining}s',
                                style: TextStyle(
                                  color: isUrgent
                                      ? Colors.redAccent
                                      : Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ─── رسالة "حاول مجدداً" ──────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isWaitingForRetry
                        ? Container(
                            key: const ValueKey('retry'),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.redAccent
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.redAccent
                                      .withValues(alpha: 0.5)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.refresh,
                                    color: Colors.redAccent, size: 15),
                                SizedBox(width: 8),
                                Text(
                                  'إجابة خاطئة! حاول مجدداً 💪',
                                  style: TextStyle(
                                      color: Colors.redAccent, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(key: ValueKey('empty'), height: 0),
                  ),

                  const SizedBox(height: 8),

                  // ─── نص السؤال ─────────────────────────────────────────
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Center(
                          child: Text(
                            question.questionText,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ─── خيارات الإجابة ─────────────────────────────────────
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        physics: const NeverScrollableScrollPhysics(),
                        children: List.generate(question.options.length,
                            (i) {
                          return _OptionButton(
                            text: question.options[i]['text']!,
                            label: question.options[i]['key']!
                                .toUpperCase(),
                            state: _getOptionState(i),
                            // لو عندنا احتفال → نوقف الضغط
                            onTap: _showCelebration
                                ? null
                                : () => _answer(i),
                          );
                        }),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ─── Confetti يطلع من فوق ────────────────────────────────────
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiCtrl,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 28,
                gravity: 0.25,
                colors: const [
                  Color(0xFF6C63FF),
                  Color(0xFFFFD700),
                  Color(0xFF4CAF50),
                  Colors.white,
                  Colors.pinkAccent,
                  Colors.cyanAccent,
                ],
              ),
            ),

            // ─── Celebration Overlay ──────────────────────────────────────
            if (_showCelebration)
              _CelebrationOverlay(points: _current?.points ?? 0),

            // ─── Transition Overlay (بين الأسئلة) ────────────────────────
            if (_isTransitioning)
              const _TransitionOverlay(),
          ],
        ),
      ),
    );
  }

  // ─── حالة زرار الإجابة ───────────────────────────────────────────────────
  _OptionState _getOptionState(int index) {
    if (_selected == null) return _OptionState.normal;
    if (index == _selected) {
      return (index == _current!.correctIndex)
          ? _OptionState.correct
          : _OptionState.wrong;
    }
    return _OptionState.normal;
  }

  Color _difficultyColor(int d) {
    if (d <= 3) return Colors.greenAccent;
    if (d <= 6) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _difficultyLabel(int d) {
    if (d <= 3) return 'سهل';
    if (d <= 6) return 'متوسط';
    return 'صعب';
  }
}

// ─── Celebration Overlay Widget ──────────────────────────────────────────────
class _CelebrationOverlay extends StatelessWidget {
  final int points;
  const _CelebrationOverlay({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✅', style: TextStyle(fontSize: 90)),
            const SizedBox(height: 20),
            const Text(
              'إجابة صحيحة!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                    color: const Color(0xFFFFD700), width: 2),
              ),
              child: Text(
                '+$points نقطة ⭐',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 24,
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

// ─── Transition Overlay بين الأسئلة ──────────────────────────────────────────
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
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🎯', style: TextStyle(fontSize: 60)),
              SizedBox(height: 20),
              Text(
                'السؤال القادم...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Color(0xFF6C63FF),
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

// ─── حالات زرار الإجابة ──────────────────────────────────────────────────────
enum _OptionState { normal, correct, wrong }

// ─── Widget زرار الإجابة ─────────────────────────────────────────────────────
class _OptionButton extends StatelessWidget {
  final String        text;
  final String        label;
  final _OptionState  state;
  final VoidCallback? onTap; // nullable: null = disabled أثناء الاحتفال

  const _OptionButton({
    required this.text,
    required this.label,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = switch (state) {
      _OptionState.correct => const Color(0xFF4CAF50),
      _OptionState.wrong   => const Color(0xFFF44336),
      _OptionState.normal  => Colors.white.withValues(alpha: 0.07),
    };

    final Color borderColor = switch (state) {
      _OptionState.correct => const Color(0xFF4CAF50),
      _OptionState.wrong   => const Color(0xFFF44336),
      _OptionState.normal  => Colors.white12,
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
