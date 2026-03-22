import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../providers/user_provider.dart';
import '../services/socket_service.dart';
import '../services/room_service.dart';
import '../services/notification_service.dart';
import '../services/energy_service.dart';
import '../services/ad_service.dart';
import '../config/api_config.dart';
import 'categories_screen.dart';
import 'dual_menu_screen.dart';
import 'dual_game_screen.dart';
import 'friends_screen.dart';
import 'leaderboard_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';

// ─── ثوابت الألوان ───────────────────────────────────────────────────────────
const _cBg        = Color(0xFF0D1117);
const _cCard      = Color(0xFF161B2E);
const _cTeal      = Color(0xFF00BCD4);
const _cPink      = Color(0xFFE91E8C);
const _cGold      = Color(0xFFFFD700);
const _cNavActive = Color(0xFFE040FB);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _socket        = SocketService();
  final _roomService   = RoomService();
  final _energyService = EnergyService();
  final _dio           = Dio();

  int  _energy             = 5;
  int  _myRank             = 0;
  int  _onlineFriendsCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSocket();
      _loadEnergy();
      _fetchAdditionalData();
    });
  }

  // ─── تحميل الطاقة ────────────────────────────────────────────────────────
  Future<void> _loadEnergy() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    try {
      final res = await _energyService.getEnergy(token);
      if (mounted) {
        setState(() {
          _energy = res['energy'] as int? ?? 5;
        });
      }
    } catch (_) {
      // keep default energy=5
    }
  }

  // ─── جلب الترتيب وعدد الأصدقاء ──────────────────────────────────────────
  Future<void> _fetchAdditionalData() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    try {
      // ترتيب اللاعب
      final rankRes = await _dio.get(
        '${ApiConfig.baseUrl}${ApiConfig.myRank}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final rank = rankRes.data['rank'] as int? ?? 0;
      if (mounted && rank > 0) setState(() => _myRank = rank);
    } catch (_) {}

    try {
      // عدد الأصدقاء المتصلين (is_online من السيرفر)
      final friendsRes = await _dio.get(
        '${ApiConfig.baseUrl}${ApiConfig.friendsList}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final friends = (friendsRes.data as List?) ?? [];
      final onlineCount = friends
          .where((f) => f['is_online'] == true || f['isOnline'] == true)
          .length;
      if (mounted) setState(() => _onlineFriendsCount = onlineCount);
    } catch (_) {}
  }

  // ─── إعداد الـ Socket ────────────────────────────────────────────────────
  void _setupSocket() {
    final user  = context.read<UserProvider>().user;
    final token = context.read<UserProvider>().token;
    if (user == null || token == null) return;

    _socket.connect();
    _socket.registerOnline(userId: user.id, userName: user.name);
    _saveFcmToken(token);

    _socket.onGameInviteReceived = (data) {
      if (!mounted) return;
      _showInviteDialog(
        fromUserId:   data['from_user_id']  as int? ?? 0,
        fromName:     data['from_name']     ?? '',
        roomCode:     data['room_code']     ?? '',
        categoryName: data['category_name'] ?? '',
      );
    };
  }

  // ─── حفظ FCM Token ───────────────────────────────────────────────────────
  Future<void> _saveFcmToken(String token) async {
    try {
      final fcmToken = await NotificationService().getToken();
      if (fcmToken == null) return;
      await _dio.put(
        '${ApiConfig.baseUrl}/auth/fcm-token',
        data: {'fcm_token': fcmToken},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      NotificationService().onTokenRefresh((newToken) {
        _dio.put(
          '${ApiConfig.baseUrl}/auth/fcm-token',
          data: {'fcm_token': newToken},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _socket.onGameInviteReceived = null;
    super.dispose();
  }

  // ─── فحص الطاقة ──────────────────────────────────────────────────────────
  Future<void> _checkEnergyAndNavigate(VoidCallback navigate) async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    if (_energy > 0) {
      try {
        final res = await _energyService.consumeEnergy(token);
        if (!mounted) return;
        if (res['can_play'] == true) {
          setState(() => _energy = res['energy'] as int? ?? (_energy - 1));
          navigate();
        }
      } catch (_) {
        navigate();
      }
      return;
    }
    if (mounted) _showNoEnergyDialog(navigate);
  }

  // ─── Dialog الطاقة ───────────────────────────────────────────────────────
  void _showNoEnergyDialog(VoidCallback navigate) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'energy.empty_title'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(Icons.favorite_border, color: Colors.white24, size: 28),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'energy.recharge_hint'.tr(),
              style: const TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'energy.wait_midnight'.tr(),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr(),
                style: const TextStyle(color: Colors.white38)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cNavActive,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: Text('energy.watch_ad'.tr()),
            onPressed: () {
              Navigator.pop(context);
              _watchAdAndRecharge(navigate);
            },
          ),
        ],
      ),
    );
  }

  void _watchAdAndRecharge(VoidCallback navigate) {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    AdService().showRewarded(
      onRewarded: () async {
        try {
          final res = await _energyService.rechargeEnergy(token);
          if (!mounted) return;
          setState(() => _energy = res['energy'] as int? ?? (_energy + 1));
          await _checkEnergyAndNavigate(navigate);
        } catch (_) {}
      },
    );
  }

  // ─── Dialog دعوة اللعب ────────────────────────────────────────────────────
  void _showInviteDialog({
    required int    fromUserId,
    required String fromName,
    required String roomCode,
    required String categoryName,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _cCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'home.invite_title'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'home.invite_msg'.tr(namedArgs: {'name': fromName}),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (categoryName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'home.invite_category'.tr(namedArgs: {'category': categoryName}),
                style: const TextStyle(color: _cTeal, fontSize: 14),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _socket.respondToInvite(
                  toUserId: fromUserId, accepted: false, roomCode: roomCode);
            },
            child: Text('home.reject'.tr(),
                style: const TextStyle(color: Colors.redAccent, fontSize: 16)),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cNavActive,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _acceptInvite(
                  fromUserId: fromUserId,
                  fromName:   fromName,
                  roomCode:   roomCode);
            },
            child: Text('home.accept'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptInvite({
    required int    fromUserId,
    required String fromName,
    required String roomCode,
  }) async {
    final user  = context.read<UserProvider>().user;
    final token = context.read<UserProvider>().token;
    if (user == null || token == null) return;

    try {
      final lang = context.locale.languageCode;
      final room = await _roomService.joinRoom(roomCode: roomCode, token: token);
      _socket.respondToInvite(
          toUserId: fromUserId, accepted: true, roomCode: roomCode);
      _socket.joinRoom(
        roomCode: roomCode,
        userId:   user.id,
        userName: user.name,
        role:     'guest',
        lang:     lang,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DualGameScreen(
            room:           room,
            role:           'guest',
            myName:         user.name,
            guestName:      fromName,
            opponentId:     fromUserId,
            opponentAvatar: room.host.avatar,
            opponentLevel:  room.host.currentLevel,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'home.join_error'.tr(namedArgs: {'error': e.toString()})),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─── Language Sheet ──────────────────────────────────────────────────────
  static const _langs = [
    {'code': 'ar', 'flag': '🇸🇦', 'label': 'العربية'},
    {'code': 'en', 'flag': '🇬🇧', 'label': 'English'},
    {'code': 'tr', 'flag': '🇹🇷', 'label': 'Türkçe'},
  ];

  void _showLangSheet() {
    final current = context.locale.languageCode;
    showModalBottomSheet(
      context: context,
      backgroundColor: _cCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Text(
              'language.choose'.tr(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._langs.map((lang) {
              final isSelected = lang['code'] == current;
              return GestureDetector(
                onTap: () {
                  context.setLocale(Locale(lang['code']!));
                  Navigator.pop(ctx);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _cNavActive.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? _cNavActive : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(lang['flag']!,
                          style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 16),
                      Text(
                        lang['label']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: _cNavActive, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //                              BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    context.locale;
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: _cBg,
      extendBody: true,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Top Bar ───────────────────────────────────────────────────
            _buildTopBar(context, user),

            // ─── Body ──────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(user),
                    const SizedBox(height: 24),
                    _buildGameCards(context),
                    const SizedBox(height: 28),
                    // ─ Explore More title ──────────────────────────────────
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        'home.explore_more'.tr(),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildExploreTiles(context),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // ─── FAB ─────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CategoriesScreen()),
        ).then((_) => _loadEnergy()),
        backgroundColor: _cTeal,
        elevation: 6,
        child: const Icon(Icons.rocket_launch_rounded, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // ─── Bottom Nav ───────────────────────────────────────────────────────
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ─── Top Bar ─────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, dynamic user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Gear → Language / Settings
          GestureDetector(
            onTap: _showLangSheet,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(Icons.settings_outlined,
                  color: _cTeal, size: 22),
            ),
          ),

          // App title
          Expanded(
            child: Text(
              'home.title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _cTeal,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Profile avatar (with glow)
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ).then((_) => _loadEnergy()),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _cPink.withValues(alpha: 0.45),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF6C63FF),
                backgroundImage: user?.avatar != null
                    ? NetworkImage(user!.avatar!) as ImageProvider
                    : null,
                child: user?.avatar == null
                    ? Text(
                        user?.name?.isNotEmpty == true
                            ? user!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Welcome Card ────────────────────────────────────────────────────────
  Widget _buildWelcomeCard(dynamic user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ─ Left: name + points + hearts ──────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'home.welcome'.tr(
                      namedArgs: {'name': user?.name ?? ''}),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Points badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star,
                          color: _cGold, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${user?.totalScore ?? 0}',
                        style: const TextStyle(
                          color: _cGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Energy hearts
                Row(
                  children: [
                    Text(
                      '$_energy/5  ',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < _energy
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: i < _energy
                            ? _cPink
                            : Colors.white24,
                        size: 17,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // ─ Right: avatar + PRO badge ──────────────────────────────────────
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _cTeal, width: 3),
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF1E2140),
                  backgroundImage: user?.avatar != null
                      ? NetworkImage(user!.avatar!) as ImageProvider
                      : null,
                  child: user?.avatar == null
                      ? Text(
                          user?.name?.isNotEmpty == true
                              ? user!.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: _cTeal,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _cTeal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Game Cards (Dual + Solo) ─────────────────────────────────────────────
  Widget _buildGameCards(BuildContext context) {
    return Row(
      children: [
        // Dual
        Expanded(
          child: _GameCard(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B35D6), Color(0xFFD535AB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.close_rounded,
            iconBgColor: const Color(0xFFD535AB),
            title: 'home.dual'.tr(),
            subtitle: 'home.dual_card_sub'.tr(),
            btnLabel: 'home.play_now'.tr(),
            btnColor: _cPink,
            energy: _energy,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DualMenuScreen()),
            ).then((_) => _loadEnergy()),
          ),
        ),
        const SizedBox(width: 16),
        // Solo
        Expanded(
          child: _GameCard(
            gradient: const LinearGradient(
              colors: [Color(0xFF00796B), Color(0xFF00BCD4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.gps_fixed_rounded,
            iconBgColor: _cTeal,
            title: 'home.solo'.tr(),
            subtitle: 'home.solo_card_sub'.tr(),
            btnLabel: 'home.start_now'.tr(),
            btnColor: _cTeal,
            energy: _energy,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ).then((_) => _loadEnergy()),
          ),
        ),
      ],
    );
  }

  // ─── Explore Tiles ────────────────────────────────────────────────────────
  Widget _buildExploreTiles(BuildContext context) {
    return Column(
      children: [
        // Leaderboard
        _ExploreTile(
          icon: Icons.emoji_events_rounded,
          iconColor: const Color(0xFFFFA000),
          iconBg: const Color(0xFFFFA000).withValues(alpha: 0.15),
          title: 'home.leaderboard'.tr(),
          subtitle: _myRank > 0
              ? 'home.your_rank'.tr(namedArgs: {'rank': '$_myRank'})
              : 'home.leaderboard_sub'.tr(),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const LeaderboardScreen())),
        ),
        const SizedBox(height: 10),
        // Friends
        _ExploreTile(
          icon: Icons.people_alt_rounded,
          iconColor: _cTeal,
          iconBg: _cTeal.withValues(alpha: 0.15),
          title: 'home.friends_mode'.tr(),
          subtitle: _onlineFriendsCount > 0
              ? 'home.online_friends'
                  .tr(namedArgs: {'count': '$_onlineFriendsCount'})
              : 'home.friends_sub'.tr(),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const FriendsScreen()))
            .then((_) => _loadEnergy()),
        ),
        const SizedBox(height: 10),
        // Stats
        _ExploreTile(
          icon: Icons.bar_chart_rounded,
          iconColor: _cNavActive,
          iconBg: _cNavActive.withValues(alpha: 0.15),
          title: 'home.stats'.tr(),
          subtitle: 'home.stats_sub'.tr(),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatsScreen())),
        ),
      ],
    );
  }

  // ─── Bottom Navigation ────────────────────────────────────────────────────
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cCard,
        border: Border(
          top: BorderSide(
              color: Colors.white.withValues(alpha: 0.06)),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'home.nav_home'.tr(),
                isActive: true,
                onTap: () {},
              ),
              _NavItem(
                icon: Icons.leaderboard_rounded,
                label: 'home.nav_ranking'.tr(),
                isActive: false,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen())),
              ),
              _NavItem(
                icon: Icons.people_rounded,
                label: 'home.nav_friends'.tr(),
                isActive: false,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FriendsScreen())),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'home.nav_profile'.tr(),
                isActive: false,
                onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProfileScreen()))
                    .then((_) => _loadEnergy()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Game Card Widget ─────────────────────────────────────────────────────────
class _GameCard extends StatelessWidget {
  final Gradient  gradient;
  final IconData  icon;
  final Color     iconBgColor;
  final String    title;
  final String    subtitle;
  final String    btnLabel;
  final Color     btnColor;
  final int       energy;
  final VoidCallback onTap;

  const _GameCard({
    required this.gradient,
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.btnLabel,
    required this.btnColor,
    required this.energy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 240,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon box — centered & larger
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: iconBgColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color:      iconBgColor.withValues(alpha: 0.30),
                    blurRadius: 18,
                    offset:     const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 46),
            ),
            const Spacer(),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor.withValues(alpha: 0.90),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  btnLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Explore Tile Widget ──────────────────────────────────────────────────────
class _ExploreTile extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final Color        iconBg;
  final String       title;
  final String       subtitle;
  final VoidCallback onTap;

  const _ExploreTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _cCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            // Texts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Arrow (auto-mirrors in RTL)
            const Icon(Icons.chevron_left_rounded,
                color: Colors.white30, size: 26),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom Nav Item ──────────────────────────────────────────────────────────
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive
                  ? _cNavActive.withValues(alpha: 0.2)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? _cNavActive : Colors.white38,
              size: 24,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isActive ? _cNavActive : Colors.white38,
              fontSize: 10,
              fontWeight:
                  isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
