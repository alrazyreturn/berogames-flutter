import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../providers/user_provider.dart';
import '../config/api_config.dart';
import 'package:dio/dio.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  List<Map<String, dynamic>> _players = [];
  Map<String, dynamic>?      _myRank;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = context.read<UserProvider>().token;

      // جلب المتصدرين
      final res = await _dio.get(ApiConfig.leaderboard);
      final List<Map<String, dynamic>> players =
          List<Map<String, dynamic>>.from(res.data);

      // جلب ترتيب اليوزر الحالي
      Map<String, dynamic>? myRank;
      if (token != null) {
        final myRes = await _dio.get(
          ApiConfig.myRank,
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        myRank = myRes.data as Map<String, dynamic>;
      }

      setState(() {
        _players = players;
        _myRank  = myRank;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'leaderboard.load_error'.tr(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<UserProvider>().user;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'leaderboard.title'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // زر تحديث
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white54),
                    onPressed: _load,
                  ),
                ],
              ),
            ),

            // ─── ترتيبي الحالي ────────────────────────────────────────
            if (_myRank != null && !_loading)
              _MyRankBanner(
                rank:       (_myRank!['rank'] as num?)?.toInt() ?? 0,
                score:      (_myRank!['total_score'] as num?)?.toInt() ?? 0,
                name:       currentUser?.name ?? '',
                avatarUrl:  currentUser?.avatar,
              ),

            // ─── القائمة ──────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFFFD700)))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wifi_off,
                                  color: Colors.white38, size: 60),
                              const SizedBox(height: 12),
                              Text(_error!,
                                  style: const TextStyle(
                                      color: Colors.white54)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _load,
                                child: Text('common.retry'.tr()),
                              ),
                            ],
                          ),
                        )
                      : _players.isEmpty
                          ? Center(
                              child: Text('leaderboard.no_players'.tr(),
                                  style: const TextStyle(color: Colors.white38)))
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: const Color(0xFFFFD700),
                              child: CustomScrollView(
                                slivers: [
                                  // ─── بودم أعلى 3 ─────────────────
                                  if (_players.length >= 3)
                                    SliverToBoxAdapter(
                                      child: _TopThreePodium(
                                          players: _players.take(3).toList()),
                                    ),

                                  const SliverToBoxAdapter(
                                      child: SizedBox(height: 16)),

                                  // ─── باقي اللاعبين ────────────────
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (ctx, i) {
                                        final startIndex =
                                            _players.length >= 3 ? 3 : 0;
                                        final p = _players[startIndex + i];
                                        final isMe = currentUser != null &&
                                            p['id'] == currentUser.id;
                                        return _PlayerRow(
                                          player: p,
                                          isMe:   isMe,
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
}

// ─── أفاتار مشترك (صورة أو حرف) ──────────────────────────────────────────────
class _UserAvatar extends StatelessWidget {
  final String  name;
  final String? avatarUrl;
  final double  radius;
  final Color   color;

  const _UserAvatar({
    required this.name,
    required this.radius,
    required this.color,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.25),
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      child: avatarUrl == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: color,
                fontSize: radius * 0.75,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}

// ─── بانر ترتيبي ──────────────────────────────────────────────────────────────
class _MyRankBanner extends StatelessWidget {
  final int rank, score;
  final String  name;
  final String? avatarUrl;
  const _MyRankBanner(
      {required this.rank, required this.score, required this.name,
       this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3D5AF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _UserAvatar(
            name:      name,
            avatarUrl: avatarUrl,
            radius:    22,
            color:     Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  'leaderboard.my_rank'.tr(),
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rank > 0 ? '#$rank' : '-',
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                '$score ${'common.points_unit'.tr()}',
                style:
                    const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── منصة أعلى 3 ──────────────────────────────────────────────────────────────
class _TopThreePodium extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  const _TopThreePodium({required this.players});

  @override
  Widget build(BuildContext context) {
    // الترتيب: 2 , 1 (منتصف مرتفع) , 3
    final order = [1, 0, 2]; // indices
    final medals  = ['🥈', '🥇', '🥉'];
    final heights = [90.0, 120.0, 70.0];
    final colors  = [
      const Color(0xFFC0C0C0), // فضة
      const Color(0xFFFFD700), // ذهب
      const Color(0xFFCD7F32), // برونز
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final idx = order[i];
          if (idx >= players.length) return const SizedBox.shrink();
          final p         = players[idx];
          final name      = (p['name']   as String?) ?? '';
          final avatarUrl = (p['avatar'] as String?);

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // إيموجي الميدالية
                Text(medals[i], style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 4),
                // أفاتار
                _UserAvatar(
                  name:      name,
                  avatarUrl: avatarUrl,
                  radius:    i == 1 ? 30 : 24,
                  color:     colors[i],
                ),
                const SizedBox(height: 6),
                // الاسم
                Text(
                  name.length > 8 ? '${name.substring(0, 8)}..' : name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                // النقاط
                Text(
                  '${(p['total_score'] as num?)?.toInt() ?? 0}',
                  style: TextStyle(color: colors[i], fontSize: 13),
                ),
                const SizedBox(height: 6),
                // القاعدة
                Container(
                  height: heights[i],
                  decoration: BoxDecoration(
                    color: colors[i].withValues(alpha: 0.15),
                    borderRadius: const BorderRadius.only(
                      topLeft:  Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                    border: Border.all(
                        color: colors[i].withValues(alpha: 0.4)),
                  ),
                  child: Center(
                    child: Text(
                      '#${(p['rank'] as num?)?.toInt() ?? idx + 1}',
                      style: TextStyle(
                          color: colors[i],
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── صف لاعب ──────────────────────────────────────────────────────────────────
class _PlayerRow extends StatelessWidget {
  final Map<String, dynamic> player;
  final bool isMe;
  const _PlayerRow({required this.player, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final rank      = (player['rank']        as num?)?.toInt() ?? 0;
    final name      = (player['name']        as String?) ?? '';
    final score     = (player['total_score'] as num?)?.toInt() ?? 0;
    final avatarUrl = (player['avatar']      as String?);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF6C63FF).withValues(alpha: 0.2)
            : const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(14),
        border: isMe
            ? Border.all(color: const Color(0xFF6C63FF), width: 1.5)
            : Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // رقم الترتيب
          SizedBox(
            width: 36,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: isMe ? const Color(0xFF6C63FF) : Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // أفاتار
          _UserAvatar(
            name:      name,
            avatarUrl: avatarUrl,
            radius:    18,
            color:     isMe ? const Color(0xFF6C63FF) : Colors.white60,
          ),
          const SizedBox(width: 12),
          // الاسم
          Expanded(
            child: Text(
              isMe ? '$name ${'leaderboard.me'.tr()}' : name,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          // النقاط
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 14),
              const SizedBox(width: 4),
              Text(
                '$score',
                style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
