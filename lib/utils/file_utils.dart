import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';
// import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart'; // 新增依赖
import 'storage_utils.dart'; // 新增导入

class FileUtils {
  // 内存缓存：保存缩略图路径，避免重复计算
  static final Map<String, String> _thumbnailCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

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

  // 获取缩略图保存目录
  static Future<String> getThumbnailDirectory() async {
    final thumbnailDir = StorageUtils.getThumbnailsDirectory();
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
      // 1. 检查内存缓存
      final videoMd5 = await calculateFileMd5(videoPath);
      if (_thumbnailCache.containsKey(videoMd5)) {
        final cachedPath = _thumbnailCache[videoMd5]!;
        final cachedFile = File(cachedPath);
        if (await cachedFile.exists()) {
          // 更新访问时间戳
          _cacheTimestamps[videoMd5] = DateTime.now();
          return cachedPath;
        } else {
          // 如果缓存的文件不存在，从缓存中移除
          _thumbnailCache.remove(videoMd5);
          _cacheTimestamps.remove(videoMd5);
        }
      }

      // 2. 获取缩略图保存目录
      final thumbnailDir = await getThumbnailDirectory();

      // 3. 生成唯一文件名（基于视频路径的MD5）
      final thumbnailFileName = '$videoMd5.jpg';
      final thumbnailPath = p.join(thumbnailDir, thumbnailFileName);

      // 4. 如果缩略图已存在于文件系统，直接返回路径
      final thumbnailFile = File(thumbnailPath);
      if (await thumbnailFile.exists()) {
        _thumbnailCache[videoMd5] = thumbnailPath;
        _cacheTimestamps[videoMd5] = DateTime.now();
        return thumbnailPath;
      }

      // 5. 生成缩略图（使用视频第一帧）
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 320, // 缩略图最大宽度
        quality: quality,
      );

      if (uint8list == null) return null;

      // 6. 保存缩略图到本地
      await thumbnailFile.writeAsBytes(uint8list);
      
      // 7. 更新内存缓存
      _thumbnailCache[videoMd5] = thumbnailPath;
      _cacheTimestamps[videoMd5] = DateTime.now();
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

  /// 清理内存缓存
  static void clearThumbnailCache() {
    _thumbnailCache.clear();
    _cacheTimestamps.clear();
  }

  /// 获取内存缓存大小
  static int getThumbnailCacheSize() {
    return _thumbnailCache.length;
  }

  /// 验证缓存文件是否存在并有效
  static Future<void> validateAndCleanCache() async {
    final keysToRemove = <String>[];
    for (final entry in _thumbnailCache.entries) {
      final path = entry.value;
      if (!await File(path).exists()) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _thumbnailCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// 清理旧的缓存项以控制内存使用
  static void cleanupOldCacheEntries({int maxCacheSize = 100}) {
    if (_thumbnailCache.length <= maxCacheSize) return;

    // 按访问时间排序，移除最旧的项
    final sortedEntries = _cacheTimestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    int toRemove = _thumbnailCache.length - maxCacheSize;
    for (int i = 0; i < toRemove && i < sortedEntries.length; i++) {
      final key = sortedEntries[i].key;
      _thumbnailCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }
}
