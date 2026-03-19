import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

// ─── Background message handler (يجب أن يكون Top-level function) ─────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // لا نحتاج Firebase.initializeApp هنا لأن main.dart يعمله
  debugPrint('📲 Background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _messaging     = FirebaseMessaging.instance;
  final _localNotif    = FlutterLocalNotificationsPlugin();

  // callback عند الضغط على الإشعار
  Function(Map<String, dynamic>)? onNotificationTap;

  // ─── تهيئة الخدمة ──────────────────────────────────────────────────────────
  Future<void> init() async {
    // 1) طلب الإذن
    await _requestPermission();

    // 2) إعداد Local Notifications (للـ Foreground)
    await _setupLocalNotifications();

    // 3── Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4) استقبال الإشعارات وهو التطبيق مفتوح (Foreground)
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 5) فتح التطبيق من إشعار وهو في الـ Background
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpened);

    // 6) فتح التطبيق من إشعار وهو مغلق تماماً (Terminated)
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _onNotificationOpened(initial);
  }

  // ─── طلب الإذن ─────────────────────────────────────────────────────────────
  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert:       true,
      badge:       true,
      sound:       true,
      provisional: false,
    );
  }

  // ─── إعداد Local Notifications ─────────────────────────────────────────────
  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings     = DarwinInitializationSettings();
    const initSettings    = InitializationSettings(
      android: androidSettings,
      iOS:     iosSettings,
    );

    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          _handlePayload(details.payload!);
        }
      },
    );

    // إنشاء Channel للـ Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'berogames_channel',
        'BeroGames Notifications',
        description: 'إشعارات الألعاب والأصدقاء والمحادثات',
        importance:  Importance.high,
        playSound:   true,
      );
      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  // ─── استقبال إشعار وهو مفتوح (Foreground) ──────────────────────────────────
  void _onForegroundMessage(RemoteMessage message) {
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
          importance:         Importance.high,
          priority:           Priority.high,
          icon:               '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: _encodePayload(message.data),
    );
  }

  // ─── عند الضغط على إشعار ───────────────────────────────────────────────────
  void _onNotificationOpened(RemoteMessage message) {
    if (message.data.isNotEmpty) {
      onNotificationTap?.call(message.data);
    }
  }

  void _handlePayload(String payload) {
    try {
      final parts = payload.split('|');
      final data  = <String, dynamic>{};
      for (final p in parts) {
        final kv = p.split('=');
        if (kv.length == 2) data[kv[0]] = kv[1];
      }
      onNotificationTap?.call(data);
    } catch (_) {}
  }

  String _encodePayload(Map<String, dynamic> data) =>
      data.entries.map((e) => '${e.key}=${e.value}').join('|');

  // ─── إشعار شات محلي عند الـ Foreground (شاشة الشات مغلقة) ─────────────────
  Future<void> showChatLocalNotification({
    required String senderName,
    required String message,
    required String senderId,
  }) async {
    final preview = message.length > 60 ? '${message.substring(0, 60)}...' : message;
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
          priority:   Priority.high,
          icon:       '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: 'type=chat|from_user_id=$senderId|from_name=$senderName',
    );
  }

  // ─── الحصول على FCM Token ───────────────────────────────────────────────────
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  // ─── مراقبة تجديد الـ Token ─────────────────────────────────────────────────
  void onTokenRefresh(Function(String) callback) {
    _messaging.onTokenRefresh.listen(callback);
  }
}
