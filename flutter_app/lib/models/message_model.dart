class MessageModel {
  final String id;
  final String matchId;
  final String senderId;
  final String content;
  final DateTime sentAt;
  bool isRead;

  MessageModel({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.content,
    required this.sentAt,
    this.isRead = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json['id'] ?? '',
        matchId: json['match_id'] ?? '',
        senderId: json['sender_id'] ?? '',
        content: json['content'] ?? '',
        sentAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : json['sent_at'] != null
                ? DateTime.parse(json['sent_at'])
                : DateTime.now(),
        isRead: json['is_read'] ?? false,
      );
}
