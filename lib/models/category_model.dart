import 'package:flutter/material.dart';

class CategoryModel {
  final int    id;
  final String nameAr;
  final String nameEn;
  final String nameTr;
  final String icon;
  final String colorHex;
  final bool   isPremium;

  CategoryModel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.nameTr,
    required this.icon,
    required this.colorHex,
    this.isPremium = false,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> j) => CategoryModel(
    id:        j['id'],
    nameAr:    j['name_ar'] ?? j['name'] ?? '',
    nameEn:    j['name_en'] ?? j['name_ar'] ?? j['name'] ?? '',
    nameTr:    j['name_tr'] ?? j['name_ar'] ?? j['name'] ?? '',
    icon:      j['icon']    ?? '📚',
    colorHex:  j['color']   ?? '#2196F3',
    isPremium: (j['is_premium'] == 1 || j['is_premium'] == true),
  );

  /// إرجاع الاسم بناءً على كود اللغة (ar / en / tr)
  String localizedName(String lang) {
    switch (lang) {
      case 'en': return nameEn.isNotEmpty ? nameEn : nameAr;
      case 'tr': return nameTr.isNotEmpty ? nameTr : nameAr;
      default:   return nameAr;
    }
  }

  // تحويل HEX → Color
  Color get color {
    final hex = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
