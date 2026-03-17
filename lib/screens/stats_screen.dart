import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../providers/user_provider.dart';
import '../services/game_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _gameService = GameService();

  Map<String, dynamic>? _stats;
  bool   _loading = true;
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
    } catch (e) {
      setState(() { _error = 'stats.load_error'.tr(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserProvider>().user;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ────────────────────────────────────────────────
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
                      'stats.title'.tr(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white54),
                    onPressed: _load,
                  ),
                ],
              ),
            ),

            // ─── المحتوى ───────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6C63FF)))
                  : _error != null
                      ? _buildError()
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: const Color(0xFF6C63FF),
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // ── بطاقة اليوزر ─────────────────────
                              _buildProfileCard(user?.name ?? '', user?.avatar),

                              const SizedBox(height: 16),

                              // ── إحصائيات عامة ────────────────────
                              _buildSectionTitle('stats.solo'.tr()),
                              const SizedBox(height: 10),
                              _buildSoloStats(),

                              const SizedBox(height: 20),

                              // ── نسبة الدقة ────────────────────────
                              _buildAccuracyCard(),

                              const SizedBox(height: 20),

                              // ── اللعب الثنائي ─────────────────────
                              _buildSectionTitle('stats.dual'.tr()),
                              const SizedBox(height: 10),
                              _buildMultiStats(),

                              const SizedBox(height: 20),

                              // ── تقدم الأقسام ──────────────────────
                              _buildSectionTitle('stats.progress'.tr()),
                              const SizedBox(height: 10),
                              _buildCategoryProgress(),

                              const SizedBox(height: 24),
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
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3D5AF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white24,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text('$score ${'common.points_unit'.tr()}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
          if (rank != null)
            Column(
              children: [
                Text(
                  '#$rank',
                  style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 26,
                      fontWeight: FontWeight.bold),
                ),
                Text('stats.rank'.tr(),
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
        ],
      ),
    );
  }

  // ─── عنوان القسم ─────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) => Text(
        title,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold),
      );

  // ─── إحصائيات اللعب الفردي ───────────────────────────────────────────────
  Widget _buildSoloStats() {
    final games     = (_stats?['total_solo_games'] as num?)?.toInt() ?? 0;
    final correct   = (_stats?['total_correct']    as num?)?.toInt() ?? 0;
    final wrong     = (_stats?['total_wrong']      as num?)?.toInt() ?? 0;
    final bestScore = (_stats?['best_solo_score']  as num?)?.toInt() ?? 0;
    final bestCatMap = _stats?['best_category'] as Map<String, dynamic>?;
    final lang       = context.locale.languageCode;
    final bestCat    = bestCatMap == null ? null : (
      lang == 'en' ? (bestCatMap['name_en'] ?? bestCatMap['name_ar'])
    : lang == 'tr' ? (bestCatMap['name_tr'] ?? bestCatMap['name_ar'])
    : bestCatMap['name_ar']
    ) as String?;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatCard(label: 'stats.sessions'.tr(), value: '$games', icon: '🎮', color: const Color(0xFF6C63FF))),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'stats.best_score'.tr(), value: '$bestScore', icon: '⭐', color: const Color(0xFFFFD700))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(label: 'stats.correct'.tr(), value: '$correct', icon: '✅', color: const Color(0xFF4CAF50))),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'stats.wrong'.tr(), value: '$wrong', icon: '❌', color: const Color(0xFFF44336))),
          ],
        ),
        if (bestCat != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Text('🏅', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('stats.best_category'.tr(),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                    Text(bestCat,
                        style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
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

    Color barColor;
    String emoji;
    if (pctInt >= 80)      { barColor = Colors.greenAccent; emoji = '🔥'; }
    else if (pctInt >= 50) { barColor = Colors.orangeAccent; emoji = '💪'; }
    else                   { barColor = Colors.redAccent;    emoji = '📖'; }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text('stats.accuracy'.tr(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                '$pctInt%',
                style: TextStyle(
                    color: barColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white12,
              color: barColor,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${'stats.correct_short'.tr()} $correct',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12)),
              Text('${'stats.wrong_short'.tr()} $wrong',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── إحصائيات اللعب الثنائي ──────────────────────────────────────────────
  Widget _buildMultiStats() {
    final total = (_stats?['total_multi_games'] as num?)?.toInt() ?? 0;
    final wins  = (_stats?['multi_wins']        as num?)?.toInt() ?? 0;
    final losses = total - wins;

    return Row(
      children: [
        Expanded(child: _StatCard(label: 'stats.matches'.tr(), value: '$total', icon: '⚔️', color: const Color(0xFFFF6584))),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'stats.wins'.tr(),  value: '$wins',  icon: '👑', color: const Color(0xFFFFD700))),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'stats.losses'.tr(), value: '$losses', icon: '😅', color: const Color(0xFF9E9E9E))),
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
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Center(
          child: Text('stats.no_sections'.tr(),
              style: const TextStyle(color: Colors.white38)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: progress.asMap().entries.map((entry) {
          final i    = entry.key;
          final item = entry.value as Map<String, dynamic>;
          final catLang = context.locale.languageCode;
          final name = (catLang == 'en'
              ? (item['name_en'] ?? item['name_ar'])
              : catLang == 'tr'
                  ? (item['name_tr'] ?? item['name_ar'])
                  : item['name_ar']) as String? ?? '';
          final diff = (item['max_difficulty'] as num?)?.toInt() ?? 1;
          final pct  = diff / 10.0;

          Color levelColor;
          if (diff <= 3)       levelColor = Colors.greenAccent;
          else if (diff <= 6)  levelColor = Colors.orangeAccent;
          else                 levelColor = Colors.redAccent;

          return Column(
            children: [
              if (i != 0)
                const Divider(color: Colors.white10, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: Colors.white12,
                              color: levelColor,
                              minHeight: 6,
                            ),
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
                              fontWeight: FontWeight.bold),
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
            Text(_error!,
                style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _load,
                child: Text('common.retry'.tr())),
          ],
        ),
      );

  String _levelLabel(int d) {
    if (d <= 3) return 'stats.beginner'.tr();
    if (d <= 6) return 'stats.intermediate'.tr();
    return 'stats.expert'.tr();
  }
}

// ─── بطاقة إحصائية واحدة ─────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value, icon;
  final Color  color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
