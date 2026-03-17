import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/category_model.dart';
import '../models/question_model.dart';

class GameService {
  final _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  // ─── جيب كل الأقسام ──────────────────────────────────────────────────────
  Future<List<CategoryModel>> getCategories({String lang = 'ar'}) async {
    final res = await _dio.get(ApiConfig.categories, queryParameters: {'lang': lang});
    return (res.data as List)
        .map((e) => CategoryModel.fromJson(e))
        .toList();
  }

  // ─── جيب أسئلة بناءً على القسم والصعوبة واللغة ───────────────────────────
  Future<List<QuestionModel>> getQuestions({
    required int    categoryId,
    required int    difficulty,
    int             limit = 3,
    String          lang  = 'ar',
  }) async {
    final res = await _dio.get(ApiConfig.questions, queryParameters: {
      'category_id': categoryId,
      'difficulty':  difficulty,
      'limit':       limit,
      'lang':        lang,
    });
    return (res.data as List)
        .map((e) => QuestionModel.fromJson(e))
        .toList();
  }

  // ─── جيب مستوى اليوزر في قسم معين ──────────────────────────────────────
  Future<int> getUserLevel({
    required int    categoryId,
    required String token,
  }) async {
    final res = await _dio.get(
      ApiConfig.userLevel,
      queryParameters: {'category_id': categoryId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return (res.data['difficulty'] as num).toInt();
  }

  // ─── حفظ النتيجة بعد انتهاء اللعبة ──────────────────────────────────────
  Future<int> submitScore({
    required int    categoryId,
    required int    score,
    required int    difficultyReached,
    required String token,
    int correctAnswers = 0,
    int wrongAnswers   = 0,
  }) async {
    final res = await _dio.post(
      ApiConfig.score,
      data: {
        'category_id':       categoryId,
        'score':             score,
        'difficulty_reached': difficultyReached,
        'correct_answers':   correctAnswers,
        'wrong_answers':     wrongAnswers,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return (res.data['total_score'] as num).toInt();
  }

  // ─── مضاعفة النقاط بعد مشاهدة Rewarded Ad ────────────────────────────────
  Future<int> addBonusScore({
    required int    bonusScore,
    required String token,
  }) async {
    final res = await _dio.post(
      ApiConfig.gameBonus,
      data: {'bonus_score': bonusScore},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return (res.data['total_score'] as num).toInt();
  }

  // ─── جيب إحصائيات اليوزر ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> getStats({required String token}) async {
    final res = await _dio.get(
      ApiConfig.stats,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return res.data as Map<String, dynamic>;
  }
}
