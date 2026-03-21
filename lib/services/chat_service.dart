import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/message_model.dart';

// ─── نموذج المحادثة ───────────────────────────────────────────────────────────
class ConversationModel {
  final int     userId;
  final String  name;
  final String? avatar;
  final String  lastMessage;
  final DateTime lastAt;
  final int     unreadCount;

  ConversationModel({
    required this.userId,
    required this.name,
    this.avatar,
    required this.lastMessage,
    required this.lastAt,
    required this.unreadCount,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> j) => ConversationModel(
    userId:      (j['other_id']     as num).toInt(),
    name:        (j['other_name']   as String?) ?? '؟',
    avatar:      j['other_avatar']  as String?,
    lastMessage: (j['last_message'] as String?) ?? '',
    lastAt:      DateTime.tryParse(j['last_at'] as String? ?? '') ?? DateTime.now(),
    unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
  );
}

class ChatService {
  final _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  // ─── جلب تاريخ المحادثة ──────────────────────────────────────────────────
  Future<List<MessageModel>> getMessages({
    required int    friendId,
    required String token,
  }) async {
    final res = await _dio.get(
      '${ApiConfig.chat}/$friendId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return (res.data as List)
        .map((j) => MessageModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ─── مسح رسالة ───────────────────────────────────────────────────────────
  Future<void> deleteMessage({
    required int    messageId,
    required String token,
  }) async {
    await _dio.delete(
      '${ApiConfig.chatMessages}/$messageId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  // ─── عدد الرسائل غير المقروءة (إجمالي) ──────────────────────────────────
  Future<int> getUnreadCount({required String token}) async {
    final res = await _dio.get(
      ApiConfig.chatUnread,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return (res.data['count'] as num?)?.toInt() ?? 0;
  }

  // ─── عدد غير المقروءة لكل صديق → Map<senderId, count> ────────────────────
  Future<Map<int, int>> getUnreadPerFriend({required String token}) async {
    final res = await _dio.get(
      ApiConfig.chatUnreadPerFriend,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final result = <int, int>{};
    for (final row in (res.data as List)) {
      final id    = (row['sender_id'] as num).toInt();
      final count = (row['count']     as num).toInt();
      result[id]  = count;
    }
    return result;
  }

  // ─── كل المحادثات (بغض النظر عن الصداقة) ─────────────────────────────────
  Future<List<ConversationModel>> getConversations({required String token}) async {
    final res = await _dio.get(
      ApiConfig.chatConversations,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return (res.data as List)
        .map((j) => ConversationModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
