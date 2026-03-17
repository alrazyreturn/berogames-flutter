class ApiConfig {
  static const String baseUrl   ='https://api.berogames.store/api';// 'http://38.180.146.158:3000/api';
  static const String socketUrl = 'https://api.berogames.store';  //'http://38.180.146.158:3000'; // WebSocket

  // Auth
  static const String register    = '/auth/register';
  static const String login       = '/auth/login';
  static const String googleLogin = '/auth/google';
  static const String profile     = '/auth/profile';

  // Game
  static const String categories  = '/game/categories';
  static const String questions   = '/game/questions';
  static const String score       = '/game/score';
  static const String userLevel   = '/game/user-level';
  static const String leaderboard = '/game/leaderboard';
  static const String myRank      = '/game/my-rank';
  static const String stats       = '/game/stats';
  static const String gameBonus   = '/game/bonus';

  // Room (Multiplayer)
  static const String roomCreate = '/room/create';
  static const String roomJoin   = '/room/join';
  static const String roomFinish = '/room/finish';

  // Chat
  static const String chat         = '/chat';
  static const String chatUnread   = '/chat/unread/count';
  static const String chatMessages = '/chat/messages';

  // Friends
  static const String friendsList     = '/friends';
  static const String friendsRequests = '/friends/requests';
  static const String friendsRequest  = '/friends/request';
  static const String friendsAccept   = '/friends/accept';

  // Energy
  static const String energy         = '/energy';
  static const String energyConsume  = '/energy/consume';
  static const String energyRecharge = '/energy/recharge';
}
