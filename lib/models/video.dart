import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

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

  // 是否需要转码

  @HiveField(9)
  String? transcode;

  Video({
    required this.title,
    required this.filePath,
    required this.fileSize,
    List<String>? tagIds,
    String? remark,
    String? transcode,
    DateTime? uploadTime,
    this.duration,
    this.thumbnailPath,
    String? id,
  })  : id = id ?? const Uuid().v4(),
        tagIds = tagIds ?? [],
        remark = remark ?? '',
        transcode = transcode ?? 'notCompleted',
        uploadTime = uploadTime ?? DateTime.now();

  // 序列化方法
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'filePath': filePath,
      'fileSize': fileSize,
      'tagIds': tagIds,
      'remark': remark,
      'uploadTime': uploadTime.toIso8601String(),
      'duration': duration,
      'thumbnailPath': thumbnailPath,
      'transcode': transcode,
    };
  }

  // 反序列化方法
  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String,
      filePath: json['filePath'] as String,
      fileSize: json['fileSize'] as int,
      tagIds: (json['tagIds'] as List?)?.cast<String>() ?? [],
      remark: json['remark'] as String? ?? '',
      uploadTime: DateTime.parse(json['uploadTime'] as String),
      duration: json['duration'] as int?,
      thumbnailPath: json['thumbnailPath'] as String?,
      transcode: json['transcode'] as String? ?? 'notCompleted',
    );
  }

  // 从JSON字符串创建Video实例
  factory Video.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return Video.fromJson(json);
  }

  // 将Video实例转换为JSON字符串
  String toJsonString() {
    return jsonEncode(toJson());
  }
}
//  notcompleted 未转码
//  completed  已转码
//  notneed 不需要
