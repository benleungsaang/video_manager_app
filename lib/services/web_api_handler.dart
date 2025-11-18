// lib/services/web_api_handler.dart
import 'package:flutter/foundation.dart';
import '../providers/tag_provider.dart';
import '../providers/video_provider.dart';
import '../models/tag.dart';
import '../models/video.dart';
import 'dart:convert';

class WebApiHandler {
  final TagProvider tagProvider;
  final VideoProvider videoProvider;

  WebApiHandler({
    required this.tagProvider,
    required this.videoProvider,
  });

  // 处理Web端的请求
  Future<Map<String, dynamic>> handleRequest(
      Map<String, dynamic> request) async {
    final tempJson = json.decode(request.toString());
    final String action = tempJson['type'];
    final Map<String, dynamic> params = tempJson['data'] ?? {};

    switch (action) {
      // 标签相关接口
      case 'getTags':
        return {
          'success': true,
          'data': tagProvider.tags.map(_tagToJson).toList()
        };
      case 'createTag':
        final Tag? tag = await tagProvider.createTag(params['name']);
        return tag != null
            ? {'success': true, 'data': _tagToJson(tag)}
            : {'success': false, 'error': '标签已存在'};
      case 'deleteTag':
        await tagProvider.deleteTag(params['id']);
        return {'success': true};

      // 视频相关接口
      case 'getVideos':
        print('接收WebSocket请求 WebApiHandler => handleRequest => getVideos');
        return {
          'success': true,
          'data': videoProvider.videos.map(_videoToJson).toList()
        };
      case 'uploadVideo':
        // 实际应处理文件二进制数据，这里简化示例
        final String name = params['name'];
        final String base64Data = params['base64Data'];
        // 调用VideoProvider的保存逻辑（需自行实现文件解析）
        return {'success': true};

      default:
        return {'success': false, 'error': '未知操作'};
    }
  }

  // 转换Tag为JSON（供Web端解析）
  Map<String, dynamic> _tagToJson(Tag tag) {
    return {
      'id': tag.id,
      'name': tag.name,
      'videoCount': tag.videoCount,
    };
  }

  // 转换Video为JSON（供Web端解析）
  Map<String, dynamic> _videoToJson(Video video) {
    return {
      'id': video.id,
      'title': video.title,
      'filePath': video.filePath,
      'thumbnailPath': video.thumbnailPath,
      'tagIds': video.tagIds,
      'uploadTime': video.uploadTime.toIso8601String(),
    };
  }
}
