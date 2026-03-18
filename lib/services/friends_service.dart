import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/friend_model.dart';

class FriendsService {
  final _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  // ─── قائمة الأصدقاء ───────────────────────────────────────────────────────
  Future<List<FriendModel>> getFriends(String token) async {
    final res = await _dio.get(ApiConfig.friendsList, options: _auth(token));
    return (res.data as List).map((e) => FriendModel.fromJson(e)).toList();
  }

  // ─── طلبات الصداقة الواردة ────────────────────────────────────────────────
  Future<List<FriendRequestModel>> getRequests(String token) async {
    final res = await _dio.get(ApiConfig.friendsRequests, options: _auth(token));
    return (res.data as List).map((e) => FriendRequestModel.fromJson(e)).toList();
  }

  // ─── إرسال طلب صداقة ─────────────────────────────────────────────────────
  Future<String> sendRequest(String email, String token) async {
    final res = await _dio.post(
      ApiConfig.friendsRequest,
      data:    {'email': email},
      options: _auth(token),
    );
    return res.data['message'] as String;
  }

  // ─── متابعة لاعب بـ userId (من شاشة اللعب) ───────────────────────────────
  Future<Map<String, dynamic>> followByUserId(int targetId, String token) async {
    final res = await _dio.post(
      ApiConfig.friendsRequestById,
      data:    {'targetId': targetId},
      options: _auth(token),
    );
    return Map<String, dynamic>.from(res.data);
  }

  // ─── حالة العلاقة مع مستخدم محدد ────────────────────────────────────────
  Future<String> getFollowStatus(int targetId, String token) async {
    final res = await _dio.get(
      '${ApiConfig.friendsStatus}/$targetId',
      options: _auth(token),
    );
    return (res.data['status'] as String?) ?? 'none';
  }

  // ─── قبول طلب صداقة ──────────────────────────────────────────────────────
  Future<void> acceptRequest(int friendshipId, String token) async {
    await _dio.put(
      '${ApiConfig.friendsAccept}/$friendshipId',
      options: _auth(token),
    );
  }

  // ─── رفض / حذف صديق ──────────────────────────────────────────────────────
  Future<void> deleteFriend(int friendshipId, String token) async {
    await _dio.delete(
      '${ApiConfig.friendsList}/$friendshipId',
      options: _auth(token),
    );
  }
}
