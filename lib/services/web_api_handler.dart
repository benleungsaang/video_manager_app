// lib/services/web_api_handler.dart
import 'dart:io';

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
  // 参数: request包含action和params
  // 返回: 包含success、data或error的Map
  Future<Map<String, dynamic>> handleRequest(
      Map<String, dynamic> request) async {
    // 解析请求类型和参数
    final String action = request['action'];
    final Map<String, dynamic> params = request['params'] ?? {};

    try {
      switch (action) {
        // 标签相关接口
        case 'getTags':
          // 获取所有标签并转换为JSON
          return {
            'success': true,
            'data': tagProvider.tags.map(_tagToJson).toList()
          };

        case 'createTag':
          // 创建新标签
          final Tag? tag = await tagProvider.createTag(params['name']);
          return tag != null
              ? {'success': true, 'data': _tagToJson(tag)}
              : {'success': false, 'error': '标签已存在'};

        case 'deleteTag':
          // 删除标签
          await tagProvider.deleteTag(params['id']);
          return {'success': true};

        // 视频相关接口
        // 获取视频列表
        case 'getVideos':
          // 获取所有视频并转换为JSON
          return {
            'success': true,
            'data': videoProvider.videos.map(_videoToJson).toList()
          };
        // 获取缩略图
        case 'getThumbnail':
          // 获取视频缩略图
          final String videoId = params['videoId'];
          final Video? video = videoProvider.getVideoById(videoId);
          if (video != null && video.thumbnailPath != null) {
            // 读取缩略图文件并转换为base64
            final File thumbnailFile = File(video.thumbnailPath!);
            final List<int> bytes = await thumbnailFile.readAsBytes();
            final String base64Data = base64Encode(bytes);
            // 统一格式：将数据放在data字段中
            return {
              'success': true,
              'data': {'base64': base64Data}
            };
          } else {
            return {'success': false, 'error': '缩略图不存在'};
          }

        // case 'uploadVideo':
        //   // 处理视频上传
        //   final String name = params['name'];
        //   final String base64Data = params['base64Data'];
        //   // 实际应用中需要解析base64数据并保存为文件
        //   final Video? video = await videoProvider.saveVideo(
        //     name: name,
        //     base64Data: base64Data
        //   );
        //   return video != null
        //       ? {'success': true, 'data': _videoToJson(video)}
        //       : {'success': false, 'error': '视频上传失败'};

        default:
          return {'success': false, 'error': '未知操作: $action'};
      }
    } catch (e) {
      // 捕获所有异常并返回错误信息
      return {'success': false, 'error': e.toString()};
    }
  }

  // 转换Tag为JSON格式
  Map<String, dynamic> _tagToJson(Tag tag) {
    return {
      'id': tag.id,
      'name': tag.name,
      'videoCount': tag.videoCount,
    };
  }

  // 转换Video为JSON格式
  Map<String, dynamic> _videoToJson(Video video) {
    return {
      'id': video.id,
      'title': video.title,
      'filePath': video.filePath,
      'thumbnailPath': video.thumbnailPath,
      'tagIds': video.tagIds,
      'uploadTime': video.uploadTime.toIso8601String(),
      'fileSize': video.fileSize,
      'duration': video.duration,
    };
  }
}
