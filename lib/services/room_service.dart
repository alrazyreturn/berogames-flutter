import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/room_model.dart';

class RoomService {
  final _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  // ─── إنشاء غرفة جديدة ────────────────────────────────────────────────────
  Future<RoomModel> createRoom({
    required int    categoryId,
    required String token,
  }) async {
    final res = await _dio.post(
      ApiConfig.roomCreate,
      data: {'category_id': categoryId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return RoomModel.fromJson(res.data);
  }

  // ─── الانضمام لغرفة موجودة ───────────────────────────────────────────────
  Future<RoomModel> joinRoom({
    required String roomCode,
    required String token,
  }) async {
    final res = await _dio.post(
      ApiConfig.roomJoin,
      data: {'room_code': roomCode},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return RoomModel.fromJson(res.data);
  }

  // ─── حفظ النتيجة النهائية ─────────────────────────────────────────────────
  Future<int> finishRoom({
    required int    roomId,
    required int    score,
    required String token,
  }) async {
    final res = await _dio.post(
      ApiConfig.roomFinish,
      data: {'room_id': roomId, 'score': score},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return (res.data['total_score'] as num).toInt();
  }
}
