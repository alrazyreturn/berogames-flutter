import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../providers/user_provider.dart';
import '../services/socket_service.dart';
import '../services/room_service.dart';
import '../services/notification_service.dart';
import '../services/energy_service.dart';
import '../services/ad_service.dart';
import '../models/room_model.dart';
import '../config/api_config.dart';
import 'categories_screen.dart';
import 'dual_menu_screen.dart';
import 'dual_game_screen.dart';
import 'friends_screen.dart';
import 'leaderboard_screen.dart';
import 'stats_screen.dart';
import 'how_to_play_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _socket        = SocketService();
  final _roomService   = RoomService();
  final _energyService = EnergyService();

  int  _energy       = 5;
  bool _energyLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSocket();
      _loadEnergy();
    });
  }

  // ─── تحميل الطاقة من السيرفر ────────────────────────────────────────────
  Future<void> _loadEnergy() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    try {
      final res = await _energyService.getEnergy(token);
      if (mounted) {
        setState(() {
          _energy       = res['energy'] as int? ?? 5;
          _energyLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _energyLoaded = true);
    }
  }

  void _setupSocket() {
    final user  = context.read<UserProvider>().user;
    final token = context.read<UserProvider>().token;
    if (user == null || token == null) return;

    _socket.connect();
    _socket.registerOnline(userId: user.id, userName: user.name);

    // ─── حفظ FCM Token على السيرفر ────────────────────────────────────────
    _saveFcmToken(token);

    // ─── استقبال دعوة لعب من صديق ─────────────────────────────────────────
    _socket.onGameInviteReceived = (data) {
      if (!mounted) return;
      final fromUserId   = data['from_user_id']  as int? ?? 0;
      final fromName     = data['from_name']      ?? 'لاعب';
      final roomCode     = data['room_code']       ?? '';
      final categoryName = data['category_name']  ?? '';
      _showInviteDialog(
        fromUserId:   fromUserId,
        fromName:     fromName,
        roomCode:     roomCode,
        categoryName: categoryName,
      );
    };
  }

  // ─── حفظ FCM Token على السيرفر ──────────────────────────────────────────
  Future<void> _saveFcmToken(String token) async {
    try {
      final fcmToken = await NotificationService().getToken();
      if (fcmToken == null) return;
      final dio = Dio();
      await dio.put(
        '${ApiConfig.baseUrl}/auth/fcm-token',
        data: {'fcm_token': fcmToken},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      NotificationService().onTokenRefresh((newToken) {
        dio.put(
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

  // ─── التحقق من الطاقة قبل اللعب ─────────────────────────────────────────
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
        // لو في خطأ في الشبكة، اسمح باللعب
        navigate();
      }
      return;
    }

    // الطاقة = 0 → اعرض dialog
    if (mounted) _showNoEnergyDialog(navigate);
  }

  // ─── dialog انتهاء الطاقة ────────────────────────────────────────────────
  void _showNoEnergyDialog(VoidCallback navigate) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E3F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '⚡ طاقتك انتهت!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // عرض القلوب الفارغة
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
            const Text(
              'شاهد إعلاناً قصيراً للحصول على ❤️ طاقة إضافية',
              style: TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'أو انتظر حتى منتصف الليل لإعادة الشحن 🕛',
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white38)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('شاهد إعلان +❤️'),
            onPressed: () {
              Navigator.pop(context);
              _watchAdAndRecharge(navigate);
            },
          ),
        ],
      ),
    );
  }

  // ─── مشاهدة Rewarded Ad حقيقي وشحن الطاقة ──────────────────────────────
  void _watchAdAndRecharge(VoidCallback navigate) {
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    AdService().showRewarded(
      onRewarded: () async {
        // المستخدم شاهد الإعلان كاملاً → شحن الطاقة
        try {
          final res = await _energyService.rechargeEnergy(token);
          if (!mounted) return;
          setState(() => _energy = res['energy'] as int? ?? (_energy + 1));
          await _checkEnergyAndNavigate(navigate);
        } catch (_) {}
      },
    );
  }

  // ─── حوار الدعوة (بدون check طاقة — استقبال دعوة مجاني) ─────────────────
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
        backgroundColor: const Color(0xFF1E1E3F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '🎮 دعوة للعب!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$fromName يريد مباراتك!',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (categoryName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'القسم: $categoryName',
                style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 14),
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
                toUserId: fromUserId,
                accepted: false,
                roomCode: roomCode,
              );
            },
            child: const Text('❌ رفض', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              // قبول الدعوة — بدون استهلاك طاقة
              _acceptInvite(fromUserId: fromUserId, fromName: fromName, roomCode: roomCode);
            },
            child: const Text('✅ قبول', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // ─── قبول الدعوة والانضمام للغرفة (بدون استهلاك طاقة) ────────────────────
  Future<void> _acceptInvite({
    required int    fromUserId,
    required String fromName,
    required String roomCode,
  }) async {
    final user  = context.read<UserProvider>().user;
    final token = context.read<UserProvider>().token;
    if (user == null || token == null) return;

    try {
      final room = await _roomService.joinRoom(roomCode: roomCode, token: token);

      _socket.respondToInvite(
        toUserId: fromUserId,
        accepted: true,
        roomCode: roomCode,
      );

      _socket.joinRoom(
        roomCode: roomCode,
        userId:   user.id,
        userName: user.name,
        role:     'guest',
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DualGameScreen(
            room:      room,
            role:      'guest',
            myName:    user.name,
            guestName: fromName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الانضمام: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('قريباً... 🚀'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'BeroGames 🎮',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.help_outline, color: Colors.white70),
                        tooltip: 'كيف تلعب؟',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HowToPlayScreen()),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.people, color: Colors.white70),
                        tooltip: 'الأصدقاء',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FriendsScreen()),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white54),
                        onPressed: () async {
                          await context.read<UserProvider>().logout();
                          if (!context.mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ─── بطاقة المستخدم ─────────────────────────────────────────
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ).then((_) => _loadEnergy()),
                child: Container(
                  width: double.infinity,
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
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // أفاتار
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white24,
                        backgroundImage: user?.avatar != null
                            ? NetworkImage(user!.avatar!) as ImageProvider
                            : null,
                        child: user?.avatar == null
                            ? Text(
                                user?.name.isNotEmpty == true
                                    ? user!.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'أهلاً، ${user?.name ?? 'لاعب'}!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'النقاط: ${user?.totalScore ?? 0}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // ─── عداد الطاقة ❤️ ───────────────────────────
                            Row(
                              children: [
                                ...List.generate(5, (i) => Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(
                                    i < _energy
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: i < _energy
                                        ? Colors.redAccent
                                        : Colors.white30,
                                    size: 18,
                                  ),
                                )),
                                const SizedBox(width: 6),
                                Text(
                                  '$_energy/5',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_outlined, color: Colors.white38, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'اختر وضع اللعب',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // ─── بطاقات اللعب ────────────────────────────────────────────
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _ModeCard(
                      icon: '🎯',
                      label: 'لعب فردي',
                      subtitle: 'تحدّى نفسك',
                      color: const Color(0xFF6C63FF),
                      energy: _energy,
                      // ✅ يحتاج طاقة
                      onTap: () => _checkEnergyAndNavigate(() => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                      ).then((_) => _loadEnergy())),
                    ),
                    _ModeCard(
                      icon: '⚔️',
                      label: 'لعب ثنائي',
                      subtitle: 'تحدَّ صديقك',
                      color: const Color(0xFFFF6584),
                      energy: _energy,
                      // ✅ يحتاج طاقة
                      onTap: () => _checkEnergyAndNavigate(() => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DualMenuScreen()),
                      ).then((_) => _loadEnergy())),
                    ),
                    _ModeCard(
                      icon: '👥',
                      label: 'الأصدقاء',
                      subtitle: 'تحدّى أصدقاءك',
                      color: const Color(0xFF43D8C9),
                      // بدون check طاقة
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FriendsScreen()),
                      ).then((_) => _loadEnergy()),
                    ),
                    _ModeCard(
                      icon: '🏆',
                      label: 'المتصدرون',
                      subtitle: 'أفضل اللاعبين',
                      color: const Color(0xFFFFD700),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                      ),
                    ),
                    _ModeCard(
                      icon: '📊',
                      label: 'إحصائياتي',
                      subtitle: 'تقدمك وأدائك',
                      color: const Color(0xFF43D8C9),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StatsScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── بطاقة وضع اللعب ─────────────────────────────────────────────────────────
class _ModeCard extends StatelessWidget {
  final String       icon;
  final String       label;
  final String       subtitle;
  final Color        color;
  final VoidCallback onTap;
  final int?         energy; // null = لا يحتاج طاقة

  const _ModeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.energy,
  });

  @override
  Widget build(BuildContext context) {
    final noEnergy = energy != null && energy! <= 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(icon, style: const TextStyle(fontSize: 42)),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            // ❤️ بادج صغير لو الطاقة منخفضة
            if (energy != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: noEnergy
                        ? Colors.red.withValues(alpha: 0.8)
                        : Colors.black38,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite,
                        color: noEnergy ? Colors.white : Colors.redAccent,
                        size: 11,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$energy',
                        style: TextStyle(
                          color: noEnergy ? Colors.white : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
