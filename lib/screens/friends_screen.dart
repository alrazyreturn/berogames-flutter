import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../models/friend_model.dart';
import '../models/room_model.dart';
import '../providers/user_provider.dart';
import '../services/friends_service.dart';
import '../services/room_service.dart';
import '../services/socket_service.dart';
import '../services/energy_service.dart';
import '../services/ad_service.dart';
import 'add_friend_screen.dart';
import 'create_room_screen.dart';
import 'chat_screen.dart';

/// شاشة الأصدقاء الرئيسية
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final _service       = FriendsService();
  final _roomService   = RoomService();
  final _socket        = SocketService();
  final _energyService = EnergyService();
  late TabController _tabs;

  List<FriendModel>        _friends  = [];
  List<FriendRequestModel> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadAll();
    _setupSocket();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _socket.onOnlineStatus       = null;
    _socket.onGameInviteResult   = null;
    super.dispose();
  }

  void _setupSocket() {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    _socket.connect();
    _socket.registerOnline(userId: user.id, userName: user.name);

    _socket.onOnlineStatus = (statuses) {
      if (!mounted) return;
      setState(() {
        for (final f in _friends) {
          f.isOnline = statuses[f.userId] ?? false;
        }
      });
    };

    _socket.onGameInviteResult = (data) {
      if (!mounted) return;
      final accepted = data['accepted'] == true;
      final name     = data['responder_name'] ?? 'الصديق';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          accepted
              ? 'friends.accepted'.tr(namedArgs: {'name': name})
              : 'friends.rejected'.tr(namedArgs: {'name': name}),
        ),
        behavior: SnackBarBehavior.floating,
      ));
      if (accepted) {
        final roomCode = data['room_code'] as String?;
        if (roomCode != null) _navigateToWaiting(roomCode);
      }
    };
  }

  Future<void> _loadAll() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    try {
      final results = await Future.wait([
        _service.getFriends(token),
        _service.getRequests(token),
      ]);
      if (!mounted) return;
      setState(() {
        _friends  = results[0] as List<FriendModel>;
        _requests = results[1] as List<FriendRequestModel>;
        _loading  = false;
      });
      // جلب حالة الأونلاين
      if (_friends.isNotEmpty) {
        _socket.getOnlineStatus(_friends.map((f) => f.userId).toList());
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── تحدي صديق (مع check الطاقة) ────────────────────────────────────────
  Future<void> _challengeFriend(FriendModel friend) async {
    final token = context.read<UserProvider>().token;
    final user  = context.read<UserProvider>().user;
    if (token == null || user == null) return;

    // ✅ تحقق من الطاقة قبل إرسال التحدي
    try {
      final energyRes = await _energyService.getEnergy(token);
      final energy    = energyRes['energy'] as int? ?? 0;

      if (energy <= 0) {
        if (!mounted) return;
        _showNoEnergyDialog(
          token: token,
          onRecharged: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreateRoomScreen(inviteFriend: friend)),
          ),
        );
        return;
      }

      // استهلاك الطاقة ثم الانتقال
      final consumeRes = await _energyService.consumeEnergy(token);
      if (!mounted) return;
      if (consumeRes['can_play'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CreateRoomScreen(inviteFriend: friend)),
        );
      }
    } catch (_) {
      // لو في خطأ في الشبكة، اسمح بالتحدي
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CreateRoomScreen(inviteFriend: friend)),
      );
    }
  }

  // ─── dialog انتهاء الطاقة ────────────────────────────────────────────────
  void _showNoEnergyDialog({required String token, required VoidCallback onRecharged}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E3F),
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
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr(), style: const TextStyle(color: Colors.white38)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: Text('energy.watch_ad'.tr()),
            onPressed: () {
              Navigator.pop(context);
              // ✅ Rewarded Ad حقيقي من AdMob
              AdService().showRewarded(
                onRewarded: () async {
                  try {
                    await _energyService.rechargeEnergy(token);
                    if (!mounted) return;
                    onRecharged();
                  } catch (_) {}
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _navigateToWaiting(String roomCode) {
    // الـ Host ينتقل لشاشة الانتظار
    // في حالة قبول الدعوة، الغرفة موجودة بالفعل
  }

  Future<void> _acceptRequest(FriendRequestModel req) async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    try {
      await _service.acceptRequest(req.friendshipId, token);
      _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _deleteRelation(int friendshipId) async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    try {
      await _service.deleteFriend(friendshipId, token);
      _loadAll();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'friends.title'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white70),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddFriendScreen()),
              );
              _loadAll();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFF6C63FF),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: [
            Tab(text: 'friends.my_friends'.tr()),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('friends.requests'.tr()),
                  if (_requests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color:        const Color(0xFFFF6584),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_requests.length}',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : TabBarView(
              controller: _tabs,
              children: [
                _buildFriendsList(),
                _buildRequestsList(),
              ],
            ),
    );
  }

  // ─── قائمة الأصدقاء ───────────────────────────────────────────────────────
  Widget _buildFriendsList() {
    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👥', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text('friends.no_friends'.tr(),
                style: const TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddFriendScreen()),
              ).then((_) => _loadAll()),
              icon: const Icon(Icons.person_add),
              label: Text('friends.add_friend'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: const Color(0xFF6C63FF),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _friends.length,
        itemBuilder: (_, i) => _FriendTile(
          friend:      _friends[i],
          onChallenge: () => _challengeFriend(_friends[i]),
          onDelete:    () => _deleteRelation(_friends[i].friendshipId),
          onChat:      () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(friend: _friends[i]),
            ),
          ),
        ),
      ),
    );
  }

  // ─── طلبات الصداقة ────────────────────────────────────────────────────────
  Widget _buildRequestsList() {
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📭', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text('friends.no_requests'.tr(),
                style: const TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      itemBuilder: (_, i) => _RequestTile(
        request:  _requests[i],
        onAccept: () => _acceptRequest(_requests[i]),
        onReject: () => _deleteRelation(_requests[i].friendshipId),
      ),
    );
  }
}

