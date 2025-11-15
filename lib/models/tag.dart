import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

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
}
