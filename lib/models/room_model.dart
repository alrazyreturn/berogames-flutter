class RoomPlayerModel {
  final int     id;
  final String  name;
  final int     totalScore;
  final String? avatar;
  final int     currentLevel;

  RoomPlayerModel({
    required this.id,
    required this.name,
    this.totalScore   = 0,
    this.avatar,
    this.currentLevel = 1,
  });

  factory RoomPlayerModel.fromJson(Map<String, dynamic> j) => RoomPlayerModel(
    id:           j['id'],
    name:         j['name']          ?? '؟',
    totalScore:   j['total_score']   ?? 0,
    avatar:       j['avatar'],
    currentLevel: j['current_level'] ?? 1,
  );
}

class RoomModel {
  final int             roomId;
  final String          roomCode;
  final int             categoryId;
  final RoomPlayerModel host;
  final RoomPlayerModel? guest;
  final String          status;

  RoomModel({
    required this.roomId,
    required this.roomCode,
    required this.categoryId,
    required this.host,
    this.guest,
    this.status = 'waiting',
  });

  factory RoomModel.fromJson(Map<String, dynamic> j) => RoomModel(
    roomId:     j['room_id'],
    roomCode:   j['room_code'],
    categoryId: j['category_id'],
    host:       RoomPlayerModel.fromJson(j['host']),
    guest:      j['guest'] != null
                  ? RoomPlayerModel.fromJson(j['guest'])
                  : null,
    status:     j['status'] ?? 'waiting',
  );
}
