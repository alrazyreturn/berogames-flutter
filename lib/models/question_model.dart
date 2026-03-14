class QuestionModel {
  final int    id;
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption; // 'a' | 'b' | 'c' | 'd'
  final int    difficulty;    // 1 → 10

  QuestionModel({
    required this.id,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    required this.difficulty,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> j) => QuestionModel(
    id:            j['id'],
    questionText:  j['question_text'],
    optionA:       j['option_a'],
    optionB:       j['option_b'],
    optionC:       j['option_c'],
    optionD:       j['option_d'],
    correctOption: j['correct_option'],
    difficulty:    j['difficulty'] ?? 1,
  );

  // قائمة الخيارات مرتبة
  List<Map<String, String>> get options => [
    {'key': 'a', 'text': optionA},
    {'key': 'b', 'text': optionB},
    {'key': 'c', 'text': optionC},
    {'key': 'd', 'text': optionD},
  ];

  // index الإجابة الصحيحة (0→a, 1→b, 2→c, 3→d)
  int get correctIndex => ['a', 'b', 'c', 'd'].indexOf(correctOption);

  // النقاط بتزيد مع الصعوبة
  int get points => difficulty * 10;
}
