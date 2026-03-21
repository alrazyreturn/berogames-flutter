import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../models/friend_model.dart';
import '../providers/user_provider.dart';
import '../services/friends_service.dart';
import '../services/socket_service.dart';
import '../services/energy_service.dart';
import '../services/ad_service.dart';
import '../services/chat_service.dart';
import '../widgets/user_profile_sheet.dart';
import 'add_friend_screen.dart';
import 'create_room_screen.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const _cBg      = Color(0xFF0B1326);
const _cSurface = Color(0xFF131B2E);
const _cCard    = Color(0xFF171F33);
const _cCyan    = Color(0xFF00FBFB);
const _cIndigo  = Color(0xFF6366F1);
const _cNavBg   = Color(0xFF10102B);

/// شاشة الأصدقاء الرئيسية
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final _service       = FriendsService();
  final _socket        = SocketService();
  final _energyService = EnergyService();
  final _chatService   = ChatService();
  late TabController _tabs;

  List<FriendModel>        _friends       = [];
  List<FriendRequestModel> _requests      = [];
  List<ConversationModel>  _conversations = [];
  Map<int, int>            _unreadCounts  = {};
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadAll();
    _setupSocket();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _socket.onOnlineStatus        = null;
    _socket.onGameInviteResult    = null;
    _socket.onChatMessageReceived = null;
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

    _socket.onChatMessageReceived = (data) {
      if (!mounted) return;
      final senderId = data['sender_id'] as int?;
      if (senderId == null) return;
      setState(() {
        _unreadCounts[senderId] = (_unreadCounts[senderId] ?? 0) + 1;
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
        backgroundColor: _cCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        _chatService.getUnreadPerFriend(token: token),
        _chatService.getConversations(token: token),
      ]);
      if (!mounted) return;
      setState(() {
        _friends       = results[0] as List<FriendModel>;
        _requests      = results[1] as List<FriendRequestModel>;
        _unreadCounts  = results[2] as Map<int, int>;
        _conversations = results[3] as List<ConversationModel>;
        _loading       = false;
      });
      if (_friends.isNotEmpty) {
        _socket.getOnlineStatus(_friends.map((f) => f.userId).toList());
      }
    } catch (e, st) {
      debugPrint('❌ [FriendsScreen] _loadAll error: $e');
      debugPrint('❌ [FriendsScreen] stacktrace: $st');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── تحدي صديق ───────────────────────────────────────────────────────────
  Future<void> _challengeFriend(FriendModel friend) async {
    final token = context.read<UserProvider>().token;
    final user  = context.read<UserProvider>().user;
    if (token == null || user == null) return;
    try {
      final energyRes = await _energyService.getEnergy(token);
      final energy    = energyRes['energy'] as int? ?? 0;
      if (energy <= 0) {
        if (!mounted) return;
        _showNoEnergyDialog(
          token: token,
          onRecharged: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => CreateRoomScreen(inviteFriend: friend))),
        );
        return;
      }
      final consumeRes = await _energyService.consumeEnergy(token);
      if (!mounted) return;
      if (consumeRes['can_play'] == true) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => CreateRoomScreen(inviteFriend: friend)));
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => CreateRoomScreen(inviteFriend: friend)));
    }
  }

  void _showNoEnergyDialog({required String token, required VoidCallback onRecharged}) {
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
              children: List.generate(5, (i) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 3),
                child: Icon(Icons.favorite_border, color: Colors.white24, size: 28),
              )),
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
            child: Text('common.cancel'.tr(),
                style: const TextStyle(color: Colors.white38)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _cIndigo,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: Text('energy.watch_ad'.tr()),
            onPressed: () {
              Navigator.pop(context);
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

  void _navigateToWaiting(String roomCode) {}

  Future<void> _acceptRequest(FriendRequestModel req) async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    try {
      await _service.acceptRequest(req.friendshipId, token);
      _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: _cCard,
            behavior: SnackBarBehavior.floating,
          ),
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
                active: true,
                onTap:  () {},
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
    final user = context.read<UserProvider>().user;

    return Scaffold(
      backgroundColor: _cBg,
      bottomNavigationBar: _buildBottomNav(),

      // ─── FAB: إضافة صديق ──────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddFriendScreen()));
          _loadAll();
        },
        backgroundColor: _cCyan,
        foregroundColor: _cNavBg,
        elevation: 0,
        shape: const CircleBorder(),
        child: const Icon(Icons.person_add_rounded, size: 26),
      ),

      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // أفاتار المستخدم
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _cCyan, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _cCyan.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: _cCyan.withValues(alpha: 0.12),
                      backgroundImage: user?.avatar != null
                          ? NetworkImage(user!.avatar!)
                          : null,
                      child: user?.avatar == null
                          ? Icon(Icons.person_rounded,
                              color: _cCyan, size: 22)
                          : null,
                    ),
                  ),

                  // العنوان
                  Text(
                    'friends.title'.tr(),
                    style: const TextStyle(
                      color: _cCyan,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),

                  // زر القائمة
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _cSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.menu_rounded,
                        color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── Tab Selector (pill style) ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedBuilder(
                animation: _tabs,
                builder: (context2, child2) => Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _cSurface,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      _TabPill(
                        label: 'friends.my_friends'.tr(),
                        active: _tabs.index == 0,
                        onTap:  () => _tabs.animateTo(0),
                      ),
                      _TabPill(
                        label: 'friends.requests'.tr(),
                        active: _tabs.index == 1,
                        onTap:  () => _tabs.animateTo(1),
                        badge: _requests.isNotEmpty ? _requests.length : null,
                      ),
                      _TabPill(
                        label: 'friends.chats'.tr(),
                        active: _tabs.index == 2,
                        onTap:  () => _tabs.animateTo(2),
                        badge: _conversations.fold<int>(
                            0, (s, c) => s + c.unreadCount) > 0
                            ? _conversations.fold<int>(
                                0, (s, c) => s + c.unreadCount)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ─── شريط البحث ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: _cSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded,
                        color: Colors.white38, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'friends.search_hint'.tr(),
                          hintStyle: const TextStyle(
                              color: Colors.white38, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ─── المحتوى ──────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _cCyan))
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _buildFriendsList(),
                        _buildRequestsList(),
                        _buildConversationsList(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── قائمة الأصدقاء ───────────────────────────────────────────────────────
  Widget _buildFriendsList() {
    final filtered = _searchQuery.isEmpty
        ? _friends
        : _friends
            .where((f) =>
                f.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded,
                color: Colors.white24, size: 70),
            const SizedBox(height: 16),
            Text('friends.no_friends'.tr(),
                style: const TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddFriendScreen()))
                  .then((_) => _loadAll()),
              icon: const Icon(Icons.person_add_rounded),
              label: Text('friends.add_friend'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cCyan,
                foregroundColor: _cNavBg,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Text('friends.no_results'.tr(),
            style: const TextStyle(color: Colors.white38, fontSize: 14)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: _cCyan,
      backgroundColor: _cSurface,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
        itemCount: filtered.length,
        itemBuilder: (_, i) => _FriendTile(
          friend:       filtered[i],
          unreadCount:  _unreadCounts[filtered[i].userId] ?? 0,
          onChallenge:  () => _challengeFriend(filtered[i]),
          onDelete:     () => _confirmDelete(filtered[i]),
          onAvatarTap:  () => _showFriendProfile(filtered[i]),
          onChat:       () {
            setState(() => _unreadCounts.remove(filtered[i].userId));
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => ChatScreen(friend: filtered[i])));
          },
        ),
      ),
    );
  }

  void _confirmDelete(FriendModel friend) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('friends.delete_title'.tr(),
            style: const TextStyle(color: Colors.white)),
        content: Text(
          'friends.delete_msg'.tr(namedArgs: {'name': friend.name}),
          style: const TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr(),
                style: const TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRelation(friend.friendshipId);
            },
            child: Text('common.delete'.tr(),
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // ─── بروفايل الصديق (bottom sheet) ───────────────────────────────────────
  void _showFriendProfile(FriendModel friend) async {
    final result = await showModalBottomSheet<String>(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: false,
      builder: (_) => UserProfileSheet(
        userId:       friend.userId,
        name:         friend.name,
        avatar:       friend.avatar,
        score:        friend.totalScore,
        isOnline:     friend.isOnline,
        friendshipId: friend.friendshipId,
      ),
    );
    if (result == 'unfollowed' && mounted) _loadAll();
  }

  // ─── عرض بروفايل من محادثة ────────────────────────────────────────────────
  void _showConvProfile(ConversationModel conv) async {
    await showModalBottomSheet<String>(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: false,
      builder: (_) => UserProfileSheet(
        userId: conv.userId,
        name:   conv.name,
        avatar: conv.avatar,
      ),
    );
    _loadAll();
  }

  // ─── قائمة المحادثات ──────────────────────────────────────────────────────
  Widget _buildConversationsList() {
    if (_conversations.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded,
              color: Colors.white24, size: 70),
          const SizedBox(height: 16),
          Text('friends.no_chats'.tr(),
              style: const TextStyle(color: Colors.white54, fontSize: 16)),
        ],
      ));
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      color: _cCyan,
      backgroundColor: _cSurface,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
        itemCount: _conversations.length,
        itemBuilder: (_, i) {
          final c = _conversations[i];
          final ringColor = [_cCyan, const Color(0xFFFF6584),
            const Color(0xFFFFD700), _cIndigo,
            Colors.greenAccent, Colors.orangeAccent][c.userId % 6];
          return GestureDetector(
            onTap: () {
              setState(() => _unreadCounts.remove(c.userId));
              // نبني FriendModel مؤقت للانتقال لشاشة الشات
              final tempFriend = FriendModel(
                friendshipId: 0,
                userId:       c.userId,
                name:         c.name,
                avatar:       c.avatar,
              );
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreen(friend: tempFriend)))
                  .then((_) => _loadAll());
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color:        _cCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  // أفاتار (قابل للضغط لعرض البروفايل)
                  GestureDetector(
                    onTap: () => _showConvProfile(c),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ringColor, width: 2),
                        boxShadow: [BoxShadow(
                            color: ringColor.withValues(alpha: 0.35),
                            blurRadius: 8)],
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: ringColor.withValues(alpha: 0.15),
                        backgroundImage: c.avatar != null
                            ? NetworkImage(c.avatar!) : null,
                        child: c.avatar == null
                            ? Text(c.name.isNotEmpty
                                ? c.name[0].toUpperCase() : '؟',
                              style: TextStyle(color: ringColor,
                                  fontWeight: FontWeight.bold, fontSize: 16))
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // اسم + آخر رسالة
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(c.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ),
                  // unread badge
                  if (c.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:        _cCyan,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(
                            color: _cCyan.withValues(alpha: 0.4),
                            blurRadius: 8)],
                      ),
                      child: Text(
                        c.unreadCount > 99
                            ? '99+' : '${c.unreadCount}',
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
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
            const Icon(Icons.mark_email_unread_rounded,
                color: Colors.white24, size: 70),
            const SizedBox(height: 16),
            Text('friends.no_requests'.tr(),
                style: const TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: _requests.length,
      itemBuilder: (_, i) => _RequestTile(
        request:  _requests[i],
        onAccept: () => _acceptRequest(_requests[i]),
        onReject: () => _deleteRelation(_requests[i].friendshipId),
      ),
    );
  }
}

