import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  String?    _token;

  UserModel? get user     => _user;
  String?    get token    => _token;
  bool       get isLoggedIn => _token != null && _user != null;

  // ─── تحميل البيانات  من الذاكرة عند بدء التطبيق ───────────────────────────
  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenStr = prefs.getString('token');
    final userStr  = prefs.getString('user');
    if (tokenStr != null && userStr != null) {
      _token = tokenStr;
      _user  = UserModel.fromJson(jsonDecode(userStr));
      notifyListeners();
    }
  }

  // ─── حفظ المستخدم بعد Login / Register ───────────────────────────────────
  Future<void> setUser(UserModel user, String token) async {
    _user  = user;
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('user',  jsonEncode(user.toJson()));
    notifyListeners();
  }

  // ─── تحديث النقاط بعد انتهاء اللعبة ──────────────────────────────────────
  Future<void> updateTotalScore(int newTotalScore) async {
    if (_user == null) return;
    _user = _user!.copyWith(totalScore: newTotalScore);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  // ─── تحديث الاسم والصورة بعد تعديل البروفايل ──────────────────────────────
  Future<void> updateProfile({String? name, String? avatar}) async {
    if (_user == null) return;
    _user = _user!.copyWith(name: name, avatar: avatar);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  // ─── تسجيل الخروج ────────────────────────────────────────────────────────
  Future<void> logout() async {
    _user  = null;
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
