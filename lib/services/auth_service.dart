import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';

class AuthService {
  final _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  // ─── تسجيل حساب جديد ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final res = await _dio.post(ApiConfig.register, data: {
      'name':     name,
      'email':    email,
      'password': password,
    });
    return {
      'user':  UserModel.fromJson(res.data['user']),
      'token': res.data['token'] as String,
    };
  }

  // ─── تسجيل دخول ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post(ApiConfig.login, data: {
      'email':    email,
      'password': password,
    });
    return {
      'user':  UserModel.fromJson(res.data['user']),
      'token': res.data['token'] as String,
    };
  }
}
