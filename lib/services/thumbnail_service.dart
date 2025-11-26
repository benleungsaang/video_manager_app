import 'dart:io';
import 'package:video_manager_app/models/video.dart';
import 'package:video_manager_app/providers/video_provider.dart';
import 'package:video_manager_app/utils/file_utils.dart';

class ThumbnailService {
  final VideoProvider _videoProvider;

  ThumbnailService(this._videoProvider);

  /// 为缺失缩略图的视频批量生成缩略图
  Future<void> generateMissingThumbnails() async {
    try {
      final videosWithoutThumbnails = _videoProvider.videos
          .where((v) => v.thumbnailPath == null)
          .map((v) => v.filePath)
          .toList();

      if (videosWithoutThumbnails.isNotEmpty) {
        await FileUtils.generateThumbnailsForVideos(videosWithoutThumbnails);
        // 重新加载视频列表以更新缩略图路径
        _videoProvider.loadVideos();
      }
    } catch (e) {
      print('生成缺失缩略图时出错: $e');
    }
  }

  /// 为单个视频生成缩略图
  Future<String?> generateThumbnailForVideo(Video video) async {
    if (video.thumbnailPath != null) {
      return video.thumbnailPath;
    }

    final thumbnailPath = await FileUtils.generateVideoThumbnail(video.filePath);
    if (thumbnailPath != null) {
      video.thumbnailPath = thumbnailPath;
      await video.save(); // 保存视频对象以更新缩略图路径
    }

    return thumbnailPath;
  }

  /// 为视频列表批量生成缩略图
  Future<void> generateThumbnailsForVideos(List<Video> videos) async {
    for (final video in videos) {
      await generateThumbnailForVideo(video);
    }
  }

  /// 清理过期的缩略图
  Future<void> cleanExpiredThumbnails() async {
    try {
      await FileUtils.cleanExpiredThumbnails();
    } catch (e) {
      print('清理过期缩略图时出错: $e');
    }
  }

  /// 验证缩略图文件是否存在，如果不存在则重新生成
  Future<void> validateAndRegenerateThumbnails() async {
    final videosWithMissingThumbnails = _videoProvider.videos.where((video) {
      if (video.thumbnailPath == null) return true;
      final thumbnailFile = File(video.thumbnailPath!);
      return !thumbnailFile.existsSync();
    }).toList();

    if (videosWithMissingThumbnails.isNotEmpty) {
      await generateThumbnailsForVideos(videosWithMissingThumbnails);
    }
  }
}