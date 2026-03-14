class UserModel {
  final int    id;
  final String name;
  final String email;
  final String? avatar;
  final int    totalScore;
  final int    currentLevel;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.totalScore   = 0,
    this.currentLevel = 1,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id:           j['id'],
    name:         j['name'],
    email:        j['email'],
    avatar:       j['avatar'],
    totalScore:   j['total_score']   ?? 0,
    currentLevel: j['current_level'] ?? 1,
  );

  Map<String, dynamic> toJson() => {
    'id':            id,
    'name':          name,
    'email':         email,
    'avatar':        avatar,
    'total_score':   totalScore,
    'current_level': currentLevel,
  };

  // نسخة محدّثة
  UserModel copyWith({
    String? name,
    String? avatar,
    int?    totalScore,
    int?    currentLevel,
    bool    clearAvatar = false,
  }) => UserModel(
    id:           id,
    name:         name         ?? this.name,
    email:        email,
    avatar:       clearAvatar  ? null : (avatar ?? this.avatar),
    totalScore:   totalScore   ?? this.totalScore,
    currentLevel: currentLevel ?? this.currentLevel,
  );
}
