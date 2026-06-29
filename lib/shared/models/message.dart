/// 消息数据模型
class MessageModel {
  final String id;
  final String conversationId;
  final String senderType; // user / system
  final String senderId;
  final String? senderName;
  final String messageType; // text / transfer_card / red_packet / ecosystem_card ...
  final Map<String, dynamic> contentJson;
  final String? replyToMessageId;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderType,
    required this.senderId,
    this.senderName,
    required this.messageType,
    required this.contentJson,
    this.replyToMessageId,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderType: json['sender_type'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String?,
      messageType: json['message_type'] as String,
      contentJson: (json['content_json'] as Map<String, dynamic>?) ?? {},
      replyToMessageId: json['reply_to_message_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get textContent => contentJson['text'] as String? ?? '';

  bool isSentBy(String userId) => senderId == userId;

  bool get isSystem => senderType == 'system';
}
