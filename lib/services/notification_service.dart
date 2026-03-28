import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── SharedPreferences key لحفظ دعوة قبول معلقة ──────────────────────────────
const _kPendingInvite = 'pending_invite_accept';

// ─── معالج أزرار إجراءات الإشعارات في الخلفية (top-level, isolate منفصل) ──────
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse details) async {
  // Accept → احفظ بيانات الدعوة في SharedPreferences، سيعالجها HomeScreen عند الفتح
  if (details.actionId == 'accept_invite' && details.payload != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingInvite, details.payload!);
  }
  // reject_invite → لا إجراء، الإشعار أُلغي تلقائياً (cancelNotification: true)
}

// ─── معالج رسائل FCM في الخلفية / التطبيق مغلق (top-level) ──────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final type = message.data['type'] ?? '';
  if (type == 'game_invite') {
    // رسالة بيانات فقط (بدون notification field) → أظهر إشعاراً محلياً بأزرار
    await _showGameInviteNotification(message.data);
  }
  debugPrint('📲 Background FCM: type=$type');
}

// ─── عرض إشعار دعوة اللعب مع أزرار القبول والرفض ───────────────────────────
Future<void> _showGameInviteNotification(Map<String, dynamic> data) async {
  final plugin = FlutterLocalNotificationsPlugin();

  // تهيئة بسيطة مع تسجيل معالج أزرار الخلفية
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(
    const InitializationSettings(
      android: androidInit,
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  // إنشاء قناة دعوات اللعب (مطلوب لـ Android 8+)
  if (Platform.isAndroid) {
    const inviteChannel = AndroidNotificationChannel(
      'game_invite_channel',
      'دعوات اللعب',
      description: 'إشعارات دعوة الأصدقاء للعب',
      importance: Importance.max,
      playSound: true,
    );
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(inviteChannel);
  }

  final fromName   = data['from_name']     ?? 'صديق';
  final roomCode   = data['room_code']     ?? '';
  final fromUserId = data['from_user_id']  ?? '';
  final catName    = data['category_name'] ?? '';
  final payload    =
      'type=game_invite|room_code=$roomCode|from_user_id=$fromUserId|from_name=$fromName';

  await plugin.show(
    roomCode.hashCode,
    '🎮 دعوة للعب!',
    catName.isNotEmpty
        ? '$fromName يدعوك للعب في $catName'
        : '$fromName يدعوك للمباراة ⚔️',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'game_invite_channel',
        'دعوات اللعب',
        channelDescription: 'إشعارات دعوة الأصدقاء للعب',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        // ─── أزرار القبول والرفض ───────────────────────
        actions: [
          AndroidNotificationAction(
            'accept_invite',
            '✅ قبول',
            cancelNotification: true,  // يُغلق الإشعار عند الضغط
            showsUserInterface: true,  // يفتح التطبيق
          ),
          AndroidNotificationAction(
            'reject_invite',
            '❌ رفض',
            cancelNotification: true,
            showsUserInterface: false, // لا يفتح التطبيق
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(),
    ),
    payload: payload,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _messaging  = FirebaseMessaging.instance;
  final _localNotif = FlutterLocalNotificationsPlugin();

  /// callback عند الضغط على إشعار أو زر قبول (يُستدعى من main.dart)
  Function(Map<String, dynamic>)? onNotificationTap;

  /// بيانات إشعار فتح التطبيق من حالة مغلقة تماماً (Terminated)
  /// يُعالجها HomeScreen بعد التهيئة
  String? _pendingLaunchPayload;

  // ─── تهيئة الخدمة ──────────────────────────────────────────────────────────
  Future<void> init() async {
    await _requestPermission();
    await _setupLocalNotifications();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onFcmNotificationOpened);

    // فتح التطبيق من إشعار FCM وهو مغلق (للأنواع الأخرى كالمحادثات)
    final initial = await _messaging.getInitialMessage();
    if (initial != null && initial.data.isNotEmpty) {
      onNotificationTap?.call(initial.data);
    }
  }

  // ─── طلب الأذونات ──────────────────────────────────────────────────────────
  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );
  }

  // ─── إعداد Local Notifications ─────────────────────────────────────────────
  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings     = DarwinInitializationSettings();
    const initSettings    = InitializationSettings(
      android: androidSettings, iOS: iosSettings,
    );

    await _localNotif.initialize(
      initSettings,
      // تُستدعى عند الضغط على إشعار أو زر عمل وهو التطبيق في المقدمة،
      // وكذلك عند فتح التطبيق من حالة مغلقة بسبب إشعار محلي
      onDidReceiveNotificationResponse: (details) {
        // زر الرفض → لا إجراء
        if (details.actionId == 'reject_invite') return;
        // زر القبول أو ضغط على الإشعار → فتح الغرفة
        if (details.payload != null) {
          _handlePayload(details.payload!);
        }
      },
      // تُستدعى من isolate منفصل عند الضغط على زر عمل وهو التطبيق في الخلفية
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // تحقق من وجود إشعار محلي فتح التطبيق من حالة مغلقة
    final launchDetails = await _localNotif.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final response = launchDetails!.notificationResponse;
      if (response != null &&
          response.actionId != 'reject_invite' &&
          response.payload != null) {
        _pendingLaunchPayload = response.payload;
      }
    }

    if (Platform.isAndroid) {
      final androidPlugin = _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // القناة الرئيسية (محادثات + إشعارات أخرى)
      const mainChannel = AndroidNotificationChannel(
        'berogames_channel',
        'BeroGames Notifications',
        description: 'إشعارات الألعاب والأصدقاء والمحادثات',
        importance: Importance.high,
        playSound: true,
      );
      // قناة دعوات اللعب (مع أزرار)
      const inviteChannel = AndroidNotificationChannel(
        'game_invite_channel',
        'دعوات اللعب',
        description: 'إشعارات دعوة الأصدقاء للعب',
        importance: Importance.max,
        playSound: true,
      );

      await androidPlugin?.createNotificationChannel(mainChannel);
      await androidPlugin?.createNotificationChannel(inviteChannel);
    }
  }

  // ─── معالج الرسائل وهو التطبيق مفتوح (Foreground) ──────────────────────────
  void _onForegroundMessage(RemoteMessage message) {
    final type = message.data['type'] ?? '';

    // دعوات اللعب → يتولاها Socket عبر حوار في الشاشة الرئيسية
    if (type == 'game_invite') return;

    final notif = message.notification;
    if (notif == null) return;

    _localNotif.show(
      message.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'berogames_channel',
          'BeroGames Notifications',
          channelDescription: 'إشعارات BeroGames',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: _encodePayload(message.data),
    );
  }

  // ─── فتح التطبيق بعد الضغط على إشعار FCM (background → foreground) ─────────
  void _onFcmNotificationOpened(RemoteMessage message) {
    if (message.data.isNotEmpty) {
      onNotificationTap?.call(message.data);
    }
  }

  // ─── تحليل الـ Payload وإطلاق الـ Callback ──────────────────────────────────
  void _handlePayload(String payload) {
    try {
      final data = <String, dynamic>{};
      for (final p in payload.split('|')) {
        final kv = p.split('=');
        if (kv.length == 2) data[kv[0]] = kv[1];
      }
      onNotificationTap?.call(data);
    } catch (_) {}
  }

  /// يُعالج الإشعار الذي فتح التطبيق من حالة مغلقة تماماً.
  /// يجب أن يستدعيه HomeScreen في initState بعد تسجيل onNotificationTap.
  void processLaunchNotification() {
    if (_pendingLaunchPayload != null) {
      final payload = _pendingLaunchPayload!;
      _pendingLaunchPayload = null;
      _handlePayload(payload);
    }
  }

  // ─── التحقق من دعوة قبول معلقة (من زر Accept في الخلفية) ───────────────────
  /// يُستدعى من HomeScreen في initState وعند عودة التطبيق للمقدمة.
  /// إذا وجد دعوة مقبولة → يستدعي [onAccept] بالبيانات.
  Future<void> checkPendingInvite(
      Function(Map<String, String> data) onAccept) async {
    final prefs   = await SharedPreferences.getInstance();
    final pending = prefs.getString(_kPendingInvite);
    if (pending == null) return;
    await prefs.remove(_kPendingInvite);
    final data = <String, String>{};
    for (final part in pending.split('|')) {
      final kv = part.split('=');
      if (kv.length == 2) data[kv[0]] = kv[1];
    }
    onAccept(data);
  }

  // ─── إشعار شات محلي ─────────────────────────────────────────────────────────
  Future<void> showChatLocalNotification({
    required String senderName,
    required String message,
    required String senderId,
  }) async {
    final preview =
        message.length > 60 ? '${message.substring(0, 60)}...' : message;
    await _localNotif.show(
      senderId.hashCode,
      '💬 $senderName',
      preview,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'berogames_channel',
          'BeroGames Notifications',
          channelDescription: 'إشعارات BeroGames',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: 'type=chat|from_user_id=$senderId|from_name=$senderName',
    );
  }

  // ─── FCM Token ───────────────────────────────────────────────────────────────
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  void onTokenRefresh(Function(String) callback) {
    _messaging.onTokenRefresh.listen(callback);
  }

  String _encodePayload(Map<String, dynamic> data) =>
      data.entries.map((e) => '${e.key}=${e.value}').join('|');
}