// ─── بطاقة صديق ──────────────────────────────────────────────────────────────
class _FriendTile extends StatelessWidget {
  final FriendModel  friend;
  final VoidCallback onChallenge;
  final VoidCallback onDelete;
  final VoidCallback onChat;

  const _FriendTile({
    required this.friend,
    required this.onChallenge,
    required this.onDelete,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onChat,
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0xFF6C63FF).withValues(alpha: 0.15),
        highlightColor: const Color(0xFF6C63FF).withValues(alpha: 0.08),
        child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // أفاتار
          Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                child: Text(
                  friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '؟',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              // نقطة الأونلاين
              Positioned(
                bottom: 0, left: 0,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:  friend.isOnline ? Colors.greenAccent : Colors.grey,
                    border: Border.all(color: const Color(0xFF1A1A2E), width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // الاسم والنقاط
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 13),
                    const SizedBox(width: 3),
                    Text(
                      '${friend.totalScore} ${'common.points_unit'.tr()}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (friend.isOnline ? Colors.greenAccent : Colors.grey)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        friend.isOnline ? 'friends.online'.tr() : 'friends.offline'.tr(),
                        style: TextStyle(
                          color:    friend.isOnline ? Colors.greenAccent : Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // زر الشات
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded,
                color: Color(0xFF43D8C9), size: 22),
            tooltip: 'friends.chat_tooltip'.tr(),
            onPressed: onChat,
          ),

          // زر التحدي
          if (friend.isOnline)
            ElevatedButton(
              onPressed: onChallenge,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6584),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('friends.challenge'.tr(), style: const TextStyle(fontSize: 13)),
            )
          else
            IconButton(
              icon: const Icon(Icons.person_remove_outlined, color: Colors.white24),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF16213E),
                  title: Text('friends.delete_title'.tr(), style: const TextStyle(color: Colors.white)),
                  content: Text(
                    'friends.delete_msg'.tr(namedArgs: {'name': friend.name}),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('common.cancel'.tr(), style: const TextStyle(color: Colors.white54)),
                    ),
                    TextButton(
                      onPressed: () { Navigator.pop(context); onDelete(); },
                      child: Text('common.delete'.tr(), style: const TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
        ),
      ),
    );
  }
}

// ─── بطاقة طلب صداقة ─────────────────────────────────────────────────────────
class _RequestTile extends StatelessWidget {
  final FriendRequestModel request;
  final VoidCallback        onAccept;
  final VoidCallback        onReject;

  const _RequestTile({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.3),
            child: Text(
              request.name.isNotEmpty ? request.name[0].toUpperCase() : '؟',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text('${request.totalScore} ${'common.points_unit'.tr()}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          // قبول
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 30),
            onPressed: onAccept,
          ),
          // رفض
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 30),
            onPressed: onReject,
          ),
        ],
      ),
    );
  }
}
