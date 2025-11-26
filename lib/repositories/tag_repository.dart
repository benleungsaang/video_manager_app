import '../services/hive_service.dart';
import '../models/tag.dart';
import '../models/video.dart';

class TagRepository {
  // 获取所有标签（同步方法，保留用于向后兼容）
  List<Tag> getAllTags() {
    return HiveService.tagBox.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  // 获取所有标签（异步方法，用于新的加载逻辑）
  Future<List<Tag>> getAllTagsAsync() async {
    try {
      return HiveService.tagBox.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      throw Exception('获取标签列表失败: $e');
    }
  }

  // 根据ID获取标签
  Tag? getTagById(String id) {
    try {
      return HiveService.tagBox.get(id);
    } catch (e) {
      throw Exception('获取标签失败: $e');
    }
  }

  // 检查标签名称是否已存在
  bool isTagNameExists(String name, {String? excludeId}) {
    try {
      return HiveService.tagBox.values
          .any((tag) => tag.name == name && tag.id != excludeId);
    } catch (e) {
      print('检查标签名称存在性时出错: $e');
      return false;
    }
  }

  // 创建标签
  Future<Tag?> createTag(String name, {int initialVideoCount = 0}) async {
    try {
      // 检查名称是否已存在
      if (isTagNameExists(name)) return null;

      final tag = Tag(name: name, videoCount: initialVideoCount);
      await HiveService.tagBox.put(tag.id, tag);
      return tag;
    } catch (e) {
      throw Exception('创建标签失败: $e');
    }
  }

  // 更新标签
  Future<Tag?> updateTag(String id, String newName) async {
    try {
      final tag = getTagById(id);
      if (tag == null) return null;

      // 检查新名称是否已存在
      if (isTagNameExists(newName, excludeId: id)) return null;

      tag.name = newName;
      await tag.save();
      return tag;
    } catch (e) {
      throw Exception('更新标签失败: $e');
    }
  }

  // 删除标签
  Future<void> deleteTag(String id) async {
    try {
      // 1. 删除标签
      await HiveService.tagBox.delete(id);

      // 2. 更新所有关联视频
      final videos = HiveService.videoBox.values
          .where((v) => v.tagIds.contains(id))
          .toList();
      for (final video in videos) {
        video.tagIds.remove(id);
        await video.save();
      }
    } catch (e) {
      throw Exception('删除标签失败: $e');
    }
  }

  // 重新计算标签关联的视频数量
  Future<void> recalculateVideoCounts() async {
    try {
      final tags = getAllTags();

      for (final tag in tags) {
        final count = HiveService.videoBox.values
            .where((video) => video.tagIds.contains(tag.id))
            .length;

        if (tag.videoCount != count) {
          // 数量有变化，更新数量
          tag.videoCount = count;
          await tag.save();
        }
      }
    } catch (e) {
      throw Exception('重新计算标签计数失败: $e');
    }
  }

  // 批量操作功能

  // 批量创建标签
  Future<List<Tag>> createTagsBatch(List<String> names, {int initialVideoCount = 0}) async {
    try {
      final createdTags = <Tag>[];
      for (final name in names) {
        // 检查名称是否已存在
        if (!isTagNameExists(name)) {
          final tag = Tag(name: name, videoCount: initialVideoCount);
          await HiveService.tagBox.put(tag.id, tag);
          createdTags.add(tag);
        }
      }
      return createdTags;
    } catch (e) {
      throw Exception('批量创建标签失败: $e');
    }
  }

  // 批量删除标签
  Future<void> deleteTagsBatch(List<String> ids) async {
    try {
      // 先收集所有关联的视频，然后一次性更新
      for (final video in HiveService.videoBox.values) {
        bool needsUpdate = false;
        for (final id in ids) {
          if (video.tagIds.contains(id)) {
            video.tagIds.remove(id);
            needsUpdate = true;
          }
        }
        if (needsUpdate) {
          await video.save();
        }
      }

      // 批量删除标签
      await HiveService.tagBox.deleteAll(ids);
    } catch (e) {
      throw Exception('批量删除标签失败: $e');
    }
  }

  // 批量更新标签
  Future<List<Tag?>> updateTagsBatch(Map<String, String> idNameMap) async {
    try {
      final updatedTags = <Tag?>[];
      for (final entry in idNameMap.entries) {
        final updatedTag = await updateTag(entry.key, entry.value);
        updatedTags.add(updatedTag);
      }
      return updatedTags;
    } catch (e) {
      throw Exception('批量更新标签失败: $e');
    }
  }

  // 批量获取标签
  List<Tag> getTagsBatch(List<String> ids) {
    try {
      final result = <Tag>[];
      for (final id in ids) {
        final tag = HiveService.tagBox.get(id);
        if (tag != null) {
          result.add(tag);
        }
      }
      return result;
    } catch (e) {
      throw Exception('批量获取标签失败: $e');
    }
  }

  // 批量检查标签名称是否存在
  Map<String, bool> checkTagNamesExistBatch(List<String> names, {String? excludeId}) {
    try {
      final result = <String, bool>{};
      for (final name in names) {
        result[name] = isTagNameExists(name, excludeId: excludeId);
      }
      return result;
    } catch (e) {
      throw Exception('批量检查标签名称失败: $e');
    }
  }
}