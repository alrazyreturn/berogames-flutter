import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../providers/user_provider.dart';
import '../config/api_config.dart';
import 'package:dio/dio.dart';
import 'home_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';
import '../widgets/user_profile_sheet.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const _cBg      = Color(0xFF0B1326);
const _cSurface = Color(0xFF131B2E);
const _cCard    = Color(0xFF171F33);
const _cCyan    = Color(0xFF00FBFB);
const _cIndigo  = Color(0xFF6366F1);
const _cNavBg   = Color(0xFF10102B);

// ─── Main Screen ──────────────────────────────────────────────────────────────
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  List<Map<String, dynamic>> _players = [];
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res   = await _dio.get(ApiConfig.leaderboard);
      final List<Map<String, dynamic>> players =
          List<Map<String, dynamic>>.from(res.data);

      setState(() {
        _players = players;
        _loading = false;
      });
    } catch (_) {
      setState(() { _error = 'leaderboard.load_error'.tr(); _loading = false; });
    }
  }

  void _showPlayerProfile(Map<String, dynamic> player) {
    final currentUser = context.read<UserProvider>().user;
    final isMe = currentUser != null && '${player['id']}' == '${currentUser.id}';
    if (isMe) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => UserProfileSheet(
        userId: (player['id'] as num).toInt(),
        name:   (player['name'] as String?) ?? '',
        avatar: player['avatar'] as String?,
        score:  (player['total_score'] as num?)?.toInt(),
      ),
    );
  }

  // ─── Bottom Nav ───────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _cNavBg,
        boxShadow: [
          BoxShadow(
            color: _cCyan.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon:   Icons.home_rounded,
                label:  'home.nav_home'.tr(),
                active: false,
                onTap:  () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const HomeScreen())),
              ),
              _NavItem(
                icon:   Icons.leaderboard_rounded,
                label:  'home.nav_ranking'.tr(),
                active: true,
                onTap:  () {},
              ),
              _NavItem(
                icon:   Icons.people_rounded,
                label:  'home.nav_friends'.tr(),
                active: false,
                onTap:  () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const FriendsScreen())),
              ),
              _NavItem(
                icon:   Icons.person_rounded,
                label:  'home.nav_profile'.tr(),
                active: false,
                onTap:  () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<UserProvider>().user;

    return Scaffold(
      backgroundColor: _cBg,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // زر تحديث / رجوع
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _cSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: _cCyan,
                        size: 18,
                      ),
                    ),
                  ),
                  // العنوان
                  Text(
                    'leaderboard.title'.tr(),
                    style: const TextStyle(
                      color: _cCyan,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            // ─── المحتوى ────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _cCyan))
                  : _error != null
                      ? _buildError()
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: _cCyan,
                          backgroundColor: _cSurface,
                          child: CustomScrollView(
                            slivers: [
                              // ─── البوديوم ─────────────────────────────
                              if (_players.length >= 3)
                                SliverToBoxAdapter(
                                  child: _TopThreePodium(
                                    players:       _players.take(3).toList(),
                                    onAvatarTap:   _showPlayerProfile,
                                    currentUserId: '${currentUser?.id ?? ''}',
                                  ),
                                ),

                              // ─── عناوين الأعمدة ───────────────────────
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'leaderboard.col_points'.tr(),
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 12),
                                      ),
                                      Text(
                                        'leaderboard.col_player'.tr(),
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // ─── قائمة اللاعبين ────────────────────────
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (ctx, i) {
                                    final startIndex =
                                        _players.length >= 3 ? 3 : 0;
                                    final p = _players[startIndex + i];
                                    final isMe = currentUser != null &&
                                        p['id'] == currentUser.id;
                                    return _PlayerRow(
                                      player:      p,
                                      isMe:        isMe,
                                      onAvatarTap: _showPlayerProfile,
                                    );
                                  },
                                  childCount: _players.length >= 3
                                      ? _players.length - 3
                                      : _players.length,
                                ),
                              ),

                              const SliverToBoxAdapter(
                                  child: SizedBox(height: 24)),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, color: Colors.white38, size: 60),
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(
              backgroundColor: _cIndigo,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('common.retry'.tr()),
          ),
        ],
      ),
    );
  }
}

// ─── Nav Item ─────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final bool         active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: active
                ? BoxDecoration(
                    color: _cCyan,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _cCyan.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  )
                : null,
            child: Icon(
              icon,
              color: active ? _cNavBg : Colors.white38,
              size: 24,
            ),
          ),
          if (!active) ...[
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10)),
          ],
        ],
      ),
    );
  }
}

// ─── بوديوم أعلى 3 ────────────────────────────────────────────────────────────
class _TopThreePodium extends StatelessWidget {
  final List<Map<String, dynamic>>          players;
  final void Function(Map<String, dynamic>) onAvatarTap;
  final String                              currentUserId;

