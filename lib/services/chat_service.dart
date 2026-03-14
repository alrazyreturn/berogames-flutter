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

  // ─── عدد الرسائل غير المقروءة ────────────────────────────────────────────
  Future<int> getUnreadCount({required String token}) async {
    final res = await _dio.get(
      ApiConfig.chatUnread,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return (res.data['count'] as num?)?.toInt() ?? 0;
  }
}
