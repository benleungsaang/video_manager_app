import '../services/hive_service.dart';
import '../models/tag.dart';
import '../models/video.dart';

class TagRepository {
  // 获取所有标签
  List<Tag> getAllTags() {
    return HiveService.tagBox.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  // 根据ID获取标签
  Tag? getTagById(String id) {
    return HiveService.tagBox.get(id);
  }

  // 检查标签名称是否已存在
  bool isTagNameExists(String name, {String? excludeId}) {
    return HiveService.tagBox.values
        .any((tag) => tag.name == name && tag.id != excludeId);
  }

  // 创建标签
  Future<Tag?> createTag(String name) async {
    // 检查名称是否已存在
    if (isTagNameExists(name)) return null;

    final tag = Tag(name: name);
    await HiveService.tagBox.put(tag.id, tag);
    return tag;
  }

  // 更新标签
  Future<Tag?> updateTag(String id, String newName) async {
    final tag = getTagById(id);
    if (tag == null) return null;

    // 检查新名称是否已存在
    if (isTagNameExists(newName, excludeId: id)) return null;

    tag.name = newName;
    await tag.save();
    return tag;
  }

  // 删除标签
  Future<void> deleteTag(String id) async {
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
  }

  // 重新计算标签关联的视频数量
  Future<void> recalculateVideoCounts() async {
    final tags = getAllTags();
    final tagsToDelete = <String>[]; // 存储需要删除的标签ID

    for (final tag in tags) {
      final count = HiveService.videoBox.values
          .where((video) => video.tagIds.contains(tag.id))
          .length;

      if (count == 0) {
        // 没有关联视频，标记为待删除
        tagsToDelete.add(tag.id);
      } else if (tag.videoCount != count) {
        // 数量有变化，更新数量
        tag.videoCount = count;
        await tag.save();
      }
    }

    // 批量删除无引用的标签
    if (tagsToDelete.isNotEmpty) {
      for (final tagId in tagsToDelete) {
        await HiveService.tagBox.delete(tagId);
      }
    }
  }
}