  const _TopThreePodium({
    required this.players,
    required this.onAvatarTap,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    // ترتيب العرض: 3rd (يسار) | 1st (وسط مرتفع) | 2nd (يمين)
    const displayOrder = [2, 0, 1];
    const ringColors   = [
      Color(0xFFCD7F32), // برونز - 3rd
      _cCyan,            // سيان  - 1st
      Color(0xFFC0C0C0), // فضة   - 2nd
    ];
    const badgeColors = [
      Color(0xFFCD7F32),
      _cCyan,
      Color(0xFF9CA3AF),
    ];
    const radii = [26.0, 40.0, 30.0];
    const ranks = [3, 1, 2];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          final idx       = displayOrder[i];
          if (idx >= players.length) return const Expanded(child: SizedBox());
          final p         = players[idx];
          final name      = (p['name']        as String?) ?? '';
          final avatarUrl = (p['avatar']       as String?);
          final score     = (p['total_score']  as num?)?.toInt() ?? 0;
          final isMe      = '${p['id']}' == currentUserId;
          final isFirst   = i == 1;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // نجمة أعلى المركز الأول
                if (isFirst)
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _cCyan,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _cCyan.withValues(alpha: 0.55),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.star_rounded,
                        color: _cNavBg, size: 20),
                  ),
                if (isFirst) const SizedBox(height: 6),

                // أفاتار مع حلقة ملونة
                GestureDetector(
                  onTap: isMe ? null : () => onAvatarTap(p),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // الحلقة + الأفاتار
                      Container(
                        padding: EdgeInsets.all(isFirst ? 3.5 : 2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ringColors[i],
                            width: isFirst ? 3 : 2,
                          ),
                          boxShadow: isFirst
                              ? [
                                  BoxShadow(
                                    color: ringColors[i].withValues(alpha: 0.5),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                  )
                                ]
                              : [],
                        ),
                        child: CircleAvatar(
                          radius: radii[i],
                          backgroundColor:
                              ringColors[i].withValues(alpha: 0.18),
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: ringColors[i],
                                    fontSize: radii[i] * 0.6,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      // شارة الترتيب
                      Positioned(
                        bottom: -10,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: badgeColors[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: _cBg, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              '${ranks[i]}',
                              style: const TextStyle(
                                color: _cBg,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // الاسم
                Text(
                  name.length > 8 ? '${name.substring(0, 8)}..' : name,
                  style: TextStyle(
                    color: isFirst ? _cCyan : Colors.white,
                    fontSize: isFirst ? 14 : 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),

                // النقاط
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fmt(score),
                      style: TextStyle(
                        color: isFirst ? _cCyan : Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.star_rounded,
                      color: isFirst ? _cCyan : Colors.white38,
                      size: 13,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        }),
      ),
    );
  }

  static String _fmt(int s) {
    if (s >= 1000) {
      final k = s ~/ 1000;
      final r = s % 1000;
      return r == 0 ? '$k,000' : '$k,${r.toString().padLeft(3, '0')}';
    }
    return '$s';
  }
}

// ─── صف لاعب ──────────────────────────────────────────────────────────────────
class _PlayerRow extends StatelessWidget {
  final Map<String, dynamic>                player;
  final bool                                isMe;
  final void Function(Map<String, dynamic>) onAvatarTap;

  const _PlayerRow({
    required this.player,
    required this.isMe,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final rank      = (player['rank']        as num?)?.toInt() ?? 0;
    final name      = (player['name']        as String?) ?? '';
    final score     = (player['total_score'] as num?)?.toInt() ?? 0;
    final avatarUrl = (player['avatar']      as String?);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: isMe
            ? _cCyan.withValues(alpha: 0.07)
            : _cCard,
        borderRadius: BorderRadius.circular(16),
        border: isMe
            ? Border.all(color: _cCyan, width: 1.5)
            : null,
        boxShadow: isMe
            ? [
                BoxShadow(
                  color: _cCyan.withValues(alpha: 0.12),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              ]
            : [],
      ),
      child: Row(
        children: [
          // ⭐ النقاط (يسار الشاشة في RTL)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                color: isMe ? _cCyan : Colors.white38,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '$score',
                style: TextStyle(
                  color: isMe ? _cCyan : Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const Spacer(),

          // الاسم
          Text(
            isMe ? '${'leaderboard.me'.tr()} ($name)' : name,
            style: TextStyle(
              color: isMe ? _cCyan : Colors.white70,
              fontSize: 14,
              fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
            ),
          ),

          const SizedBox(width: 12),

          // الأفاتار
          GestureDetector(
            onTap: isMe ? null : () => onAvatarTap(player),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isMe ? _cCyan : Colors.white12,
                      width: 1.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: isMe
                        ? _cCyan.withValues(alpha: 0.15)
                        : Colors.white10,
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: isMe ? _cCyan : Colors.white60,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                // نقطة خضراء (أنا فقط)
                if (isMe)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: _cBg, width: 1.5),
                      ),
                    ),
                  ),
                // أيقونة إضافة صديق (للآخرين)
                if (!isMe)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _cIndigo,
                        shape: BoxShape.circle,
                        border: Border.all(color: _cBg, width: 1.5),
                      ),
                      child: const Icon(Icons.person_add,
                          size: 8, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // رقم الترتيب (يمين الشاشة في RTL)
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: TextStyle(
                color: isMe ? _cCyan : Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

