import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';

class AuthService {
  final _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  final _googleSignIn = GoogleSignIn(
    serverClientId: '564493548124-p7q6n790akns34ujvjeklj9n37a3a8t7.apps.googleusercontent.com',
  );

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

  // ─── تسجيل دخول بجوجل ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> loginWithGoogle() async {
    // تسجيل الخروج أولاً لضمان ظهور شاشة الاختيار دائماً
    await _googleSignIn.signOut();

    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('تم إلغاء تسجيل الدخول');

    final auth    = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw Exception('فشل الحصول على token');

    final res = await _dio.post(ApiConfig.googleLogin, data: {'idToken': idToken});
    return {
      'user':  UserModel.fromJson(res.data['user']),
      'token': res.data['token'] as String,
    };
  }
}
