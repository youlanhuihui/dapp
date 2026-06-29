class User {
  final String userId;
  final String email;
  final String? phone;
  final String? nickname;
  final String? avatarUrl;
  final bool nodeVip;
  final DateTime? createdAt;

  const User({
    required this.userId,
    required this.email,
    this.phone,
    this.nickname,
    this.avatarUrl,
    this.nodeVip = false,
    this.createdAt,
  });

  factory User.fromMe(Map<String, dynamic> json) => User(
        userId: (json['id'] ?? json['user_id']) as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        nickname: json['nickname'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        nodeVip: json['node_vip'] as bool? ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
      );

  String get displayName => (nickname != null && nickname!.isNotEmpty)
      ? nickname!
      : email.split('@').first;
}
