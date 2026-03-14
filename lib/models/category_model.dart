import 'package:flutter/material.dart';

class CategoryModel {
  final int    id;
  final String name;
  final String nameAr;
  final String icon;
  final String colorHex;

  CategoryModel({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.icon,
    required this.colorHex,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> j) => CategoryModel(
    id:       j['id'],
    name:     j['name'],
    nameAr:   j['name_ar'],
    icon:     j['icon']  ?? '📚',
    colorHex: j['color'] ?? '#2196F3',
  );

  // تحويل HEX → Color
  Color get color {
    final hex = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
