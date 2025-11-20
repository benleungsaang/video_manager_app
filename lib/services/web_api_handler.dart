// lib/services/web_api_handler.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_manager_app/main.dart';
import 'package:video_manager_app/utils/file_utils.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../providers/tag_provider.dart';
import '../providers/video_provider.dart';
import '../models/tag.dart';
import '../models/video.dart';
import 'dart:convert';

// 二进制分块上传类
class UploadingFile {
  final String fileId;
  final int totalSize;
  int totalChunks;
  Map<int, Uint8List> chunks = {};
  int receivedSize = 0;

  UploadingFile({
    required this.fileId,
    required this.totalSize,
    required this.totalChunks,
  });
}

class WebApiHandler {
  // 静态获取Provider实例，并不会实时更新
  // final TagProvider tagProvider;
  // final VideoProvider videoProvider;

  // WebApiHandler({
  //   required this.tagProvider,
  //   required this.videoProvider,
  // });

  // 通过全局动态获取Provider实例
  WebApiHandler();

  // 动态获取最新的Provider实例（需结合Provider全局访问）
  VideoProvider get _videoProvider =>
      Provider.of<VideoProvider>(navigatorKey.currentContext!, listen: false);
  TagProvider get _tagProvider =>
      Provider.of<TagProvider>(navigatorKey.currentContext!, listen: false);

  final Map<String, UploadingFile> _uploadingFiles = {};

  // 处理Web端的请求
  // 参数: request包含action和params
  // 返回: 包含success、data或error的Map
  Future<Map<String, dynamic>> handleRequest(
    WebSocketChannel channel,
    Map<String, dynamic> request,
  ) async {
    // 解析请求类型和参数
    final String action = request['action'];
    final Map<String, dynamic> params = request['params'] ?? {};
    final String requestId = request['id'];

    try {
      switch (action) {
        // 标签相关接口
        case 'getTags':
          // 获取所有标签并转换为JSON
          return {
            'success': true,
            'data': _tagProvider.tags.map(_tagToJson).toList()
          };

        case 'createTag':
          // 创建新标签
          final Tag? tag = await _tagProvider.createTag(params['name']);
          return tag != null
              ? {'success': true, 'data': _tagToJson(tag)}
              : {'success': false, 'error': '标签已存在'};

        case 'deleteTag':
          // 删除标签
          await _tagProvider.deleteTag(params['id']);
          return {'success': true};

        // 视频相关接口
        // 获取视频列表
        case 'getVideos':
          // 获取所有视频并转换为JSON
          return {
            'success': true,
            'data': _videoProvider.videos.map(_videoToJson).toList()
          };
        // 添加获取视频播放URL的处理
        case 'getVideoUrl':
          final String videoId = params['videoId'];
          final Video? video = _videoProvider.getVideoById(videoId);
          if (video != null && video.filePath != null) {
            // 对于Web端，返回文件的相对路径或URL
            return {
              'success': true,
              'data': {'videoUrl': video.filePath}
            };
          } else {
            return {'success': false, 'error': '视频文件不存在'};
          }
        // 删除视频
        case 'deleteVideo':
          final String videoId = params['id'];
          await _videoProvider.deleteVideo(videoId);
          return {'success': true};
        // 获取缩略图
        case 'getThumbnail':
          // 获取视频缩略图
          final String videoId = params['videoId'];
          final Video? video = _videoProvider.getVideoById(videoId);
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
        // 搜索视频
        case 'searchVideos':
          final String query = params['query'] ?? '';
          _videoProvider.searchVideos(query);
          return {
            'success': true,
            'data': _videoProvider.videos.map(_videoToJson).toList()
          };
        case 'uploadVideo':
          // 处理视频上传
          final String name = params['name'];
          final String base64Data = params['base64Data'];
          final int duration = params['duration']; // 假设前端传入视频时长
          final int fileSize = params['fileSize']; // 假设前端传入文件大小
          final String remark = params['remark'] ?? ''; // 备注信息
          final List<String> tagIds =
              List<String>.from(params['tagIds'] ?? []); // 标签ID列表
          // 视频保存目录
          final appDir = await getApplicationDocumentsDirectory();
          final videosDir = p.join(appDir.path, 'videos');
          await Directory(videosDir).create(recursive: true);
          final videoFilePath = p.join(
              videosDir, '${DateTime.now().millisecondsSinceEpoch}_$name');

          // 1. 将base64数据转换为文件（实际项目中需处理存储路径）
          final bytes = base64Decode(base64Data);
          await File(videoFilePath).writeAsBytes(bytes);

          // 为刚上传的视频生成缩略图并更新视频信息
          final thumbNailPath = await FileUtils.generateVideoThumbnail(
              videoFilePath); // 生成缩略图的临时路径

          // 2. 创建Video对象（根据实际Video类的构造函数调整参数）
          final newVideo = Video(
            id: 'video_${DateTime.now().millisecondsSinceEpoch}', // 生成唯一ID
            title: name,
            remark: remark,
            filePath: videoFilePath,
            duration: duration,
            fileSize: fileSize,
            uploadTime: DateTime.now(),
            tagIds: tagIds,
            thumbnailPath: thumbNailPath,
          );

          // 3. 调用VideoProvider保存视频（原方法是void，无返回值）
          await _videoProvider.saveVideo(newVideo);

          // 4. 由于saveVideo已调用loadVideos()，直接从Provider获取最新视频列表
          // 查找刚上传的视频（通过ID匹配，确保返回最新数据）
          final uploadedVideo = _videoProvider.videos.firstWhere(
            (v) => v.id == newVideo.id,
            orElse: () => throw Exception('视频保存后未找到'),
          );
          return {
            'success': true,
            'data': _videoToJson(uploadedVideo), // 返回完整的视频信息
          };
        // 处理二进制块元数据
        case 'initBinaryUpload':
          return await _handleInitBinaryUpload(params);
        // 【 逐份接收 】分块上传的二进制数据
        case 'uploadBinaryChunk':
          return await _handleUploadBinaryChunk(channel, params, requestId);
        // 【 合并 】 分块上传的进制数据
        case 'completeBinaryUpload':
          return await _handleCompleteBinaryUpload(params);
        // 添加取消二进制上传处理
        case 'cancelBinaryUpload':
          final String fileId = params['fileId'];
          if (_uploadingFiles.containsKey(fileId)) {
            _uploadingFiles.remove(fileId);
          } else {
            // 检查是否有未合并的临时文件
            final appDir = await getApplicationDocumentsDirectory();
            final tempDir = p.join(appDir.path, 'temp_uploads');
            final tempFile = File(p.join(tempDir, fileId));
            if (await tempFile.exists()) {
              await tempFile.delete();
            }
          }
          return {'success': true};
        default:
          return {'success': false, 'error': '未知操作: $action'};
      }
    } catch (e) {
      // 捕获所有异常并返回错误信息
      return {'success': false, 'error': e.toString()};
    }
  }

