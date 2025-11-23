import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'video.g.dart';

@HiveType(typeId: 0)
class Video extends HiveObject {
  // 唯一标识
  @HiveField(0)
  final String id;

  // 视频标题
  @HiveField(1)
  String title;

  // 视频本地路径
  @HiveField(2)
  final String filePath;

  // 文件大小(字节)
  @HiveField(3)
  final int fileSize;

  // 关联的标签ID列表
  @HiveField(4)
  List<String> tagIds;

  // 视频备注
  @HiveField(5)
  String remark;

  // 上传时间
  @HiveField(6)
  final DateTime uploadTime;

  // 视频时长(秒)
  @HiveField(7)
  int? duration;

  // 缩略图路径
  @HiveField(8)
  String? thumbnailPath;

  Video({
    required this.title,
    required this.filePath,
    required this.fileSize,
    List<String>? tagIds,
    String? remark,
    DateTime? uploadTime,
    this.duration,
    this.thumbnailPath,
    String? id,
  })  : id = id ?? const Uuid().v4(),
        tagIds = tagIds ?? [],
        remark = remark ?? '',
        uploadTime = uploadTime ?? DateTime.now();
}
