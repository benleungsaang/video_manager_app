import 'package:flutter/foundation.dart';
import '../repositories/video_repository.dart';
import '../models/video.dart';

class VideoProvider with ChangeNotifier {
  final VideoRepository _repository = VideoRepository();
  List<Video> _videos = [];

  // 新增网络上传状态（暂未使用，留着后续开发 web端上传时使用，或者到时候不是这样用）
  // double _networkUploadProgress = 0.0;
  // bool _isNetworkUploading = false;

  // 获取视频列表
  List<Video> get videos => _videos;

  // 加载所有视频
  void loadVideos() {
    _videos = _repository.getAllVideos();
    notifyListeners();
  }

  // 获取视频详情
  Video? getVideoById(String id) {
    return _repository.getVideoById(id);
  }

  // 保存视频
  Future<void> saveVideo(Video video) async {
    await _repository.saveVideo(video);
    loadVideos(); // 重新加载列表
  }
 
  // 删除视频
  Future<void> deleteVideo(String id) async {
    await _repository.deleteVideo(id);
    loadVideos(); // 重新加载列表
  }

  // 搜索视频
  void searchVideos(String keyword) {
    _videos = _repository.searchVideos(keyword);
    notifyListeners();
  }
}