  // 初始化二进制上传
  Future<Map<String, dynamic>> _handleInitBinaryUpload(
      Map<String, dynamic> params) async {
    final String fileId = params['fileId'];
    final int totalSize = params['totalSize'];

    if (_uploadingFiles.containsKey(fileId)) {
      return {'success': false, 'error': '文件ID已存在'};
    }

    _uploadingFiles[fileId] = UploadingFile(
      fileId: fileId,
      totalSize: totalSize,
      totalChunks: 0, // 暂时不知道总块数，后续会更新
    );

    return {'success': true};
  }

  // 处理二进制块元数据
  Future<Map<String, dynamic>> _handleUploadBinaryChunk(
      WebSocketChannel channel,
      Map<String, dynamic> params,
      String requestId) async {
    final String fileId = params['fileId'];
    final int chunkIndex = params['chunkIndex'];
    final int totalChunks = params['totalChunks'];

    if (!_uploadingFiles.containsKey(fileId)) {
      return {'success': false, 'error': '未初始化上传'};
    }

    // 更新总块数
    final uploadFile = _uploadingFiles[fileId]!;
    uploadFile.totalChunks = totalChunks;

    // 通知客户端可以发送二进制数据
    return {'status': 'ready'};
  }

// 处理二进制数据
  void handleBinaryData({
    required WebSocketChannel channel,
    required String fileId,
    required int chunkIndex,
    required Uint8List data,
    required String requestId,
  }) {
    if (!_uploadingFiles.containsKey(fileId)) {
      channel.sink.add(
          json.encode({'id': requestId, 'success': false, 'error': '文件不存在'}));
      return;
    }

    final uploadFile = _uploadingFiles[fileId]!;
    uploadFile.chunks[chunkIndex] = data;
    uploadFile.receivedSize += data.length;

    // 计算进度
    final progress =
        (uploadFile.receivedSize / uploadFile.totalSize * 100).toInt();

    // 返回进度信息
    channel.sink.add(
        json.encode({'id': requestId, 'success': true, 'progress': progress}));
  }

// 完成二进制上传
  Future<Map<String, dynamic>> _handleCompleteBinaryUpload(
      Map<String, dynamic> params) async {
    final String fileId = params['fileId'];
    final String name = params['name'];
    final int duration = params['duration'];
    final int fileSize = params['fileSize'];
    final String remark = params['remark'] ?? '';
    final List<String> tagIds = List<String>.from(params['tagIds'] ?? []);

    if (!_uploadingFiles.containsKey(fileId)) {
      return {'success': false, 'error': '未找到上传中的文件'};
    }

    final UploadingFile uploadingFile = _uploadingFiles[fileId]!;

    // 验证完整性
    if (uploadingFile.receivedSize != fileSize ||
        uploadingFile.chunks.length != uploadingFile.totalChunks) {
      return {'success': false, 'error': '文件分片不完整'};
    }

    // 合并文件
    final appDir = await getApplicationDocumentsDirectory();
    final videosDir = p.join(appDir.path, 'videos');
    await Directory(videosDir).create(recursive: true);
    final videoFilePath =
        p.join(videosDir, '${DateTime.now().millisecondsSinceEpoch}_$name');

    final File videoFile = File(videoFilePath);
    final IOSink sink = videoFile.openWrite();

    // 按顺序写入所有分片
    for (int i = 0; i < uploadingFile.totalChunks; i++) {
      sink.add(uploadingFile.chunks[i]!);
    }
    await sink.close();

    // 生成缩略图
    final thumbNailPath = await FileUtils.generateVideoThumbnail(videoFilePath);

    // 创建视频对象
    final newVideo = Video(
      id: 'video_${DateTime.now().millisecondsSinceEpoch}',
      title: name,
      remark: remark,
      filePath: videoFilePath,
      duration: duration,
      fileSize: fileSize,
      uploadTime: DateTime.now(),
      tagIds: tagIds,
      thumbnailPath: thumbNailPath,
    );

    // 保存视频
    await _videoProvider.saveVideo(newVideo);
    _uploadingFiles.remove(fileId);

    return {'success': true, 'data': _videoToJson(newVideo)};
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
