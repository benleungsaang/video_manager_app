import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/video.dart';
import '../providers/video_provider.dart';
import 'file_utils.dart'; // 引入文件工具类
import 'storage_utils.dart'; // 引入存储工具类
import '../../utils/video_player_utils.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoUploader {
  // 本地视频复制处理（复制到APP目录）
  final VideoPlayerUtils _playerUtils = VideoPlayerUtils();
  static Future<Video> copyToAppDirectory(
    File sourceFile,
    String title,
    List<String> tagIds,
    VideoProvider videoProvider,
    int durationTime,
  ) async {
    try {
      // 获取新存储位置的视频目录
      final videosDir = StorageUtils.getVideosDirectory();
      await Directory(videosDir).create(recursive: true);

      // 复制文件到APP目录
      final fileName = p.basename(sourceFile.path);
      final targetPath = p.join(videosDir, fileName);
      final targetFile = await sourceFile.copy(targetPath);

      // 生成视频缩略图
      final thumbnailPath =
          await FileUtils.generateVideoThumbnail(targetFile.path);

      // 创建视频对象
      final video = Video(
        title: title,
        filePath: targetFile.path,
        fileSize: await targetFile.length(),
        tagIds: tagIds,
        thumbnailPath: thumbnailPath, // 保存缩略图路径
        duration: durationTime,
      );

      // 保存视频信息
      await videoProvider.saveVideo(video);
      return video;
    } catch (e) {
      print('文件复制失败: ${e.toString()}');
      throw Exception('文件复制失败: ${e.toString()}');
    }
  }

  // 本地视频复制处理（复制到APP目录）- 带备注版本
  static Future<Video> copyToAppDirectoryWithRemark(
    File sourceFile,
    String title,
    List<String> tagIds,
    String remark,
    VideoProvider videoProvider,
    int durationTime,
  ) async {
    try {
      // 获取新存储位置的视频目录
      final videosDir = StorageUtils.getVideosDirectory();
      await Directory(videosDir).create(recursive: true);

      // 复制文件到APP目录
      final fileName = p.basename(sourceFile.path);
      final targetPath = p.join(videosDir, fileName);
      final targetFile = await sourceFile.copy(targetPath);

      // 生成视频缩略图
      final thumbnailPath =
          await FileUtils.generateVideoThumbnail(targetFile.path);

      // 创建视频对象（包含备注）
      final video = Video(
        title: title,
        filePath: targetFile.path,
        fileSize: await targetFile.length(),
        tagIds: tagIds,
        remark: remark, // 添加备注
        thumbnailPath: thumbnailPath, // 保存缩略图路径
        duration: durationTime,
      );

      // 保存视频信息
      await videoProvider.saveVideo(video);
      return video;
    } catch (e) {
      print('文件复制失败: ${e.toString()}');
      throw Exception('文件复制失败: ${e.toString()}');
    }
  }
}
