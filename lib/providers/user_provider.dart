import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/subscription_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel?          _user;
  String?             _token;
  SubscriptionStatus? _subscriptionStatus;

  UserModel?          get user               => _user;
  String?             get token              => _token;
  bool                get isLoggedIn         => _token != null && _user != null;
  SubscriptionStatus? get subscriptionStatus => _subscriptionStatus;

  // Shortcuts
  bool get hasUnlimitedEnergy => _subscriptionStatus?.unlimitedEnergy == true;
  bool get canPlayPremium     => _subscriptionStatus?.canPlayPremium == true;
  bool get hasNoAds           => _subscriptionStatus?.noAds == true;

  // ─── تحميل البيانات من الذاكرة عند بدء التطبيق ────────────────────────────
  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenStr = prefs.getString('token');
    final userStr  = prefs.getString('user');
    if (tokenStr != null && userStr != null) {
      _token = tokenStr;
      _user  = UserModel.fromJson(jsonDecode(userStr));
      notifyListeners();
      // جلب حالة الاشتراك في الخلفية
      await refreshSubscription();
    }
  }

  // ─── حفظ المستخدم بعد Login / Register ──────────────────────────────────
  Future<void> setUser(UserModel user, String token) async {
    _user  = user;
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('user',  jsonEncode(user.toJson()));
    notifyListeners();
    await refreshSubscription();
  }

  // ─── تحديث حالة الاشتراك من السيرفر ─────────────────────────────────────
  Future<void> refreshSubscription() async {
    if (_token == null) return;
    try {
      _subscriptionStatus = await SubscriptionService().getStatus(_token!);
      notifyListeners();
    } catch (_) {}
  }

  // ─── تحديث النقاط بعد انتهاء اللعبة ────────────────────────────────────
  Future<void> updateTotalScore(int newTotalScore) async {
    if (_user == null) return;
    _user = _user!.copyWith(totalScore: newTotalScore);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  // ─── تحديث الاسم والصورة بعد تعديل البروفايل ────────────────────────────
  Future<void> updateProfile({String? name, String? avatar}) async {
    if (_user == null) return;
    _user = _user!.copyWith(name: name, avatar: avatar);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  // ─── تسجيل الخروج ───────────────────────────────────────────────────────
  Future<void> logout() async {
    _user               = null;
    _token              = null;
    _subscriptionStatus = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
