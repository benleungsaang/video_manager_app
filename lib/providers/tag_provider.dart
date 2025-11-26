import 'package:flutter/foundation.dart';
import '../repositories/tag_repository.dart';
import '../models/tag.dart';

class TagProvider with ChangeNotifier {
  final TagRepository _repository = TagRepository();
  List<Tag> _tags = [];
  bool _isLoading = false;
  String? _error;

  // 获取标签列表
  List<Tag> get tags => _tags;

  // 加载状态
  bool get isLoading => _isLoading;

  // 错误信息
  String? get error => _error;

  // 加载所有标签
  Future<void> loadTags() async {
    if (_isLoading) return; // 避免重复加载

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _tags = await _repository.getAllTagsAsync(); // 使用异步方法
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('加载标签失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 重新计算所有标签的视频计数
  Future<void> recalculateVideoCounts() async {
    try {
      await _repository.recalculateVideoCounts();
      await loadTags(); // 重新加载列表
    } catch (e) {
      _error = '重新计算标签计数失败: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  // 获取标签详情
  Tag? getTagById(String id) {
    try {
      return _repository.getTagById(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // 创建标签
  Future<Tag?> createTag(String name, {int initialVideoCount = 0}) async {
    try {
      final newTag = await _repository.createTag(name, initialVideoCount: initialVideoCount);
      if (newTag != null) {
        await loadTags(); // 重新加载列表
      }
      return newTag;
    } catch (e) {
      _error = '创建标签失败: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  // 更新标签
  Future<Tag?> updateTag(String id, String newName) async {
    try {
      final updatedTag = await _repository.updateTag(id, newName);
      if (updatedTag != null) {
        await loadTags(); // 重新加载列表
      }
      return updatedTag;
    } catch (e) {
      _error = '更新标签失败: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  // 删除标签
  Future<void> deleteTag(String id) async {
    try {
      await _repository.deleteTag(id);
      await loadTags(); // 重新加载列表
    } catch (e) {
      _error = '删除标签失败: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  // 清除错误状态
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
