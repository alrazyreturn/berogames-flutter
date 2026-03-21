import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';
import 'notification_service.dart';
import 'sound_service.dart';

/// SocketService - Singleton يدير اتصال WebSocket مع السيرفر
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool get isConnected => _socket?.connected ?? false;

  // ─── حفظ بيانات المستخدم لإعادة التسجيل بعد الرجوع من الخلفية ───────────
  int?    _savedUserId;
  String? _savedUserName;

  // ─── معرف صديق الشات المفتوح حالياً (null = شاشة الشات مغلقة) ───────────
  // تُعيِّنه ChatScreen عند الفتح وتُصفِّره عند الإغلاق
  int? activeChatFriendId;

  // ─── Callbacks (تُعيّن من الشاشات) ───────────────────────────────────────
  Function(Map<String, dynamic>)? onPlayerJoined;
  Function(Map<String, dynamic>)? onGameStarted;
  Function(Map<String, dynamic>)? onScoreUpdate;
  Function(Map<String, dynamic>)? onOpponentFinished;
  Function(Map<String, dynamic>)? onGameOver;
  Function(Map<String, dynamic>)? onOpponentDisconnected;
  Function(String)?               onError;

  // ─── Auto Matchmaking Callbacks ──────────────────────────────────────────
  Function(Map<String, dynamic>)? onMatchFound;
  Function(Map<String, dynamic>)? onInQueue;

  // ─── Friends / Online Callbacks ───────────────────────────────────────────
  Function(Map<int, bool>)?       onOnlineStatus;
  Function(Map<String, dynamic>)? onGameInviteReceived;
  Function(Map<String, dynamic>)? onGameInviteResult;
  Function(Map<String, dynamic>)? onInviteSent;

  // ─── Friends Realtime Callbacks ──────────────────────────────────────────
  Function(Map<String, dynamic>)? onFriendshipAccepted;

  // ─── WebRTC Signaling Callbacks ───────────────────────────────────────────
  Function(Map<String, dynamic>)? onWebRtcOffer;
  Function(Map<String, dynamic>)? onWebRtcAnswer;
  Function(Map<String, dynamic>)? onWebRtcIceCandidate;
  Function(bool)?                  onWebRtcMicStatus; // حالة ميك الخصم

  // ─── Chat Callbacks ───────────────────────────────────────────────────────
  Function(Map<String, dynamic>)? onChatMessageReceived;
  Function(Map<String, dynamic>)? onChatMessageSent;
  Function(Map<String, dynamic>)? onChatTyping;
  Function(Map<String, dynamic>)? onChatMessageDeleted;
  Function(Map<String, dynamic>)? onChatBlocked;

  // ─── الاتصال بالسيرفر ────────────────────────────────────────────────────
  void connect({int? userId, String? userName}) {
    if (_socket != null && _socket!.connected) {
      // متصل بالفعل — فقط أعد التسجيل لو طُلب
      if (userId != null && userName != null) {
        registerOnline(userId: userId, userName: userName);
      }
      return;
    }

    // لو Socket موجود لكن منقطع — أعد الاتصال بدلاً من إنشاء جديد
    if (_socket != null && !_socket!.connected) {
      _socket!.connect();
      if (userId != null && userName != null) {
        _socket!.once('connect', (_) {
          registerOnline(userId: userId, userName: userName);
        });
      }
      return;
    }

    _socket = IO.io(
      ApiConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      print('✅ Socket connected: ${_socket!.id}');
      if (userId != null && userName != null) {
        registerOnline(userId: userId, userName: userName);
      }
    });

    _socket!.onDisconnect((_) {
      print('❌ Socket disconnected');
    });

    _socket!.onConnectError((err) {
      print('⚠️ Socket connect error: $err');
      onError?.call('فشل الاتصال بالسيرفر');
    });

    // ─── Incoming Events ─────────────────────────────────────────────────
    _socket!.on('player_joined', (data) {
      onPlayerJoined?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('game_started', (data) {
      onGameStarted?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('score_update', (data) {
      onScoreUpdate?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('opponent_finished', (data) {
      onOpponentFinished?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('game_over', (data) {
      onGameOver?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('opponent_disconnected', (data) {
      onOpponentDisconnected?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('error_msg', (data) {
      onError?.call(data['message'] ?? 'خطأ غير معروف');
    });

    // ─── Auto Matchmaking Events ─────────────────────────────────────────
    _socket!.on('match_found', (data) {
      onMatchFound?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('in_queue', (data) {
      onInQueue?.call(Map<String, dynamic>.from(data));
    });

    // ─── Friends / Online Events ──────────────────────────────────────────
    _socket!.on('online_status', (data) {
      final map = <int, bool>{};
      (data as Map).forEach((k, v) {
        map[int.tryParse(k.toString()) ?? 0] = v == true;
      });
      onOnlineStatus?.call(map);
    });

    _socket!.on('game_invite_received', (data) {
      onGameInviteReceived?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('game_invite_result', (data) {
      onGameInviteResult?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('invite_sent', (data) {
      onInviteSent?.call(Map<String, dynamic>.from(data));
    });

    // ─── Friends Realtime Events ─────────────────────────────────────────
    _socket!.on('friendship_accepted', (data) {
      onFriendshipAccepted?.call(Map<String, dynamic>.from(data));
    });

    // ─── WebRTC Signaling Events ──────────────────────────────────────────
    _socket!.on('webrtc_offer', (data) {
      onWebRtcOffer?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('webrtc_answer', (data) {
      onWebRtcAnswer?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('webrtc_ice_candidate', (data) {
      onWebRtcIceCandidate?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('webrtc_mic_status', (data) {
      onWebRtcMicStatus?.call(data['mic_on'] == true);
    });

    // ─── Chat Events ─────────────────────────────────────────────────────
    _socket!.on('chat_message_received', (data) {
      final msg      = Map<String, dynamic>.from(data);
      final senderId = msg['sender_id'] as int?;
      // إذا شاشة الشات مع هذا الصديق مغلقة → أظهر foreground notification
      if (senderId != null && senderId != activeChatFriendId) {
        _showForegroundChatNotif(msg);
      }
      onChatMessageReceived?.call(msg);
    });

    _socket!.on('chat_message_sent', (data) {
      onChatMessageSent?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('chat_typing', (data) {
      onChatTyping?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('chat_message_deleted', (data) {
      onChatMessageDeleted?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('chat_blocked', (data) {
      onChatBlocked?.call(Map<String, dynamic>.from(data));
    });
  }

  // ─── الانضمام لغرفة ──────────────────────────────────────────────────────
  void joinRoom({
    required String roomCode,
    required int    userId,
    required String userName,
    required String role,   // 'host' أو 'guest'
    String          lang = 'ar',
  }) {
    _socket?.emit('join_room', {
      'room_code': roomCode,
      'user_id':   userId,
      'user_name': userName,
      'role':      role,
      'lang':      lang,
    });
  }

  // ─── Host يبدأ اللعبة ────────────────────────────────────────────────────
  void startGame({
    required String roomCode,
    required int    categoryId,
    required int    roomId,
    required int    difficulty,
    String          lang = 'ar',
  }) {
    _socket?.emit('start_game', {
      'room_code':   roomCode,
      'category_id': categoryId,
      'room_id':     roomId,
      'difficulty':  difficulty,
      'lang':        lang,
    });
  }

  // ─── إرسال إجابة ─────────────────────────────────────────────────────────
  void submitAnswer({
    required String roomCode,
    required bool   isCorrect,
    required int    scoreEarned,
  }) {
    _socket?.emit('submit_answer', {
      'room_code':   roomCode,
      'is_correct':  isCorrect,
      'score_earned': scoreEarned,
    });
  }

  // ─── اللاعب أنهى كل الأسئلة ──────────────────────────────────────────────
  void playerFinished({
    required String roomCode,
    required int    finalScore,
  }) {
    _socket?.emit('player_finished', {
      'room_code':   roomCode,
      'final_score': finalScore,
    });
  }

  // ─── Friends / Online ─────────────────────────────────────────────────────
  void registerOnline({ required int userId, required String userName }) {
    _savedUserId   = userId;   // احفظ للاستخدام عند العودة من الخلفية
    _savedUserName = userName;
    _socket?.emit('user_online', { 'user_id': userId, 'user_name': userName });
  }

  void getOnlineStatus(List<int> userIds) {
    _socket?.emit('get_online_status', { 'user_ids': userIds });
  }

  void sendGameInvite({
    required int    toUserId,
    required String fromName,
    required String roomCode,
    String          categoryName = '',
  }) {
    _socket?.emit('send_game_invite', {
      'to_user_id':    toUserId,
      'from_name':     fromName,
      'room_code':     roomCode,
      'category_name': categoryName,
    });
  }

  void respondToInvite({
    required int    toUserId,
    required bool   accepted,
    required String roomCode,
  }) {
    _socket?.emit('game_invite_response', {
      'to_user_id': toUserId,
      'accepted':   accepted,
      'room_code':  roomCode,
    });
  }

  // ─── Chat ─────────────────────────────────────────────────────────────────
  void sendChatMessage({ required int toUserId, required String message }) {
    _socket?.emit('send_chat_message', {
      'to_user_id': toUserId,
      'message':    message,
    });
  }

  void sendTyping({ required int toUserId, required bool isTyping }) {
    _socket?.emit('chat_typing', {
      'to_user_id': toUserId,
      'is_typing':  isTyping,
    });
  }

  void deleteChatMessage({ required int messageId, required int toUserId }) {
    _socket?.emit('delete_chat_message', {
      'message_id':  messageId,
      'to_user_id':  toUserId,
    });
  }

  // ─── WebRTC Signaling Emit ────────────────────────────────────────────────
  void sendWebRtcOffer({ required String roomCode, required Map<String, dynamic> sdp }) {
    _socket?.emit('webrtc_offer', { 'room_code': roomCode, 'sdp': sdp });
  }

  void sendWebRtcAnswer({ required String roomCode, required Map<String, dynamic> sdp }) {
    _socket?.emit('webrtc_answer', { 'room_code': roomCode, 'sdp': sdp });
  }

  void sendWebRtcIceCandidate({ required String roomCode, required Map<String, dynamic> candidate }) {
    _socket?.emit('webrtc_ice_candidate', { 'room_code': roomCode, 'candidate': candidate });
  }

  void sendWebRtcMicStatus({ required String roomCode, required bool micOn }) {
    _socket?.emit('webrtc_mic_status', { 'room_code': roomCode, 'mic_on': micOn });
  }

  // ─── App Lifecycle: Background / Foreground ───────────────────────────────
  // عند الخلفية: قطع الاتصال كلياً → disconnect event يُزيله من onlineUsers فوراً
  void emitBackground() {
    _socket?.disconnect();
  }

  // عند العودة: أعد الاتصال وسجّل online بنفس بيانات المستخدم
  void emitForeground() {
    if (_savedUserId != null && _savedUserName != null) {
      connect(userId: _savedUserId, userName: _savedUserName);
    } else {
      _socket?.connect();
    }
  }

  // ─── Auto Matchmaking ─────────────────────────────────────────────────────
  void findMatch({ required int userId, required String userName, String lang = 'ar' }) {
    _socket?.emit('find_match', { 'user_id': userId, 'user_name': userName, 'lang': lang });
  }

  void cancelMatch() {
    _socket?.emit('cancel_match');
  }

  // ─── Foreground chat notification ────────────────────────────────────────
  // تُظهر إشعاراً محلياً + صوتاً عند استقبال رسالة والشات مع ذلك الصديق مغلق
  void _showForegroundChatNotif(Map<String, dynamic> msg) {
    final senderName = (msg['sender_name'] as String?)?.isNotEmpty == true
        ? msg['sender_name'] as String
        : 'صديق';
    final senderId = msg['sender_id']?.toString() ?? '';
    final text     = msg['message'] as String? ?? '';
    NotificationService().showChatLocalNotification(
      senderName: senderName,
      message:    text,
      senderId:   senderId,
    );
    SoundService().playChatNotify();
  }

  // ─── قطع الاتصال ─────────────────────────────────────────────────────────
  void disconnect() {
    _clearCallbacks();
    _socket?.disconnect();
    _socket = null;
  }

  // ─── مسح الـ Callbacks عند مغادرة الشاشة ────────────────────────────────
  void _clearCallbacks() {
    onPlayerJoined        = null;
    onGameStarted         = null;
    onScoreUpdate         = null;
    onOpponentFinished    = null;
    onGameOver            = null;
    onOpponentDisconnected = null;
    onError               = null;
    onMatchFound           = null;
    onInQueue              = null;
    onOnlineStatus         = null;
    onGameInviteReceived   = null;
    onGameInviteResult     = null;
    onInviteSent           = null;
    onChatMessageReceived  = null;
    onChatMessageSent      = null;
    onChatTyping           = null;
    onChatMessageDeleted   = null;
    onChatBlocked          = null;
    onFriendshipAccepted   = null;
    onWebRtcOffer          = null;
    onWebRtcAnswer         = null;
    onWebRtcIceCandidate   = null;
    onWebRtcMicStatus      = null;
  }

  void clearCallbacks() => _clearCallbacks();
}