// ─── Tab Pill ─────────────────────────────────────────────────────────────────
class _TabPill extends StatelessWidget {
  final String   label;
  final bool     active;
  final VoidCallback onTap;
  final int?     badge;

  const _TabPill({
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? _cCyan : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: active
                ? [BoxShadow(
                    color: _cCyan.withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: active ? _cNavBg : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: active
                        ? _cNavBg.withValues(alpha: 0.3)
                        : const Color(0xFFFF6584),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      color: active ? _cNavBg : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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

// ─── بطاقة صديق ──────────────────────────────────────────────────────────────
class _FriendTile extends StatelessWidget {
  final FriendModel  friend;
  final int          unreadCount;
  final VoidCallback onChallenge;
  final VoidCallback onDelete;
  final VoidCallback onChat;
  final VoidCallback onAvatarTap;

  const _FriendTile({
    required this.friend,
    required this.unreadCount,
    required this.onChallenge,
    required this.onDelete,
    required this.onChat,
    required this.onAvatarTap,
  });

  // ألوان الحلقة (عشوائية لكل مستخدم)
  static const _ringColors = [
    _cCyan,
    Color(0xFFFF6584),
    Color(0xFFFFD700),
    Color(0xFF6366F1),
    Colors.greenAccent,
    Colors.orangeAccent,
  ];

  @override
  Widget build(BuildContext context) {
    final ringColor = _ringColors[friend.userId % _ringColors.length];

    return GestureDetector(
      onTap: onChat,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _cCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            // ─── أزرار اليسار ─────────────────────────────────────────
            // زر حذف
            _CircleBtn(
              icon:  Icons.person_remove_rounded,
              color: Colors.white24,
              onTap: onDelete,
            ),
            const SizedBox(width: 8),
            // زر شات مع badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                _CircleBtn(
                  icon:  Icons.chat_bubble_rounded,
                  color: _cCyan,
                  onTap: onChat,
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -4,
                    left: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints: const BoxConstraints(
                          minWidth: 17, minHeight: 17),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6584),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),

            const Spacer(),

            // ─── الاسم والنقاط ────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  friend.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${friend.totalScore} ${'common.points_unit'.tr()}',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  friend.isOnline
                      ? 'friends.online'.tr()
                      : 'friends.offline'.tr(),
                  style: TextStyle(
                    color: friend.isOnline
                        ? _cCyan
                        : Colors.white38,
                    fontSize: 11,
                    fontWeight: friend.isOnline
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 12),

            // ─── الأفاتار (قابل للضغط) ────────────────────────────────
            GestureDetector(
              onTap: onAvatarTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ringColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: ringColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: ringColor.withValues(alpha: 0.15),
                      backgroundImage: friend.avatar != null
                          ? NetworkImage(friend.avatar!)
                          : null,
                      child: friend.avatar == null
                          ? Text(
                              friend.name.isNotEmpty
                                  ? friend.name[0].toUpperCase()
                                  : '؟',
                              style: TextStyle(
                                color: ringColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                  ),
                  // نقطة الحالة
                  Positioned(
                    bottom: 2,
                    left: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: friend.isOnline
                            ? Colors.greenAccent
                            : Colors.grey.shade600,
                        border: Border.all(color: _cBg, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── زر دائري صغير ───────────────────────────────────────────────────────────
class _CircleBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;

  const _CircleBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, color: color, size: 18),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: _cIndigo.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // قبول
          GestureDetector(
            onTap: onAccept,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.greenAccent.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.greenAccent, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          // رفض
          GestureDetector(
            onTap: onReject,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.redAccent, size: 20),
            ),
          ),

          const Spacer(),

          // الاسم والنقاط
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                request.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${request.totalScore} ${'common.points_unit'.tr()}',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(width: 12),

          // أفاتار
          CircleAvatar(
            radius: 26,
            backgroundColor: _cIndigo.withValues(alpha: 0.2),
            backgroundImage: request.avatar != null
                ? NetworkImage(request.avatar!)
                : null,
            child: request.avatar == null
                ? Text(
                    request.name.isNotEmpty
                        ? request.name[0].toUpperCase()
                        : '؟',
                    style: const TextStyle(
                      color: _cIndigo,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
