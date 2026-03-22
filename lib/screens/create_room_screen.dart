import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../models/category_model.dart';
import '../models/friend_model.dart';
import '../models/room_model.dart';
import '../providers/user_provider.dart';
import '../services/game_service.dart';
import '../services/room_service.dart';
import '../services/socket_service.dart';
import 'dual_game_screen.dart';

/// شاشة إنشاء غرفة: اختيار القسم → عرض الكود → انتظار اللاعب الثاني
class CreateRoomScreen extends StatefulWidget {
  final FriendModel? inviteFriend; // لو جاي من شاشة الأصدقاء
  const CreateRoomScreen({super.key, this.inviteFriend});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _gameService = GameService();
  final _roomService = RoomService();
  final _socket      = SocketService();

  List<CategoryModel> _categories  = [];
  CategoryModel?      _selected;
  RoomModel?          _room;
  bool _loadingCategories = true;
  bool _creatingRoom      = false;
  bool    _guestJoined = false;
  String? _guestName;
  int?    _guestId;
  String? _guestAvatar;
  int     _guestLevel  = 1;

  @override
  bool _catsLoaded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_catsLoaded) {
      _catsLoaded = true;
      _loadCategories();
    }
  }

  @override
  void dispose() {
    if (_room == null) _socket.clearCallbacks();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _gameService.getCategories(
        lang: context.locale.languageCode,
      );
      if (mounted) setState(() { _categories = cats; _loadingCategories = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  Future<void> _createRoom() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('create_room.select_first'.tr()), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final token = context.read<UserProvider>().token;
    final user  = context.read<UserProvider>().user;
    if (token == null || user == null) return;

    setState(() => _creatingRoom = true);

    try {
      final room = await _roomService.createRoom(
        categoryId: _selected!.id,
        token:      token,
      );

      // الاتصال بـ WebSocket والانضمام كـ Host
      _socket.connect();
      _socket.onPlayerJoined = (data) {
        if (!mounted) return;
        setState(() {
          _guestJoined  = true;
          _guestName    = data['guest_name'] ?? 'common.opponent'.tr();
          _guestId      = data['guest_id'] != null ? int.tryParse('${data['guest_id']}') : null;
          _guestAvatar  = data['guest_avatar'] as String?;
          _guestLevel   = (data['guest_level'] as int?) ?? 1;
        });
      };
      _socket.onError = (msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
        );
      };

      _socket.joinRoom(
        roomCode:   room.roomCode,
        userId:     user.id,
        userName:   user.name,
        userAvatar: user.avatar,
        role:       'host',
        lang:       context.locale.languageCode,
      );

      // لو في صديق مدعو → ابعت له دعوة تلقائياً
      if (widget.inviteFriend != null) {
        _guestName = widget.inviteFriend!.name;
        _socket.sendGameInvite(
          toUserId:     widget.inviteFriend!.userId,
          fromName:     user.name,
          roomCode:     room.roomCode,
          categoryName: _selected?.localizedName(context.locale.languageCode) ?? '',
        );
        _socket.onInviteSent = (data) {
          if (!mounted) return;
          final success = data['success'] == true;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(success
                ? 'create_room.invite_sent'.tr(namedArgs: {'name': widget.inviteFriend!.name})
                : (data['message'] ?? 'create_room.offline'.tr())),
            behavior: SnackBarBehavior.floating,
          ));
        };
      }

      if (mounted) setState(() { _room = room; _creatingRoom = false; });

    } catch (e) {
      if (mounted) {
        setState(() => _creatingRoom = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.error_prefix'.tr(namedArgs: {'msg': e.toString()})),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _startGame() {
    if (_room == null) return;
    final user = context.read<UserProvider>().user;

    _socket.startGame(
      roomCode:   _room!.roomCode,
      categoryId: _room!.categoryId,
      roomId:     _room!.roomId,
      difficulty: 1,
      lang:       context.locale.languageCode,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DualGameScreen(
          room:           _room!,
          role:           'host',
          myName:         user?.name ?? 'common.you'.tr(),
          guestName:      _guestName ?? 'common.opponent'.tr(),
          opponentId:     _guestId ?? widget.inviteFriend?.userId,
          opponentAvatar: _guestAvatar,
          opponentLevel:  _guestLevel,
        ),
      ),
    );
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
          'create_room.title'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _room == null ? _buildSetup() : _buildWaiting(),
    );
  }

  // ─── قبل إنشاء الغرفة: اختيار القسم ─────────────────────────────────────
  Widget _buildSetup() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'create_room.choose_section'.tr(),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _loadingCategories
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
              : Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.3,
                    children: _categories.map((cat) {
                      final isSelected = _selected?.id == cat.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selected = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6C63FF).withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF6C63FF)
                                  : Colors.white12,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(cat.icon, style: const TextStyle(fontSize: 32)),
                              const SizedBox(height: 8),
                              Text(
                                cat.localizedName(context.locale.languageCode),
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _creatingRoom ? null : _createRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _creatingRoom
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text('create_room.create_btn'.tr(), style: const TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── بعد إنشاء الغرفة: عرض الكود + انتظار ────────────────────────────────
  Widget _buildWaiting() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏠', style: TextStyle(fontSize: 70)),
          const SizedBox(height: 20),
          Text(
            'create_room.share_code'.tr(),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),

          // ─── كود الغرفة ──────────────────────────────────────────────────
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _room!.roomCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('create_room.copied'.tr()),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
              decoration: BoxDecoration(
                color:        const Color(0xFF6C63FF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: const Color(0xFF6C63FF), width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _room!.roomCode,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 38,
                      fontWeight: FontWeight.bold, letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.copy, color: Colors.white54, size: 22),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ─── حالة الانتظار ────────────────────────────────────────────────
          _guestJoined
              ? Column(
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text(
                      'create_room.joined'.tr(namedArgs: {'name': _guestName ?? 'common.opponent'.tr()}),
                      style: const TextStyle(
                        color: Colors.greenAccent, fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _startGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'create_room.start_btn'.tr(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF6C63FF)),
                    const SizedBox(height: 16),
                    Text(
                      'create_room.waiting'.tr(),
                      style: const TextStyle(color: Colors.white54, fontSize: 15),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}
