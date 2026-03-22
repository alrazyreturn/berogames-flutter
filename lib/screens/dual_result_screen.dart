import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../providers/user_provider.dart';
import '../services/friends_service.dart';
import '../models/friend_model.dart';
import '../config/api_config.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
import 'dual_menu_screen.dart';
import 'leaderboard_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';

// ─── Design tokens (Neon-Glass Editorial — matches dual_game_screen) ──────────
const _cBg      = Color(0xFF0B1326);
const _cSurface = Color(0xFF131B2E);
const _cCard    = Color(0xFF171F33);
const _cCyan    = Color(0xFF00FBFB);
const _cNavBg   = Color(0xFF10102B);
const _cPink    = Color(0xFFFF6B8A);
const _cIndigo  = Color(0xFF6366F1);

/// شاشة النتيجة النهائية للعب الثنائي
class DualResultScreen extends StatefulWidget {
  final String  myName;
  final String? myAvatar;
  final String  opponentName;
  final String? opponentAvatar;
  final int     myScore;
  final int     opponentScore;
  final String  winner;      // 'host' | 'guest' | 'draw'
  final String  myRole;      // 'host' | 'guest'
  final int?    opponentId;  // null = بوت أو غير معروف
  final bool    isBot;

  const DualResultScreen({
    super.key,
    required this.myName,
    this.myAvatar,
    required this.opponentName,
    this.opponentAvatar,
    required this.myScore,
    required this.opponentScore,
    required this.winner,
    required this.myRole,
    this.opponentId,
    this.isBot = false,
  });

  @override
  State<DualResultScreen> createState() => _DualResultScreenState();
}

