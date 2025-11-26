import '../services/hive_service.dart';
import '../models/video.dart';
// import '../models/tag.dart';

class VideoRepository {
  // 获取所有视频（同步方法，保留用于向后兼容）
  List<Video> getAllVideos() {
    return HiveService.videoBox.values.toList()
      ..sort((a, b) => b.uploadTime.compareTo(a.uploadTime));
  }

  // 获取所有视频（异步方法，用于新的加载逻辑）
  Future<List<Video>> getAllVideosAsync() async {
    try {
      return HiveService.videoBox.values.toList()
        ..sort((a, b) => b.uploadTime.compareTo(a.uploadTime));
    } catch (e) {
      throw Exception('获取视频列表失败: $e');
    }
  }

  // 根据ID获取视频
  Video? getVideoById(String id) {
    try {
      return HiveService.videoBox.get(id);
    } catch (e) {
      throw Exception('获取视频失败: $e');
    }
  }

  // 保存视频
  Future<void> saveVideo(Video video) async {
    try {
      // 获取保存前的视频（如果存在）
      final existingVideo = HiveService.videoBox.get(video.id);
      final List<String> oldTagIds = existingVideo?.tagIds ?? [];
      final List<String> newTagIds = video.tagIds;
      
      // 处理新增的标签：如果标签不存在则创建
      await _handleNewTags(newTagIds);
      // 更新标签计数
      await _updateTagCounts(oldTagIds, newTagIds);

      await HiveService.videoBox.put(video.id, video);
    } catch (e) {
      throw Exception('保存视频失败: $e');
    }
  }

  // 处理新增的标签：如果标签不存在则创建
  Future<void> _handleNewTags(List<String> tagIds) async {
    for (final tagId in tagIds) {
      try {
        final tag = HiveService.tagBox.get(tagId);
        if (tag == null) {
          // 如果标签不存在，这可能是前端传入的错误ID，我们忽略或需要处理
          // 通常在前端应该先创建标签再引用
          // 但我们也可以在这里创建一个新标签，如果它不存在
          print('警告: 尝试引用不存在的标签 $tagId');
        }
      } catch (e) {
        print('处理标签时出错: $e');
      }
    }
  }

  // 更新标签计数 - 优化版本，减少数据库访问次数
  Future<void> _updateTagCounts(List<String> oldTagIds, List<String> newTagIds) async {
    // 找出新增的标签（在新列表中但不在旧列表中）
    final addedTagIds = newTagIds.where((tagId) => !oldTagIds.contains(tagId)).toList();
    // 找出被移除的标签（在旧列表中但不在新列表中）
    final removedTagIds = oldTagIds.where((tagId) => !newTagIds.contains(tagId)).toList();

    // 使用Map来收集所有需要更新的标签计数，然后批量更新
    final Map<String, int> tagCountUpdates = {};
    
    // 先从新增标签开始
    for (final tagId in addedTagIds) {
      if (tagCountUpdates.containsKey(tagId)) {
        tagCountUpdates[tagId] = tagCountUpdates[tagId]! + 1;
      } else {
        tagCountUpdates[tagId] = 1;
      }
    }

    // 再处理被移除的标签
    for (final tagId in removedTagIds) {
      if (tagCountUpdates.containsKey(tagId)) {
        tagCountUpdates[tagId] = tagCountUpdates[tagId]! - 1;
      } else {
        tagCountUpdates[tagId] = -1;
      }
    }

    // 批量更新标签计数
    for (final entry in tagCountUpdates.entries) {
      final tag = HiveService.tagBox.get(entry.key);
      if (tag != null) {
        tag.videoCount = (tag.videoCount + entry.value).clamp(0, double.infinity).toInt();
        await tag.save();
      }
    }
  }

  // 删除视频
  Future<void> deleteVideo(String id) async {
    try {
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
    } catch (e) {
      throw Exception('删除视频失败: $e');
    }
  }

  // 根据标签ID获取视频
  List<Video> getVideosByTagId(String tagId) {
    try {
      return HiveService.videoBox.values
          .where((video) => video.tagIds.contains(tagId))
          .toList();
    } catch (e) {
      throw Exception('获取标签关联视频失败: $e');
    }
  }

  // 搜索视频（标题、标签、备注）- 支持多关键字搜索（异步版本）
  Future<List<Video>> searchVideosAsync(String keyword) async {
    try {
      if (keyword.isEmpty) return await getAllVideosAsync();

      // 将关键字按空格分割成多个关键字
      final keywords = keyword.trim().toLowerCase().split(RegExp(r'\s+')).where((k) => k.isNotEmpty).toList();
      
      if (keywords.isEmpty) return await getAllVideosAsync();

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
    } catch (e) {
      throw Exception('搜索视频失败: $e');
    }
  }

  // 搜索视频（标题、标签、备注）- 支持多关键字搜索（同步版本，保留向后兼容）
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

  // 按文件路径筛选视频（异步版本）
  Future<List<Video>> filterVideosByFilePathAsync(String keyword) async {
    try {
      if (keyword.isEmpty) return await getAllVideosAsync();

      final searchKeyword = keyword.toLowerCase();

      return HiveService.videoBox.values.where((video) {
        // 检查文件路径是否包含关键字
        return video.filePath.toLowerCase().contains(searchKeyword);
      }).toList();
    } catch (e) {
      throw Exception('筛选视频失败: $e');
    }
  }

  // 按文件路径筛选视频（同步版本，保留向后兼容）
  List<Video> filterVideosByFilePath(String keyword) {
    if (keyword.isEmpty) return getAllVideos();

    final searchKeyword = keyword.toLowerCase();

    return HiveService.videoBox.values.where((video) {
      // 检查文件路径是否包含关键字
      return video.filePath.toLowerCase().contains(searchKeyword);
    }).toList();
  }
}
