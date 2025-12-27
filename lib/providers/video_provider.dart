import 'package:flutter/foundation.dart';
import '../repositories/video_repository.dart';
import '../models/video.dart';

class VideoProvider with ChangeNotifier {
  final VideoRepository _repository = VideoRepository();
  List<Video> _videos = [];
  bool _isLoading = false;
  String? _error;

  // 新增网络上传状态（暂未使用，留着后续开发 web端上传时使用，或者到时候不是这样用）
  // double _networkUploadProgress = 0.0;
  // bool _isNetworkUploading = false;

    // 获取视频列表
    List<Video> get videos => _videos;
  
    // 获取最近上传的视频
    List<Video> getRecentVideos(int limit) {
      return _videos
          .where((video) => video.uploadTime != null)
          .toList()
        ..sort((a, b) => b.uploadTime.compareTo(a.uploadTime))
        ..removeRange(limit, _videos.length > limit ? _videos.length : limit);
    }
  // 加载状态
  bool get isLoading => _isLoading;

  // 错误信息
  String? get error => _error;

  // 加载所有视频
  Future<void> loadVideos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _videos = await _repository.getAllVideosAsync(); // 使用异步方法
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('加载视频失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 获取视频详情
  Video? getVideoById(String id) {
    try {
      return _repository.getVideoById(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // 保存视频
  Future<void> saveVideo(Video video) async {
    try {
      await _repository.saveVideo(video);
      await loadVideos(); // 重新加载列表
    } catch (e) {
      _error = '保存视频失败: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  // 删除视频
  Future<void> deleteVideo(String id) async {
    try {
      await _repository.deleteVideo(id);
      await loadVideos(); // 重新加载列表
    } catch (e) {
      _error = '删除视频失败: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  // 搜索视频
  Future<void> searchVideos(String keyword) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _videos = await _repository.searchVideosAsync(keyword); // 使用异步方法
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('搜索视频失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 按文件路径筛选视频
  Future<void> filterVideosByFilePath(String keyword) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _videos = await _repository.filterVideosByFilePathAsync(keyword); // 使用异步方法
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('筛选视频失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 清除错误状态
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
