import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../models/room_model.dart';
import '../providers/user_provider.dart';
import '../services/room_service.dart';
import '../services/socket_service.dart';
import 'dual_game_screen.dart';

/// شاشة الانضمام لغرفة بالكود
class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _codeCtrl    = TextEditingController();
  final _roomService = RoomService();
  final _socket      = SocketService();

  bool      _joining  = false;
  bool      _waiting  = false; // انتظار بدء اللعبة من الـ Host
  RoomModel? _room;
  String?   _hostName;

  @override
  void dispose() {
    _codeCtrl.dispose();
    if (_room == null) _socket.clearCallbacks();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('join_room.code_hint'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final token = context.read<UserProvider>().token;
    final user  = context.read<UserProvider>().user;
    if (token == null || user == null) return;

    setState(() => _joining = true);

    try {
      final room = await _roomService.joinRoom(roomCode: code, token: token);

      // الاتصال بـ WebSocket والانضمام كـ Guest
      _socket.connect();
      _socket.onGameStarted = (data) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DualGameScreen(
              room:             room,
              role:             'guest',
              myName:           user.name,
              guestName:        room.host.name,
              opponentId:       room.host.id,
              initialQuestions: data,
              opponentAvatar:   room.host.avatar,
              opponentLevel:    room.host.currentLevel,
            ),
          ),
        );
      };
      _socket.onError = (msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
        );
      };
      _socket.onOpponentDisconnected = (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('join_room.opponent_left'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      };

      _socket.joinRoom(
        roomCode: room.roomCode,
        userId:   user.id,
        userName: user.name,
        role:     'guest',
        lang:     context.locale.languageCode,
      );

      if (mounted) {
        setState(() {
          _room     = room;
          _hostName = room.host.name;
          _joining  = false;
          _waiting  = true;
        });
      }

    } on Exception catch (e) {
      if (mounted) {
        setState(() => _joining = false);
        String msg = e.toString();
        if (msg.contains('404')) msg = 'join_room.room_started'.tr();
        if (msg.contains('400')) msg = 'join_room.own_room'.tr();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
        );
      }
    }
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
          'join_room.title'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _waiting ? _buildWaiting() : _buildForm(),
    );
  }

  // ─── نموذج إدخال الكود ────────────────────────────────────────────────────
  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔗', style: TextStyle(fontSize: 70)),
          const SizedBox(height: 24),
          Text(
            'join_room.code_hint'.tr(),
            style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'join_room.ask_code'.tr(),
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          TextField(
            controller:    _codeCtrl,
            textAlign:     TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              color: Colors.white, fontSize: 28,
              fontWeight: FontWeight.bold, letterSpacing: 6,
            ),
            maxLength:  6,
            decoration: InputDecoration(
              counterText:  '',
              hintText:     'XXXXXX',
              hintStyle:    const TextStyle(color: Colors.white24, letterSpacing: 6),
              filled:       true,
              fillColor:    Colors.white.withValues(alpha: 0.07),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:   BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:   const BorderSide(color: Color(0xFF6C63FF), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _joining ? null : _joinRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6584),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _joining
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'join_room.join_btn'.tr(),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── انتظار الـ Host يبدأ اللعبة ──────────────────────────────────────────
  Widget _buildWaiting() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✅', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text(
              'join_room.joined_host'.tr(namedArgs: {'name': _hostName ?? ''}),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'join_room.waiting_host'.tr(),
              style: const TextStyle(color: Colors.white54, fontSize: 15),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Color(0xFF6C63FF)),
          ],
        ),
      ),
    );
  }
}
