import '../services/hive_service.dart';
import '../models/video.dart';
import '../models/tag.dart';

class VideoRepository {
  // 获取所有视频
  List<Video> getAllVideos() {
    return HiveService.videoBox.values.toList()
      ..sort((a, b) => b.uploadTime.compareTo(a.uploadTime));
  }

  // 根据ID获取视频
  Video? getVideoById(String id) {
    return HiveService.videoBox.get(id);
  }

  // 保存视频
  Future<void> saveVideo(Video video) async {
    await HiveService.videoBox.put(video.id, video);
  }

  // 删除视频
  Future<void> deleteVideo(String id) async {
    final video = HiveService.videoBox.get(id);
    if (video == null) return;

    // 保存视频关联的标签ID，用于后续检查
    final associatedTagIds = List<String>.from(video.tagIds);

    await HiveService.videoBox.delete(id);

    // 检查关联标签的引用情况，计算该标签当前被多少视频引用
    for (final tagId in associatedTagIds) {
      final remainingVideos = HiveService.videoBox.values
          .where((v) => v.tagIds.contains(tagId))
          .length;

      if (remainingVideos == 0) {
        await HiveService.tagBox.delete(tagId);
      }
    }
  }

  // 根据标签ID获取视频
  List<Video> getVideosByTagId(String tagId) {
    return HiveService.videoBox.values
        .where((video) => video.tagIds.contains(tagId))
        .toList();
  }

  // 搜索视频（标题、标签、备注）
  List<Video> searchVideos(String keyword) {
    if (keyword.isEmpty) return getAllVideos();

    final lowerKeyword = keyword.toLowerCase();
    return HiveService.videoBox.values.where((video) {
      // 标题匹配
      final titleMatch = video.title.toLowerCase().contains(lowerKeyword);

      // 备注匹配
      final remarkMatch = video.remark.toLowerCase().contains(lowerKeyword);

      // 标签匹配
      final tagMatch = video.tagIds.any((tagId) {
        final tag = HiveService.tagBox.get(tagId);
        return tag != null && tag.name.toLowerCase().contains(lowerKeyword);
      });

      return titleMatch || remarkMatch || tagMatch;
    }).toList();
  }
}
