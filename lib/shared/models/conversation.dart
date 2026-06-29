/// 会话数据模型
class ConversationModel {
  final String id;
  final String type;
  final String? title;
  final String createdBy;
  final DateTime createdAt;
  // 扩展字段（列表接口常带）
  final String? peerUserId;
  final String? peerNickname;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ConversationModel({
    required this.id,
    required this.type,
    this.title,
    required this.createdBy,
    required this.createdAt,
    this.peerUserId,
    this.peerNickname,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      peerUserId: json['peer_user_id'] as String?,
      peerNickname: json['peer_nickname'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isGroup =>
      type == 'group' || type == 'system_group' || type == 'system_private';

  /// 显示名：title 优先，否则 peer_nickname，否则 id 后 8 位
  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    if (peerNickname != null && peerNickname!.isNotEmpty) return peerNickname!;
    return 'Conv ${id.substring(id.length - 8)}';
  }
}
