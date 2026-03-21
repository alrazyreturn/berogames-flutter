class FriendModel {
  final int     friendshipId;
  final int     userId;
  final String  name;
  final int     totalScore;
  final String? avatar;
  bool          isOnline;

  FriendModel({
    required this.friendshipId,
    required this.userId,
    required this.name,
    this.totalScore = 0,
    this.avatar,
    this.isOnline   = false,
  });

  factory FriendModel.fromJson(Map<String, dynamic> j) => FriendModel(
    friendshipId: j['friendship_id'],
    userId:       j['user_id'],
    name:         j['name']        ?? '؟',
    totalScore:   j['total_score'] ?? 0,
    avatar:       j['avatar']      as String?,
  );
}

class FriendRequestModel {
  final int     friendshipId;
  final int     userId;
  final String  name;
  final int     totalScore;
  final String? avatar;

  FriendRequestModel({
    required this.friendshipId,
    required this.userId,
    required this.name,
    this.totalScore = 0,
    this.avatar,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> j) => FriendRequestModel(
    friendshipId: j['friendship_id'],
    userId:       j['user_id'],
    name:         j['name']        ?? '؟',
    totalScore:   j['total_score'] ?? 0,
    avatar:       j['avatar']      as String?,
  );
}
