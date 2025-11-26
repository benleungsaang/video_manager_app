import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

part 'tag.g.dart';

@HiveType(typeId: 1)
class Tag extends HiveObject {
  // 唯一标识
  @HiveField(0)
  final String id;

  // 标签名称
  @HiveField(1)
  String name;

  // 关联的视频数量(用于显示，实际数量从视频表计算)
  @HiveField(2)
  int videoCount;

  Tag({
    required this.name,
    this.videoCount = 0,
    String? id,
  }) : id = id ?? const Uuid().v4();

  // 序列化方法
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'videoCount': videoCount,
    };
  }

  // 反序列化方法
  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String,
      videoCount: json['videoCount'] as int? ?? 0,
    );
  }

  // 从JSON字符串创建Tag实例
  factory Tag.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return Tag.fromJson(json);
  }

  // 将Tag实例转换为JSON字符串
  String toJsonString() {
    return jsonEncode(toJson());
  }
}
