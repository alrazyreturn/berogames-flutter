import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../providers/user_provider.dart';
import '../services/game_service.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const _cBg      = Color(0xFF0B1326);
const _cSurface = Color(0xFF131B2E);
const _cCard    = Color(0xFF171F33);
const _cCyan    = Color(0xFF00FBFB);
const _cIndigo  = Color(0xFF6366F1);
const _cNavBg   = Color(0xFF10102B);

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _gameService = GameService();

  Map<String, dynamic>? _stats;
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
      final token = context.read<UserProvider>().token;
      if (token == null) throw Exception('غير مسجل');
      final data = await _gameService.getStats(token: token);
      setState(() { _stats = data; _loading = false; });
    } catch (_) {
      setState(() { _error = 'stats.load_error'.tr(); _loading = false; });
    }
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
                active: false,
                onTap:  () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
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
                active: true,
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
    final user = context.read<UserProvider>().user;

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
                  // زر الرجوع
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
                    'stats.title'.tr(),
                    style: const TextStyle(
                      color: _cCyan,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  // زر تحديث
                  GestureDetector(
                    onTap: _load,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _cSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white54,
                        size: 18,
                      ),
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
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: [
                              // ── بطاقة الملف الشخصي ───────────────────
                              _buildProfileCard(
                                  user?.name ?? '', user?.avatar),

                              const SizedBox(height: 20),

                              // ── اللعب الفردي ──────────────────────────
                              _buildSectionTitle(
                                  Icons.videogame_asset_rounded, 'stats.solo'.tr()),
                              const SizedBox(height: 12),
                              _buildSoloStats(),

                              const SizedBox(height: 20),

                              // ── نسبة الدقة ────────────────────────────
                              _buildAccuracyCard(),

                              const SizedBox(height: 20),

                              // ── اللعب الثنائي ─────────────────────────
                              _buildSectionTitle(
                                  Icons.people_rounded, 'stats.dual'.tr()),
                              const SizedBox(height: 12),
                              _buildMultiStats(),

                              const SizedBox(height: 20),

                              // ── تقدم الأقسام ──────────────────────────
                              _buildSectionTitle(
                                  Icons.auto_graph_rounded,
                                  'stats.progress'.tr()),
                              const SizedBox(height: 12),
                              _buildCategoryProgress(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── بطاقة الملف الشخصي ──────────────────────────────────────────────────
  Widget _buildProfileCard(String name, String? avatarUrl) {
    final rank  = (_stats?['rank']        as num?)?.toInt();
    final score = (_stats?['total_score'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cCyan.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: _cCyan.withValues(alpha: 0.07),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // أفاتار مع حلقة سيان
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _cCyan, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _cCyan.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: _cCyan.withValues(alpha: 0.12),
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: _cCyan,
                          fontSize: 26,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      '$score ${'common.points_unit'.tr()}',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // رقم الترتيب
          if (rank != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _cCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _cCyan.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    '#$rank',
                    style: const TextStyle(
                        color: _cCyan,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'stats.rank'.tr(),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── عنوان قسم ───────────────────────────────────────────────────────────
  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: _cCyan, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: _cCyan,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _cCyan.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── إحصائيات اللعب الفردي ───────────────────────────────────────────────
  Widget _buildSoloStats() {
    final games     = (_stats?['total_solo_games'] as num?)?.toInt() ?? 0;
    final correct   = (_stats?['total_correct']    as num?)?.toInt() ?? 0;
    final wrong     = (_stats?['total_wrong']       as num?)?.toInt() ?? 0;
    final bestScore = (_stats?['best_solo_score']   as num?)?.toInt() ?? 0;
    final bestCatMap = _stats?['best_category'] as Map<String, dynamic>?;
    final lang       = context.locale.languageCode;
    final bestCat    = bestCatMap == null
        ? null
        : (lang == 'en'
                ? (bestCatMap['name_en'] ?? bestCatMap['name_ar'])
                : lang == 'tr'
                    ? (bestCatMap['name_tr'] ?? bestCatMap['name_ar'])
                    : bestCatMap['name_ar']) as String?;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'stats.sessions'.tr(),
                value: '$games',
                icon:  Icons.sports_esports_rounded,
                color: _cIndigo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'stats.best_score'.tr(),
                value: '$bestScore',
                icon:  Icons.emoji_events_rounded,
                color: Colors.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'stats.correct'.tr(),
                value: '$correct',
                icon:  Icons.check_circle_rounded,
                color: Colors.greenAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'stats.wrong'.tr(),
                value: '$wrong',
                icon:  Icons.cancel_rounded,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
        if (bestCat != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.military_tech_rounded,
                      color: Colors.amber, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'stats.best_category'.tr(),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                    Text(
                      bestCat,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─── بطاقة نسبة الدقة ────────────────────────────────────────────────────
  Widget _buildAccuracyCard() {
    final correct = (_stats?['total_correct'] as num?)?.toInt() ?? 0;
    final wrong   = (_stats?['total_wrong']   as num?)?.toInt() ?? 0;
    final total   = correct + wrong;
    final pct     = total == 0 ? 0.0 : correct / total;
    final pctInt  = (pct * 100).round();

    Color barEnd;
    IconData moodIcon;
    if (pctInt >= 80)      { barEnd = Colors.greenAccent; moodIcon = Icons.local_fire_department_rounded; }
    else if (pctInt >= 50) { barEnd = Colors.orangeAccent; moodIcon = Icons.fitness_center_rounded; }
    else                   { barEnd = Colors.redAccent;    moodIcon = Icons.menu_book_rounded; }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: barEnd.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(moodIcon, color: barEnd, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'stats.accuracy'.tr(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '$pctInt%',
                style: TextStyle(
                  color: barEnd,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // شريط التقدم المزدوج
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_cCyan, barEnd],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: barEnd.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.greenAccent, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    '${'stats.correct_short'.tr()} $correct',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.cancel_rounded,
                      color: Colors.redAccent, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    '${'stats.wrong_short'.tr()} $wrong',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── إحصائيات اللعب الثنائي ──────────────────────────────────────────────
  Widget _buildMultiStats() {
    final total  = (_stats?['total_multi_games'] as num?)?.toInt() ?? 0;
    final wins   = (_stats?['multi_wins']        as num?)?.toInt() ?? 0;
    final losses = total - wins;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'stats.matches'.tr(),
            value: '$total',
            icon:  Icons.sports_kabaddi_rounded,
            color: const Color(0xFFFF6584),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'stats.wins'.tr(),
            value: '$wins',
            icon:  Icons.emoji_events_rounded,
            color: Colors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'stats.losses'.tr(),
            value: '$losses',
            icon:  Icons.sentiment_dissatisfied_rounded,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }

  // ─── تقدم الأقسام ────────────────────────────────────────────────────────
  Widget _buildCategoryProgress() {
    final List<dynamic> progress =
        (_stats?['category_progress'] as List<dynamic>?) ?? [];

    if (progress.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'stats.no_sections'.tr(),
            style: const TextStyle(color: Colors.white38),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: progress.asMap().entries.map((entry) {
          final i    = entry.key;
          final item = entry.value as Map<String, dynamic>;
          final lang = context.locale.languageCode;
          final name = (lang == 'en'
                  ? (item['name_en'] ?? item['name_ar'])
                  : lang == 'tr'
                      ? (item['name_tr'] ?? item['name_ar'])
                      : item['name_ar']) as String? ?? '';
          final diff = (item['max_difficulty'] as num?)?.toInt() ?? 1;
          final pct  = diff / 10.0;

          Color levelColor;
          if (diff <= 3)      { levelColor = Colors.greenAccent; }
          else if (diff <= 6) { levelColor = Colors.orangeAccent; }
          else                { levelColor = const Color(0xFFFF6584); }

          return Column(
            children: [
              if (i != 0)
                Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06)),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // شريط تقدم مزدوج
                          Stack(
                            children: [
                              Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: pct,
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [_cCyan, levelColor],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: levelColor.withValues(alpha: 0.4),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${'stats.level_prefix'.tr()} $diff',
                          style: TextStyle(
                            color: levelColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _levelLabel(diff),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ─── خطأ ─────────────────────────────────────────────────────────────────
  Widget _buildError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.white38, size: 60),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.white54)),
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

  String _levelLabel(int d) {
    if (d <= 3) { return 'stats.beginner'.tr(); }
    if (d <= 6) { return 'stats.intermediate'.tr(); }
    return 'stats.expert'.tr();
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

// ─── بطاقة إحصائية ───────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
