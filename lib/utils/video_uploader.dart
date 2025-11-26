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
  
  // 重试配置
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);
  
  static Future<Video> copyToAppDirectory(
    File sourceFile,
    String title,
    List<String> tagIds,
    VideoProvider videoProvider,
    int durationTime,
  ) async {
    Video? result;
    String? lastError;
    
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        // 获取新存储位置的视频目录
        final videosDir = StorageUtils.getVideosDirectory();
        await Directory(videosDir).create(recursive: true);

        // 检查源文件是否存在
        if (!await sourceFile.exists()) {
          throw Exception('源文件不存在: ${sourceFile.path}');
        }

        // 检查可用存储空间
        final sourceFileSize = await sourceFile.length();
        final availableSpace = await StorageUtils.getAvailableStorageSpace();
        if (availableSpace < sourceFileSize * 1.1) { // 预留10%空间
          throw Exception('存储空间不足，需要 ${FileUtils.formatFileSize(sourceFileSize)}, 可用 ${FileUtils.formatFileSize(availableSpace)}');
        }

        // 复制文件到APP目录
        final fileName = p.basename(sourceFile.path);
        final targetPath = p.join(videosDir, fileName);
        final targetFile = await sourceFile.copy(targetPath);

        // 生成视频缩略图（带重试机制）
        String? thumbnailPath;
        for (int thumbAttempt = 0; thumbAttempt <= _maxRetries; thumbAttempt++) {
          try {
            thumbnailPath = await FileUtils.generateVideoThumbnail(targetFile.path);
            if (thumbnailPath != null) break;
          } catch (e) {
            print('生成缩略图失败 (尝试 $thumbAttempt): $e');
            if (thumbAttempt < _maxRetries) {
              await Future.delayed(_retryDelay * (thumbAttempt + 1)); // 指数退避
            } else {
              print('生成缩略图最终失败: $e');
            }
          }
        }

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
        result = video;
        break; // 成功，跳出重试循环
      } catch (e) {
        lastError = e.toString();
        print('文件复制失败 (尝试 $attempt): ${e.toString()}');
        if (attempt < _maxRetries) {
          // 清理可能创建的不完整文件
          final videosDir = StorageUtils.getVideosDirectory();
          final fileName = p.basename(sourceFile.path);
          final targetPath = p.join(videosDir, fileName);
          final targetFile = File(targetPath);
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          
          // 等待后重试
          await Future.delayed(_retryDelay * (attempt + 1)); // 指数退避
        } else {
          print('文件复制最终失败: $e');
        }
      }
    }

    if (result == null) {
      throw Exception('文件复制失败，已重试 $_maxRetries 次，最后错误: $lastError');
    }
    return result;
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
    Video? result;
    String? lastError;
    
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        // 获取新存储位置的视频目录
        final videosDir = StorageUtils.getVideosDirectory();
        await Directory(videosDir).create(recursive: true);

        // 检查源文件是否存在
        if (!await sourceFile.exists()) {
          throw Exception('源文件不存在: ${sourceFile.path}');
        }

        // 检查可用存储空间
        final sourceFileSize = await sourceFile.length();
        final availableSpace = await StorageUtils.getAvailableStorageSpace();
        if (availableSpace < sourceFileSize * 1.1) { // 预留10%空间
          throw Exception('存储空间不足，需要 ${FileUtils.formatFileSize(sourceFileSize)}, 可用 ${FileUtils.formatFileSize(availableSpace)}');
        }

        // 复制文件到APP目录
        final fileName = p.basename(sourceFile.path);
        final targetPath = p.join(videosDir, fileName);
        final targetFile = await sourceFile.copy(targetPath);

        // 生成视频缩略图（带重试机制）
        String? thumbnailPath;
        for (int thumbAttempt = 0; thumbAttempt <= _maxRetries; thumbAttempt++) {
          try {
            thumbnailPath = await FileUtils.generateVideoThumbnail(targetFile.path);
            if (thumbnailPath != null) break;
          } catch (e) {
            print('生成缩略图失败 (尝试 $thumbAttempt): $e');
            if (thumbAttempt < _maxRetries) {
              await Future.delayed(_retryDelay * (thumbAttempt + 1)); // 指数退避
            } else {
              print('生成缩略图最终失败: $e');
            }
          }
        }

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
        result = video;
        break; // 成功，跳出重试循环
      } catch (e) {
        lastError = e.toString();
        print('文件复制失败 (尝试 $attempt): ${e.toString()}');
        if (attempt < _maxRetries) {
          // 清理可能创建的不完整文件
          final videosDir = StorageUtils.getVideosDirectory();
          final fileName = p.basename(sourceFile.path);
          final targetPath = p.join(videosDir, fileName);
          final targetFile = File(targetPath);
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          
          // 等待后重试
          await Future.delayed(_retryDelay * (attempt + 1)); // 指数退避
        } else {
          print('文件复制最终失败: $e');
        }
      }
    }

    if (result == null) {
      throw Exception('文件复制失败，已重试 $_maxRetries 次，最后错误: $lastError');
    }
    return result;
  }

  /// 获取当前文件上传状态信息
  static String getUploadStatus() {
    return '最大重试次数: $_maxRetries, 重试延迟: ${_retryDelay.inSeconds}秒';
  }
}
