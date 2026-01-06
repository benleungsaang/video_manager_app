import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 15)
class User extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String username;

  @HiveField(2)
  String role; // 'user' or 'admin'

  @HiveField(3)
  String? totpSecret; // 生效的TOTP密钥

  @HiveField(4)
  String? pendingSecret; // 待处理的TOTP密钥

  @HiveField(5)
  String status; // 'pending_activation', 'pending_approval', 'pending_reset', 'active', 'disabled'

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime? lastLoginAt;

  @HiveField(8)
  List<String> sessions; // 会话ID列表

  User({
    required this.id,
    required this.username,
    required this.role,
    this.totpSecret,
    this.pendingSecret,
    required this.status,
    required this.createdAt,
    this.lastLoginAt,
    this.sessions = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'totpSecret': totpSecret,
      'pendingSecret': pendingSecret,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'sessions': sessions,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      role: json['role'] ?? 'user',
      totpSecret: json['totpSecret'],
      pendingSecret: json['pendingSecret'],
      status: json['status'] ?? 'pending_activation',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      lastLoginAt: json['lastLoginAt'] != null 
          ? DateTime.parse(json['lastLoginAt']) 
          : null,
      sessions: List<String>.from(json['sessions'] ?? []),
    );
  }
}