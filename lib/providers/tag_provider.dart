import 'package:flutter/foundation.dart';
import '../repositories/tag_repository.dart';
import '../models/tag.dart';

class TagProvider with ChangeNotifier {
  final TagRepository _repository = TagRepository();
  List<Tag> _tags = [];

  // 获取标签列表
  List<Tag> get tags => _tags;

  // 加载所有标签
  void loadTags() {
    _tags = _repository.getAllTags();
    notifyListeners();
  }

  // 获取标签详情
  Tag? getTagById(String id) {
    return _repository.getTagById(id);
  }

  // 创建标签
  Future<Tag?> createTag(String name) async {
    final newTag = await _repository.createTag(name);
    if (newTag != null) {
      loadTags(); // 重新加载列表
    }
    return newTag;
  }

  // 更新标签
  Future<Tag?> updateTag(String id, String newName) async {
    final updatedTag = await _repository.updateTag(id, newName);
    if (updatedTag != null) {
      loadTags(); // 重新加载列表
    }
    return updatedTag;
  }

  // 删除标签
  Future<void> deleteTag(String id) async {
    await _repository.deleteTag(id);
    loadTags(); // 重新加载列表
  }

  // 重新计算标签视频数量
  Future<void> recalculateVideoCounts() async {
    await _repository.recalculateVideoCounts();
    loadTags(); // 重新加载列表
  }
}
