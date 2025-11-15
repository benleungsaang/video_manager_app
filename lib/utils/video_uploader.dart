import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/video.dart';
import '../providers/video_provider.dart';

class VideoUploader {
  // 本地视频复制处理（复制到APP目录）
  static Future<void> copyToAppDirectory(
    File sourceFile,
    String title,
    List<String> tagIds,
    VideoProvider videoProvider,
  ) async {
    try {
      // 获取APP的视频存储目录
      final appDir = await getApplicationDocumentsDirectory();
      final videosDir = p.join(appDir.path, 'videos');
      await Directory(videosDir).create(recursive: true);

      // 复制文件到APP目录
      final fileName = p.basename(sourceFile.path);
      final targetPath = p.join(videosDir, fileName);
      final targetFile = await sourceFile.copy(targetPath);

      // 创建视频对象
      final video = Video(
        title: title,
        filePath: targetFile.path,
        fileSize: await targetFile.length(),
        tagIds: tagIds,
      );

      // 保存视频信息
      await videoProvider.saveVideo(video);
    } catch (e) {
      throw Exception('文件复制失败: ${e.toString()}');
    }
  }

  // 检查视频大小是否超过限制
  // static bool checkVideoSizeLimit(File file, {int maxSizeGB = 10}) {
  //   final maxSizeBytes = maxSizeGB * 1024 * 1024 * 1024;
  //   return file.lengthSync() <= maxSizeBytes;
  // }
}
