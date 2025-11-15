import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart'; // 新增依赖

class FileUtils {
  // 选择视频文件
  static Future<FilePickerResult?> pickVideo() async {
    return await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
  }

  // 计算文件MD5
  static Future<String> calculateFileMd5(String filePath) async {
    final file = File(filePath);
    final input = file.openRead();
    final digest = await md5.bind(input).first;
    return digest.toString();
  }

  // 获取文件大小格式化显示
  static String formatFileSize(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  // 获取应用缓存目录
  static Future<String> getCacheDirectory() async {
    final directory = await getTemporaryDirectory();
    return directory.path;
  }

  // 创建缩略图保存目录
  static Future<String> getThumbnailDirectory() async {
    final cacheDir = await getCacheDirectory();
    final thumbnailDir = p.join(cacheDir, 'thumbnails');
    await Directory(thumbnailDir).create(recursive: true);
    return thumbnailDir;
  }

  // #################### 新增缩略图相关功能 ####################

  /// 为视频生成缩略图并保存到本地
  /// [videoPath] 视频文件路径
  /// [quality] 缩略图质量(0-100)
  /// 返回缩略图保存路径
  static Future<String?> generateVideoThumbnail(
    String videoPath, {
    int quality = 70,
  }) async {
    try {
      // 1. 获取缩略图保存目录
      final thumbnailDir = await getThumbnailDirectory();

      // 2. 生成唯一文件名（基于视频路径的MD5）
      final videoMd5 = await calculateFileMd5(videoPath);
      final thumbnailFileName = '$videoMd5.jpg';
      final thumbnailPath = p.join(thumbnailDir, thumbnailFileName);

      // 3. 如果缩略图已存在，直接返回路径
      if (await File(thumbnailPath).exists()) {
        return thumbnailPath;
      }

      // 4. 生成缩略图（使用视频第一帧）
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 320, // 缩略图最大宽度
        quality: quality,
      );

      if (uint8list == null) return null;

      // 5. 保存缩略图到本地
      await File(thumbnailPath).writeAsBytes(uint8list);
      return thumbnailPath;
    } catch (e) {
      print('生成缩略图失败: $e');
      return null;
    }
  }

  /// 批量生成视频缩略图（用于初始化）
  static Future<void> generateThumbnailsForVideos(
      List<String> videoPaths) async {
    for (final path in videoPaths) {
      await generateVideoThumbnail(path);
    }
  }

  /// 清理过期的缩略图（超过7天未使用的）
  static Future<void> cleanExpiredThumbnails() async {
    try {
      final thumbnailDir = await getThumbnailDirectory();
      final dir = Directory(thumbnailDir);

      if (!await dir.exists()) return;

      final now = DateTime.now();
      final files = await dir.list().toList();

      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          final modifiedTime = stat.modified;

          // 删除7天前的缩略图
          if (now.difference(modifiedTime).inDays > 7) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('清理缩略图失败: $e');
    }
  }
}
