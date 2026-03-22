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

// ─── Design Tokens (Neon-Glass — consistent with the rest of the app) ─────────
const _cBg   = Color(0xFF0B1326);
const _cCard = Color(0xFF171F33);
const _cCyan    = Color(0xFF00FBFB);
const _cIndigo  = Color(0xFF6366F1);

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

  List<CategoryModel> _categories      = [];
  CategoryModel?      _selected;
  RoomModel?          _room;
  bool _loadingCategories = true;
  bool _creatingRoom      = false;
  bool    _guestJoined = false;
  String? _guestName;
  int?    _guestId;
  String? _guestAvatar;
  int     _guestLevel  = 1;

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
      backgroundColor: _cBg,
      // ─── AppBar نيون ──────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: _cCyan.withValues(alpha: 0.8)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'create_room.title'.tr(),
          style: const TextStyle(
            color: _cCyan,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end:   Alignment.bottomCenter,
              colors: [
                _cCyan.withValues(alpha: 0.06),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      body: _room == null ? _buildSetup() : _buildWaiting(),
    );
  }

  // ─── قبل إنشاء الغرفة: اختيار القسم ──────────────────────────────────────
  Widget _buildSetup() {
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── عنوان القسم ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 4, height: 20,
                  decoration: BoxDecoration(
                    color: _cCyan,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(color: _cCyan.withValues(alpha: 0.6), blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'create_room.choose_section'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          // ─── الشبكة ──────────────────────────────────────────────────────
          Expanded(
            child: _loadingCategories
                ? Center(
                    child: CircularProgressIndicator(
                        color: _cCyan, strokeWidth: 2))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:   2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing:  12,
                        childAspectRatio: 1.25,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (_, i) => _buildCategoryCard(_categories[i]),
                    ),
                  ),
          ),

          // ─── زر الإنشاء (ثابت في الأسفل) ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: _buildCreateButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(CategoryModel cat) {
    final isSelected = _selected?.id == cat.id;

    return GestureDetector(
      onTap: () => setState(() => _selected = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? _cCyan.withValues(alpha: 0.12)
              : _cCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? _cCyan : Colors.white.withValues(alpha: 0.07),
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:      _cCyan.withValues(alpha: 0.25),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // أيقونة مع توهج
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? _cCyan.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.04),
              ),
              child: Center(
                child: Text(
                  cat.icon,
                  style: TextStyle(fontSize: isSelected ? 28 : 26),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              cat.localizedName(context.locale.languageCode),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? _cCyan : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: _selected != null
              ? [_cCyan.withValues(alpha: 0.85), _cIndigo]
              : [Colors.white12, Colors.white.withValues(alpha: 0.06)],
        ),
        boxShadow: _selected != null
            ? [
                BoxShadow(
                  color:      _cCyan.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 1,
                  offset:     const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: ElevatedButton(
        onPressed: _creatingRoom ? null : _createRoom,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor:     Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
        ),
        child: _creatingRoom
            ? SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: _cBg, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.meeting_room_rounded,
                    color: _selected != null ? _cBg : Colors.white24,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'create_room.create_btn'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _selected != null ? _cBg : Colors.white24,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─── بعد إنشاء الغرفة: عرض الكود + انتظار ───────────────────────────────
  Widget _buildWaiting() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // أيقونة المنزل بتوهج
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape:  BoxShape.circle,
                color:  _cCyan.withValues(alpha: 0.08),
                border: Border.all(
                    color: _cCyan.withValues(alpha: 0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: _cCyan.withValues(alpha: 0.15), blurRadius: 30),
                ],
              ),
              child: Center(
                child: Text('🏠', style: const TextStyle(fontSize: 40)),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'create_room.share_code'.tr(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 20),

            // ─── كود الغرفة ───────────────────────────────────────────────
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
                padding: const EdgeInsets.symmetric(
                    vertical: 20, horizontal: 32),
                decoration: BoxDecoration(
                  color:        _cCyan.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(22),
                  border:       Border.all(
                      color: _cCyan.withValues(alpha: 0.6), width: 1.8),
                  boxShadow: [
                    BoxShadow(
                        color: _cCyan.withValues(alpha: 0.2),
                        blurRadius: 24, spreadRadius: 2),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _room!.roomCode,
                      style: TextStyle(
                        color:         _cCyan,
                        fontSize:      36,
                        fontWeight:    FontWeight.w900,
                        letterSpacing: 8,
                        shadows: [
                          Shadow(color: _cCyan.withValues(alpha: 0.7),
                              blurRadius: 12),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(Icons.copy_rounded,
                        color: _cCyan.withValues(alpha: 0.5), size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 36),

            // ─── حالة الانتظار ────────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _guestJoined
                  ? _buildGuestJoined()
                  : _buildWaitingIndicator(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestJoined() {
    return Column(
      key: const ValueKey('joined'),
      children: [
        // شارة الانضمام
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color:        Colors.greenAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.greenAccent.withValues(alpha: 0.4), width: 1.2),
            boxShadow: [
              BoxShadow(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  blurRadius: 16),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✅', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Text(
                'create_room.joined'.tr(
                    namedArgs: {'name': _guestName ?? 'common.opponent'.tr()}),
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // زر ابدأ اللعبة
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF00FBFB), Color(0xFF00C8C8)],
            ),
            boxShadow: [
              BoxShadow(
                color:      _cCyan.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 1,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _startGame,
            icon: const Icon(Icons.play_arrow_rounded,
                color: _cBg, size: 24),
            label: Text(
              'create_room.start_btn'.tr(),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _cBg,
                letterSpacing: 0.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor:     Colors.transparent,
              padding:         const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingIndicator() {
    return Column(
      key: const ValueKey('waiting'),
      children: [
        SizedBox(
          width: 40, height: 40,
          child: CircularProgressIndicator(
            color:       _cCyan,
            strokeWidth: 2.5,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'create_room.waiting'.tr(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
