import 'package:dio/dio.dart';
import '../config/api_config.dart';

class EnergyService {
  final _dio = Dio();

  // ─── جلب الطاقة الحالية ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> getEnergy(String token) async {
    final res = await _dio.get(
      '${ApiConfig.baseUrl}${ApiConfig.energy}',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(res.data);
  }

  // ─── استهلاك طاقة واحدة قبل اللعبة ──────────────────────────────────────
  Future<Map<String, dynamic>> consumeEnergy(String token) async {
    final res = await _dio.post(
      '${ApiConfig.baseUrl}${ApiConfig.energyConsume}',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(res.data);
  }

  // ─── شحن طاقة بعد مشاهدة إعلان ──────────────────────────────────────────
  Future<Map<String, dynamic>> rechargeEnergy(String token) async {
    final res = await _dio.post(
      '${ApiConfig.baseUrl}${ApiConfig.energyRecharge}',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(res.data);
  }
}
