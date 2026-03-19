import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/message_model.dart';

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
}