class _DualResultScreenState extends State<DualResultScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confetti;
  late AnimationController _scaleCtrl;
  late Animation<double>   _scaleAnim;

  // ─── حالة الصداقة ────────────────────────────────────────────────────────
  final _friendsService = FriendsService();
  String _followStatus  = 'loading';
  bool   _followLoading = false;

  bool get _iWon        => widget.myRole == widget.winner;
  bool get _isDraw      => widget.winner == 'draw';
  bool get _opponentWon => !_iWon && !_isDraw;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 5));
    if (_iWon || _isDraw) _confetti.play();

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _scaleCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFollowStatus();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _scaleCtrl.dispose();
    super.dispose();
  }

  // ─── جلب حالة الصداقة ────────────────────────────────────────────────────
  Future<void> _loadFollowStatus() async {
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

  // ─── الضغط على زر الصداقة ────────────────────────────────────────────────
  Future<void> _onFollowTap() async {
    if (widget.isBot || widget.opponentId == null || _followLoading) return;
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    setState(() => _followLoading = true);
    try {
      final result    = await _friendsService.followByUserId(widget.opponentId!, token);
      final newStatus = result['status'] as String? ?? 'pending_sent';
      if (!mounted) return;
      setState(() => _followStatus = newStatus);
      final msg = newStatus == 'accepted'
          ? '🎉 أصبحتما أصدقاء!'
          : '✅ تم إرسال طلب المتابعة';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: newStatus == 'accepted'
            ? Colors.greenAccent.withValues(alpha: 0.9)
            : _cCyan.withValues(alpha: 0.9),
        duration: const Duration(seconds: 2),
      ));
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

  @override
  Widget build(BuildContext context) {
    final resultColor = _isDraw
        ? Colors.amber
        : (_iWon ? _cCyan : _cPink);

    return Scaffold(
      backgroundColor: _cBg,
      bottomNavigationBar: _buildBottomNav(),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          // ─── Confetti ────────────────────────────────────────────────────
          ConfettiWidget(
            confettiController:  _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles:   30,
            colors: [_cCyan, _cPink, Colors.amber, Colors.white],
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
              child: Column(
                children: [
                  // ─── أيقونة النتيجة ──────────────────────────────────────
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: resultColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: resultColor.withValues(alpha: 0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: resultColor.withValues(alpha: 0.25),
                            blurRadius: 32,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _isDraw ? '🤝' : (_iWon ? '🏆' : '😔'),
                          style: const TextStyle(fontSize: 46),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── عنوان النتيجة ───────────────────────────────────────
                  Text(
                    _isDraw
                        ? 'dual_result.draw'.tr()
                        : (_iWon
                            ? 'dual_result.won'.tr()
                            : 'dual_result.lost'.tr()),
                    style: TextStyle(
                      color:      resultColor,
                      fontSize:   28,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color:      resultColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── بطاقة المقارنة مع الأفاتار ─────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    decoration: BoxDecoration(
                      color:        _cCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:      Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset:     const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // أنا
                        Expanded(
                          child: _PlayerResult(
                            name:     widget.myName,
                            avatar:   widget.myAvatar,
                            score:    widget.myScore,
                            isWinner: _iWon,
                            color:    _cCyan,
                          ),
                        ),

                        // VS
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _cSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Text(
                              'VS',
                              style: TextStyle(
                                color:         Colors.white.withValues(alpha: 0.25),
                                fontSize:      13,
                                fontWeight:    FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),

                        // الخصم
                        Expanded(
                          child: _PlayerResult(
                            name:     widget.opponentName,
                            avatar:   widget.opponentAvatar,
                            score:    widget.opponentScore,
                            isWinner: _opponentWon,
                            color:    _cPink,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── أزرار الصداقة والرسالة ──────────────────────────────
                  const SizedBox(height: 20),
                  _buildFriendButton(),
                  // يظهر زر الرسالة دائماً (بوت أو لاعب حقيقي)
                  const SizedBox(height: 12),
                  _buildMessageButton(),

                  const SizedBox(height: 20),

                  // ─── الأزرار ────────────────────────────────────────────
                  Row(
                    children: [
                      // زر الرئيسية
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HomeScreen()),
                            (_) => false,
                          ),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              color: _cSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              'dual_result.home_btn'.tr(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color:      Colors.white70,
                                fontSize:   15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // زر العب مجدداً (gradient)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const DualMenuScreen()),
                          ),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _cCyan.withValues(alpha: 0.85),
                                  _cIndigo,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:      _cCyan.withValues(alpha: 0.2),
                                  blurRadius: 14,
                                  offset:     const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('⚔️', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  'dual_result.play_again'.tr(),
                                  style: const TextStyle(
                                    color:      Colors.white,
                                    fontSize:   15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── زر الصداقة ──────────────────────────────────────────────────────────
  Widget _buildFriendButton() {
    // للبوت: يُعرض الزر دائماً لكن معطّل تماماً
    // للبوت: يبدو كـ "تم إرسال الطلب" بدون تأثير حقيقي
    if (widget.isBot || widget.opponentId == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color:        Colors.amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.55), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.amber.withValues(alpha: 0.2), blurRadius: 18),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            Text(
              'dual_result.pending_sent'.tr(),
              style: const TextStyle(color: Colors.amber, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    // للاعب حقيقي: الزر الكامل
    final bool isAccepted = _followStatus == 'accepted';
    final bool isPending  = _followStatus == 'pending_sent' || _followStatus == 'pending_received';
    final bool canFollow  = _followStatus == 'none';
    final bool isLoading  = _followStatus == 'loading' || _followLoading;

    final Color btnColor = isAccepted
        ? Colors.greenAccent
        : isPending
            ? Colors.white38
            : _cCyan;

    final String label = isLoading
        ? 'common.loading'.tr()
        : isAccepted
            ? 'dual_result.friends'.tr()
            : _followStatus == 'pending_received'
                ? 'dual_result.accept_request'.tr()
                : isPending
                    ? 'dual_result.pending_sent'.tr()
                    : 'dual_result.add_friend'.tr();

    final IconData icon = isAccepted
        ? Icons.people_rounded
        : isPending
            ? Icons.hourglass_top_rounded
            : Icons.person_add_rounded;

    return GestureDetector(
      onTap: canFollow && !isLoading ? _onFollowTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isAccepted
              ? Colors.greenAccent.withValues(alpha: 0.08)
              : isPending
                  ? _cSurface
                  : _cCyan.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: btnColor.withValues(
                alpha: isAccepted ? 0.6 : canFollow ? 0.7 : 0.25),
            width: 1.5,
          ),
          boxShadow: canFollow
              ? [BoxShadow(color: _cCyan.withValues(alpha: 0.3), blurRadius: 22, spreadRadius: 1)]
              : isAccepted
                  ? [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.2), blurRadius: 18)]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: _cCyan),
              )
            else
              Icon(icon, color: btnColor, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color:      btnColor,
                fontSize:   15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── زر الرسالة — يفتح شاشة الشات مباشرةً ───────────────────────────────
  // ─── فتح الشات (مع جلب ID البوت تلقائياً إذا كان null) ──────────────────────
  Future<void> _openChat() async {
    int?    chatId     = widget.opponentId;
    String? chatAvatar = widget.opponentAvatar;

    // إذا لم يصل opponent_id من السيرفر (سيرفر قديم) → اجلبه من /auth/bot-info
    if (chatId == null && widget.isBot) {
      try {
        final dio = Dio();
        final r   = await dio.get('${ApiConfig.baseUrl}${ApiConfig.botInfo}');
        chatId     = r.data['id']     as int?;
        chatAvatar = r.data['avatar'] as String?;
      } catch (_) {}
    }

    if (chatId == null || !mounted) return;

    final friend = FriendModel(
      friendshipId: 0,
      userId:       chatId,
      name:         widget.opponentName,
      avatar:       chatAvatar ?? widget.opponentAvatar,
      totalScore:   0,
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(friend: friend)));
  }

  Widget _buildMessageButton() {
    return GestureDetector(
      onTap: _openChat,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color:        const Color(0xFF6366F1).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.65),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color:      const Color(0xFF6366F1).withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_rounded, color: Color(0xFF6366F1), size: 20),
            const SizedBox(width: 10),
            Text(
              'dual_result.message_btn'.tr(),
              style: const TextStyle(
                color:      Color(0xFF6366F1),
                fontSize:   15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom Navigation ────────────────────────────────────────────────────
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
                onTap:    () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (_) => false),
              ),
              _NavItem(
                icon:     Icons.leaderboard_rounded,
                label:    'home.nav_ranking'.tr(),
                isActive: false,
                onTap:    () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen())),
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
                    MaterialPageRoute(
                        builder: (_) => const ProfileScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── بطاقة نتيجة لاعب مع أفاتار نيون ────────────────────────────────────────
class _PlayerResult extends StatelessWidget {
  final String  name;
  final String? avatar;
  final int     score;
  final bool    isWinner;
  final Color   color;

  const _PlayerResult({
    required this.name,
    required this.score,
    required this.isWinner,
    required this.color,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── تاج الفائز ─────────────────────────────────────────────────
        if (isWinner)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('👑', style: TextStyle(fontSize: 22)),
          )
        else
          const SizedBox(height: 30),

        // ─── أفاتار مع توهج نيون ────────────────────────────────────────
        Container(
          width: 68, height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: isWinner ? 0.85 : 0.4),
              width: isWinner ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color:        color.withValues(alpha: isWinner ? 0.55 : 0.15),
                blurRadius:   isWinner ? 24 : 10,
                spreadRadius: isWinner ? 3  : 0,
              ),
            ],
          ),
          child: ClipOval(
            child: avatar != null && avatar!.isNotEmpty
                ? Image.network(
                    avatar!,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, e, st) =>
                        _AvatarFallback(name: name, color: color),
                  )
                : _AvatarFallback(name: name, color: color),
          ),
        ),

        const SizedBox(height: 10),

        // ─── اسم اللاعب ─────────────────────────────────────────────────
        Text(
          name,
          style: TextStyle(
            color:      color,
            fontWeight: FontWeight.bold,
            fontSize:   12,
            shadows: isWinner
                ? [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                : null,
          ),
          overflow:  TextOverflow.ellipsis,
          maxLines:  1,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        // ─── النقاط ─────────────────────────────────────────────────────
        Text(
          '$score',
          style: TextStyle(
            color:      Colors.white,
            fontSize:   32,
            fontWeight: FontWeight.bold,
            shadows: isWinner
                ? [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 12)]
                : null,
          ),
        ),

        Text(
          'common.points_unit'.tr(),
          style: TextStyle(
            color:    Colors.white.withValues(alpha: 0.35),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ─── صورة بديلة — أول حرف من الاسم ──────────────────────────────────────────
class _AvatarFallback extends StatelessWidget {
  final String name;
  final Color  color;
  const _AvatarFallback({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0] : '؟',
          style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ─── Nav Item ─────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _cCyan : Colors.white38;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Container(
                width: 28, height: 3,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: _cCyan,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(color: _cCyan.withValues(alpha: 0.5), blurRadius: 6),
                  ],
                ),
              ),
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color:    color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
