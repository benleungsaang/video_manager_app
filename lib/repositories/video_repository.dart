import '../services/hive_service.dart';
import '../models/video.dart';
// import '../models/tag.dart';

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
    // 获取保存前的视频（如果存在）
    final existingVideo = HiveService.videoBox.get(video.id);
    final List<String> oldTagIds = existingVideo?.tagIds ?? [];
    final List<String> newTagIds = video.tagIds;
    
    // 处理新增的标签：如果标签不存在则创建
    await _handleNewTags(newTagIds);
    // 更新标签计数
    await _updateTagCounts(oldTagIds, newTagIds);

    await HiveService.videoBox.put(video.id, video);
  }

  // 处理新增的标签：如果标签不存在则创建
  Future<void> _handleNewTags(List<String> tagIds) async {
    for (final tagId in tagIds) {
      final tag = HiveService.tagBox.get(tagId);
      if (tag == null) {
        // 如果标签不存在，这可能是前端传入的错误ID，我们忽略或需要处理
        // 通常在前端应该先创建标签再引用
        // 但我们也可以在这里创建一个新标签，如果它不存在
        print('警告: 尝试引用不存在的标签 $tagId');
      }
    }
  }

  // 更新标签计数
  Future<void> _updateTagCounts(List<String> oldTagIds, List<String> newTagIds) async {
    // 找出新增的标签（在新列表中但不在旧列表中）
    final addedTagIds = newTagIds.where((tagId) => !oldTagIds.contains(tagId)).toList();
    // 找出被移除的标签（在旧列表中但不在新列表中）
    final removedTagIds = oldTagIds.where((tagId) => !newTagIds.contains(tagId)).toList();

    // 增加新增标签的计数
    for (final tagId in addedTagIds) {
      final tag = HiveService.tagBox.get(tagId);
      if (tag != null) {
        tag.videoCount = (tag.videoCount ?? 0) + 1;
        await tag.save();
      }
    }

    // 减少被移除标签的计数
    for (final tagId in removedTagIds) {
      final tag = HiveService.tagBox.get(tagId);
      if (tag != null) {
        tag.videoCount = (tag.videoCount > 0) ? tag.videoCount - 1 : 0;
        await tag.save();
      }
    }
  }

  // 删除视频
  Future<void> deleteVideo(String id) async {
    final video = HiveService.videoBox.get(id);
    if (video == null) return;

    // 保存视频关联的标签ID，用于后续检查
    final associatedTagIds = List<String>.from(video.tagIds);

    await HiveService.videoBox.delete(id);

    // 减少关联标签的计数
    for (final tagId in associatedTagIds) {
      final tag = HiveService.tagBox.get(tagId);
      if (tag != null) {
        tag.videoCount = (tag.videoCount > 0) ? tag.videoCount - 1 : 0;
        await tag.save();
      }
    }
  }

  // 根据标签ID获取视频
  List<Video> getVideosByTagId(String tagId) {
    return HiveService.videoBox.values
        .where((video) => video.tagIds.contains(tagId))
        .toList();
  }

  // 搜索视频（标题、标签、备注）- 支持多关键字搜索
  List<Video> searchVideos(String keyword) {
    if (keyword.isEmpty) return getAllVideos();

    // 将关键字按空格分割成多个关键字
    final keywords = keyword.trim().toLowerCase().split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
    
    if (keywords.isEmpty) return getAllVideos();

    return HiveService.videoBox.values.where((video) {
      // 检查视频是否匹配所有关键字
      return keywords.every((singleKeyword) {
        // 标题匹配
        final titleMatch = video.title.toLowerCase().contains(singleKeyword);

        // 备注匹配
        final remarkMatch = video.remark.toLowerCase().contains(singleKeyword);

        // 标签匹配
        final tagMatch = video.tagIds.any((tagId) {
          final tag = HiveService.tagBox.get(tagId);
          return tag != null && tag.name.toLowerCase().contains(singleKeyword);
        });

        // 任何一个匹配即可
        return titleMatch || remarkMatch || tagMatch;
      });
    }).toList();
  }

  // 按文件路径筛选视频
  List<Video> filterVideosByFilePath(String keyword) {
    if (keyword.isEmpty) return getAllVideos();

    final searchKeyword = keyword.toLowerCase();

    return HiveService.videoBox.values.where((video) {
      // 检查文件路径是否包含关键字
      return video.filePath.toLowerCase().contains(searchKeyword);
    }).toList();
  }
}
