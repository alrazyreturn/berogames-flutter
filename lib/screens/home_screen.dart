import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../providers/user_provider.dart';
import '../services/socket_service.dart';
import '../services/room_service.dart';
import '../services/notification_service.dart';
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
  final _socket      = SocketService();
  final _roomService = RoomService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupSocket());
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
        fromUserId:    fromUserId,
        fromName:      fromName,
        roomCode:      roomCode,
        categoryName:  categoryName,
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
      // مراقبة تجديد الـ Token
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

  // ─── حوار الدعوة ────────────────────────────────────────────────────────
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
                toUserId: fromUserId,   // رد للمضيف
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
              _acceptInvite(fromUserId: fromUserId, fromName: fromName, roomCode: roomCode);
            },
            child: const Text('✅ قبول', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // ─── قبول الدعوة والانضمام للغرفة ────────────────────────────────────────
  Future<void> _acceptInvite({
    required int    fromUserId,
    required String fromName,
    required String roomCode,
  }) async {
    final user  = context.read<UserProvider>().user;
    final token = context.read<UserProvider>().token;
    if (user == null || token == null) return;

    try {
      // انضمام REST
      final room = await _roomService.joinRoom(
        roomCode: roomCode,
        token:    token,
      );

      // إرسال رد القبول للمضيف
      _socket.respondToInvite(
        toUserId: fromUserId,  // ID المضيف اللي بعت الدعوة
        accepted: true,
        roomCode: roomCode,
      );

      // الانضمام للغرفة عبر socket كـ guest
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
                      // زر كيف تلعب
                      IconButton(
                        icon: const Icon(Icons.help_outline,
                            color: Colors.white70),
                        tooltip: 'كيف تلعب؟',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const HowToPlayScreen()),
                        ),
                      ),
                      // زر الأصدقاء
                      IconButton(
                        icon: const Icon(Icons.people, color: Colors.white70),
                        tooltip: 'الأصدقاء',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FriendsScreen()),
                        ),
                      ),
                      // زر تسجيل الخروج
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white54),
                        onPressed: () async {
                          await context.read<UserProvider>().logout();
                          if (!context.mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
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
                ),
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
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'النقاط: ${user?.totalScore ?? 0}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // سهم للإشارة بأنها قابلة للضغط
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
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CategoriesScreen()),
                      ),
                    ),
                    _ModeCard(
                      icon: '⚔️',
                      label: 'لعب ثنائي',
                      subtitle: 'تحدَّ صديقك',
                      color: const Color(0xFFFF6584),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DualMenuScreen()),
                      ),
                    ),
                    _ModeCard(
                      icon: '👥',
                      label: 'الأصدقاء',
                      subtitle: 'تحدّى أصدقاءك',
                      color: const Color(0xFF43D8C9),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FriendsScreen()),
                      ),
                    ),
                    _ModeCard(
                      icon: '🏆',
                      label: 'المتصدرون',
                      subtitle: 'أفضل اللاعبين',
                      color: const Color(0xFFFFD700),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LeaderboardScreen()),
                      ),
                    ),
                    _ModeCard(
                      icon: '📊',
                      label: 'إحصائياتي',
                      subtitle: 'تقدمك وأدائك',
                      color: const Color(0xFF43D8C9),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const StatsScreen()),
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
  final String   icon;
  final String   label;
  final String   subtitle;
  final Color    color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
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
      ),
    );
  }
}
