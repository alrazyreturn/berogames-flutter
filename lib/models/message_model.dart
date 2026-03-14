class MessageModel {
  final int    id;
  final int    senderId;
  final int    receiverId;
  final String message;
  final bool   isRead;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> j) => MessageModel(
    id:         j['id'],
    senderId:   j['sender_id'],
    receiverId: j['receiver_id'],
    message:    j['message'],
    isRead:     (j['is_read'] as int? ?? 0) == 1,
    createdAt:  DateTime.parse(j['created_at']).toLocal(),
  );
}
