import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../providers/user_provider.dart';
import '../services/game_service.dart';
import '../services/energy_service.dart';
import '../services/ad_service.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';
import 'friends_screen.dart';
import 'stats_screen.dart';

// ─── Neon-Glass palette ───────────────────────────────────────────────────────
const _cBg      = Color(0xFF0B1326);
const _cSurface = Color(0xFF131B2E);
const _cCard    = Color(0xFF171F33);
const _cCyan    = Color(0xFF00FBFB);
const _cIndigo  = Color(0xFF6366F1);
const _cNavBg   = Color(0xFF10102B);

// ─── Emoji → Material icon mapping ───────────────────────────────────────────
IconData _iconForEmoji(String emoji) {
  switch (emoji) {
    case '🔬': return Icons.science;
    case '📚': return Icons.library_books;
    case '⚽': return Icons.sports;
    case '🌍': return Icons.language;
    case '🏛️': return Icons.account_balance;
    case '🕌': return Icons.auto_stories;
    case '⚔️': return Icons.groups;
    default:   return Icons.category;
  }
}

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _gameService   = GameService();
  final _energyService = EnergyService();
  late Future<List<CategoryModel>> _future;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _future = _gameService.getCategories(lang: context.locale.languageCode);
    }
  }

  void _reload() => setState(() {
    _future = _gameService.getCategories(lang: context.locale.languageCode);
  });

  void _navigateToGame(CategoryModel category) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => GameScreen(category: category)));
  }

  void _onCategoryTap(CategoryModel category) {
    if (category.isPremium) {
      _showPremiumGate(category);
    } else {
      _navigateToGame(category);
    }
  }

  void _showPremiumGate(CategoryModel category) {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PremiumGateSheet(
        category:    category,
        lang:        context.locale.languageCode,
        onWatchAd:   () => _handleWatchAd(ctx, category),
        onUseEnergy: () => _handleUseEnergy(ctx, category),
      ),
    );
  }

  void _handleWatchAd(BuildContext sheetCtx, CategoryModel category) {
    Navigator.pop(sheetCtx);
    AdService().showRewarded(onRewarded: () {
      if (mounted) { _navigateToGame(category); }
    });
  }

  Future<void> _handleUseEnergy(
      BuildContext sheetCtx, CategoryModel category) async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    Navigator.pop(sheetCtx);
    try {
      final result  = await _energyService.consumeEnergy(token);
      final canPlay = result['can_play'] as bool? ?? false;
      if (!mounted) return;
      if (canPlay) {
        _navigateToGame(category);
      } else {
        _showSnack('categories.no_energy'.tr(), isError: true);
      }
    } catch (_) {
      if (mounted) { _showSnack('categories.no_energy'.tr(), isError: true); }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: isError
          ? Colors.redAccent.withValues(alpha: 0.85)
          : _cCyan.withValues(alpha: 0.85),
      behavior: SnackBarBehavior.floating,
      shape:    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content:  Text(msg, style: const TextStyle(color: Colors.white)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final lang = context.locale.languageCode;

    return Scaffold(
      backgroundColor: _cBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(user),
            Expanded(child: _buildBody(lang)),
            _buildBottomNav(context),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(dynamic user) {
    final name      = (user?.name  as String?) ?? '';
    final avatarUrl = (user?.avatar as String?);

    return Container(
      height:  64,
      color:   _cBg,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // RTL: right side → back arrow
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_forward_ios_rounded,
                color: _cCyan, size: 22),
          ),
          const Spacer(),
          // Center title
          const Text('الأصناف',
            style: TextStyle(
              color:      _cCyan,
              fontSize:   20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          // RTL: left side → user avatar
          Container(
            width:  40,
            height: 40,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              border: Border.all(
                  color: _cCyan.withValues(alpha: 0.25), width: 2),
            ),
            child: ClipOval(
              child: avatarUrl != null
                  ? Image.network(avatarUrl, fit: BoxFit.cover,
                      errorBuilder: (ctx2, e2, st2) => _avatarFallback(name))
                  : _avatarFallback(name),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name) => Container(
    color: _cIndigo.withValues(alpha: 0.3),
    child: Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: _cCyan, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),
  );

  // ─── Body ─────────────────────────────────────────────────────────────────
  Widget _buildBody(String lang) {
    return FutureBuilder<List<CategoryModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _cCyan, strokeWidth: 2));
        }
        if (snapshot.hasError) {
          return Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, color: Colors.white24, size: 56),
              const SizedBox(height: 12),
              Text('categories.load_error'.tr(),
                  style: const TextStyle(color: Colors.white54, fontSize: 15)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _reload,
                icon:  const Icon(Icons.refresh, color: _cCyan),
                label: Text('common.retry'.tr(),
                    style: const TextStyle(color: _cCyan)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _cCyan),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ));
        }

        final all     = snapshot.data ?? [];
        final regular = all.where((c) => !c.isPremium).toList();
        final premium = all.where((c) =>  c.isPremium).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Welcome section
              _buildWelcomeSection(),
              const SizedBox(height: 28),

              // Regular 2-col grid
              if (regular.isNotEmpty) _buildRegularGrid(regular, lang),

              // Premium PRO cards
              if (premium.isNotEmpty) ...[
                const SizedBox(height: 14),
                ...premium.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ProCard(
                    category: c, lang: lang,
                    onTap: () => _onCategoryTap(c),
                  ),
                )),
              ],

              const SizedBox(height: 8),

              // Daily challenge banner
              _buildDailyChallengeBanner(),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // ─── Welcome section ──────────────────────────────────────────────────────
  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'categories.welcome_sub'.tr(),
          style: const TextStyle(
            color:      Color(0xFFC0C1FF),
            fontSize:   14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'categories.title'.tr(),
          style: const TextStyle(
            color:      Colors.white,
            fontSize:   32,
            fontWeight: FontWeight.w900,
            height:     1.1,
          ),
        ),
        const SizedBox(height: 10),
        // Cyan accent bar
        Container(
          height: 6,
          width:  64,
          decoration: BoxDecoration(
            color:        _cCyan,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color:     _cCyan.withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Regular 2-col grid ───────────────────────────────────────────────────
  Widget _buildRegularGrid(List<CategoryModel> regular, String lang) {
    final rows = <Widget>[];
    for (var i = 0; i < regular.length; i += 2) {
      rows.add(Row(
        children: [
          Expanded(child: _RegularCard(
            category: regular[i],
            lang:     lang,
            onTap:    () => _onCategoryTap(regular[i]),
          )),
          const SizedBox(width: 14),
          Expanded(child: i + 1 < regular.length
              ? _RegularCard(
                  category: regular[i + 1],
                  lang:     lang,
                  onTap:    () => _onCategoryTap(regular[i + 1]),
                )
              : const SizedBox()),
        ],
      ));
      if (i + 2 < regular.length) { rows.add(const SizedBox(height: 14)); }
    }
    return Column(children: rows);
  }

  // ─── Daily challenge banner ────────────────────────────────────────────────
  Widget _buildDailyChallengeBanner() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color:        _cCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cCyan.withValues(alpha: 0.12)),
      ),
      child: Stack(
        children: [
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end:   Alignment.centerRight,
                  colors: [
                    _cCyan.withValues(alpha: 0.0),
                    _cCyan.withValues(alpha: 0.10),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // "ابدأ" button (left in RTL layout)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color:        _cCyan,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color:     _cCyan.withValues(alpha: 0.35),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Text(
                    'categories.challenge_start'.tr(),
                    style: const TextStyle(
                      color:      Color(0xFF003737),
                      fontSize:   14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                // Text block (right in RTL)
                Flexible(
                  child: Column(
                    mainAxisAlignment:  MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'categories.challenge_title'.tr(),
                        style: const TextStyle(
                          color:      _cCyan,
                          fontSize:   18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'categories.challenge_desc'.tr(),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color:    Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          height:   1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom nav ───────────────────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: _cNavBg.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(
            color: _cCyan.withValues(alpha: 0.08))),
        boxShadow: [BoxShadow(
            color:     Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset:     const Offset(0, -8))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavBtn(
            icon:   Icons.home_rounded,
            label:  'home.nav_home'.tr(),
            active: true,
            onTap:  () => Navigator.of(context)
                .popUntil((route) => route.isFirst),
          ),
          _NavBtn(
            icon:   Icons.leaderboard_rounded,
            label:  'home.nav_ranking'.tr(),
            active: false,
            onTap:  () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const LeaderboardScreen())),
          ),
          _NavBtn(
            icon:   Icons.people_rounded,
            label:  'home.nav_friends'.tr(),
            active: false,
            onTap:  () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const FriendsScreen())),
          ),
          _NavBtn(
            icon:   Icons.person_rounded,
            label:  'home.nav_profile'.tr(),
            active: false,
            onTap:  () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const StatsScreen())),
          ),
        ],
      ),
    );
  }
}

// ─── Nav button ───────────────────────────────────────────────────────────────
class _NavBtn extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final bool         active;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.label,
      required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: active
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color:        _cCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: _cCyan.withValues(alpha: 0.15), blurRadius: 12)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: _cCyan, size: 22),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(
                    color: _cCyan, fontSize: 10, fontWeight: FontWeight.bold)),
              ]),
            )
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: Colors.white30, size: 22),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(
                  color: Colors.white30, fontSize: 10)),
            ]),
    );
  }
}

// ─── Regular category card (grid) ─────────────────────────────────────────────
class _RegularCard extends StatelessWidget {
  final CategoryModel category;
  final String        lang;
  final VoidCallback  onTap;
  const _RegularCard({required this.category, required this.lang,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    final icon  = _iconForEmoji(category.icon);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 165,
        decoration: BoxDecoration(
          color:        _cCard.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Stack(
          children: [
            // Ambient glow circle (top-right)
            Positioned(
              top: -16, right: -16,
              child: Container(
                width:  80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.08),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisAlignment:  MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon in rounded square
                  Container(
                    width:  64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end:   Alignment.bottomLeft,
                        colors: [
                          color.withValues(alpha: 0.22),
                          color.withValues(alpha: 0.0),
                        ],
                      ),
                      border: Border.all(
                          color: color.withValues(alpha: 0.3)),
                      boxShadow: [BoxShadow(
                          color:     color.withValues(alpha: 0.18),
                          blurRadius: 12)],
                    ),
                    child: Icon(icon, color: color, size: 30),
                  ),
                  const SizedBox(height: 12),
                  // Name
                  Text(
                    category.localizedName(lang),
                    textAlign: TextAlign.center,
                    maxLines:  1,
                    overflow:  TextOverflow.ellipsis,
                    style: const TextStyle(
                      color:      Color(0xFFDAE2FD),
                      fontSize:   16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (category.questionCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${category.questionCount} ${'categories.q_count'.tr()}',
                      style: TextStyle(
                        color:         color,
                        fontSize:      11,
                        fontWeight:    FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PRO/Premium card (full width) ────────────────────────────────────────────
class _ProCard extends StatelessWidget {
  final CategoryModel category;
  final String        lang;
  final VoidCallback  onTap;
  const _ProCard({required this.category, required this.lang,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    final icon  = _iconForEmoji(category.icon);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color:        _cCard.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: [BoxShadow(
              color: color.withValues(alpha: 0.08), blurRadius: 16)],
        ),
        child: Row(
          children: [
            const SizedBox(width: 18),
            // Icon square
            Container(
              width:  54, height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.22),
                      color.withValues(alpha: 0.0)],
                ),
                border: Border.all(color: color.withValues(alpha: 0.3)),
                boxShadow: [BoxShadow(
                    color: color.withValues(alpha: 0.2), blurRadius: 10)],
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            // Name + subtitle
            Expanded(
              child: Column(
                mainAxisAlignment:  MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.localizedName(lang),
                    style: const TextStyle(
                      color:      Color(0xFFDAE2FD),
                      fontSize:   17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'categories.pro_subtitle'.tr(),
                    style: TextStyle(
                      color:    Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // PRO badge + lock
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('PRO', style: TextStyle(
                    color:      color,
                    fontSize:   13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  )),
                  const SizedBox(height: 2),
                  Icon(Icons.lock_rounded, color: color, size: 20),
                ],
              ),
            ),
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Premium gate bottom sheet ────────────────────────────────────────────────
class _PremiumGateSheet extends StatelessWidget {
  final CategoryModel category;
  final String        lang;
  final VoidCallback  onWatchAd;
  final VoidCallback  onUseEnergy;
  const _PremiumGateSheet({required this.category, required this.lang,
      required this.onWatchAd, required this.onUseEnergy});

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    final icon  = _iconForEmoji(category.icon);

    return Container(
      decoration: const BoxDecoration(
        color:        _cSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white12, borderRadius: BorderRadius.circular(2)),
          ),
          // Icon
          Container(
            width:  80, height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(colors: [
                color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)]),
              border: Border.all(color: color.withValues(alpha: 0.35)),
              boxShadow: [BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 20, spreadRadius: 2)],
            ),
            child: Icon(icon, color: color, size: 38),
          ),
          const SizedBox(height: 14),
          Text(category.localizedName(lang), style: TextStyle(
            color: color, fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // PRO badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFF5A623), Color(0xFFFFD700)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_rounded, size: 12, color: Colors.white),
              const SizedBox(width: 5),
              Text('categories.premium_badge'.tr(),
                style: const TextStyle(color: Colors.white,
                    fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 14),
          Text('categories.premium_desc'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13, height: 1.5)),
          const SizedBox(height: 24),
          // Watch Ad
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: onWatchAd,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cIndigo, elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
              icon:  const Icon(Icons.play_circle_rounded,
                  color: Colors.white, size: 20),
              label: Text('categories.watch_ad_btn'.tr(),
                style: const TextStyle(color: Colors.white,
                    fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          // Use Energy
          SizedBox(
            width: double.infinity, height: 52,
            child: OutlinedButton.icon(
              onPressed: onUseEnergy,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
              icon:  const Text('❤️', style: TextStyle(fontSize: 16)),
              label: Text('categories.use_energy_btn'.tr(),
                style: TextStyle(color: color,
                    fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr(),
              style: const TextStyle(color: Colors.white38, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
