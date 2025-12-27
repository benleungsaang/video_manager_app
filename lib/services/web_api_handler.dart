import 'dart:io';
import 'dart:async'; // 导入 Completer
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:video_manager_app/main.dart';
import 'package:video_manager_app/utils/file_utils.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../providers/tag_provider.dart';
import '../providers/video_provider.dart';
import '../repositories/video_repository.dart'; // 添加VideoRepository导入
import '../models/tag.dart';
import '../models/video.dart';
import 'dart:convert';
import '../utils/storage_utils.dart'; // 新增导入

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
  // 通过全局动态获取Provider实例
  WebApiHandler();

  // 动态获取最新的Provider实例（需结合Provider全局访问）
  VideoProvider get _videoProvider =>
      Provider.of<VideoProvider>(navigatorKey.currentContext!, listen: false);
  TagProvider get _tagProvider =>
      Provider.of<TagProvider>(navigatorKey.currentContext!, listen: false);

  // 添加一个单独的Repository实例用于搜索等操作，避免影响VideoProvider状态
  final VideoRepository _repository = VideoRepository();

  final Map<String, UploadingFile> _uploadingFiles = {};
  final Map<String, Completer> _activeOperations = {}; // 追踪活跃操作，便于资源清理

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

    // 为当前操作创建Completer，便于资源追踪和清理
    final operationId =
        '${DateTime.now().millisecondsSinceEpoch}_${action}_${requestId}';
    final completer = Completer();
    _activeOperations[operationId] = completer;

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
          final Tag? tag = await _tagProvider.createTag(params['name'],
              initialVideoCount: 0);
          return tag != null
              ? {'success': true, 'data': _tagToJson(tag)}
              : {'success': false, 'error': '标签已存在'};

        // 删除标签
        case 'deleteTag':
          await _tagProvider.deleteTag(params['id']);
          return {'success': true};

        // 以 ID 获取视频
        case 'getVideoById':
          final String videoId = params['videoId'];
          final Video? video = _videoProvider.getVideoById(videoId);
          if (video != null && video.filePath != null) {
            // 对于Web端，返回文件的相对路径或URL
            return {
              'success': true,
              'data': {'video': video}
            };
          } else {
            return {'success': false, 'error': '视频文件不存在'};
          }

        // 以 ID 获取视频大小
        case 'getVideoSize':
          final String videoId = params['videoId'];
          final Video? video = _videoProvider.getVideoById(videoId);
          if (video != null && video.filePath != null) {
            // 对于Web端，返回文件的相对路径或URL
            return {
              'success': true,
              'data': {'videoSize': video.fileSize}
            };
          } else {
            return {'success': false, 'error': '视频文件不存在'};
          }

                // 视频相关接口
                // 获取视频列表
                case 'getVideos':
                  // 获取所有视频并转换为JSON
                  return {
                    'success': true,
                    'data': _videoProvider.videos.map(_videoToJson).toList()
                  };
                        // 获取最近上传的视频
                        case 'getRecentVideos':
                          final int limit = params['limit'] ?? 5;
                          final List<Video> recentVideos = _videoProvider.getRecentVideos(limit);
                          return {
                            'success': true,
                            'data': recentVideos.map(_videoToJson).toList()
                          };        case 'getVideoUrl':
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
            try {
              final List<int> bytes = await thumbnailFile.readAsBytes();
              final String base64Data = base64Encode(bytes);
              // 统一格式：将数据放在data字段中
              return {
                'success': true,
                'data': {'base64': base64Data}
              };
            } catch (e) {
              print('读取缩略图失败: $e');
              return {'success': false, 'error': '无法读取缩略图文件'};
            }
          } else {
            return {'success': false, 'error': '缩略图不存在'};
          }
        // 搜索视频
        case 'searchVideos':
          final String query = params['query'] ?? '';
          final List<Video> searchResults = await _repository.searchVideosAsync(query);
          return {
            'success': true,
            'data': searchResults.map(_videoToJson).toList()
          };
        case 'updateVideo':
          // 处理视频更新
          final Map<String, dynamic> videoData =
              request['params']['video'] ?? {};
          final String id = videoData['id'];
          final String title = videoData['title'];
          final String? filePath = videoData['filePath'];
          final int? fileSize = videoData['fileSize']; // 假设前端传入文件大小
          final List<String> tagIds =
              List<String>.from(videoData['tagIds'] ?? []); // 标签ID列表
          final String? thumbnailPath = videoData['thumbnailPath'];
          final String uploadTime = videoData['uploadTime'];
          final int? duration = videoData['duration']; // 假设前端传入时长
          final String remark = videoData['remark'] ?? ''; // 备注信息

          // 获取现有视频以获取未更新的字段
          final existingVideo = _videoProvider.getVideoById(id);
          if (existingVideo == null) {
            return {'success': false, 'error': '视频不存在'};
          }

          // 创建更新后的Video对象
          final updatedVideo = Video(
            id: id,
            title: title,
            remark: remark,
            filePath: filePath ?? existingVideo.filePath,
            duration: duration ?? existingVideo.duration,
            fileSize: fileSize ?? existingVideo.fileSize,
            uploadTime: DateTime.parse(uploadTime),
            tagIds: tagIds,
            thumbnailPath: thumbnailPath ?? existingVideo.thumbnailPath,
            transcode: existingVideo.transcode, // 保留现有转码状态
          );

          // 保存视频（这会自动处理标签计数的更新）
          await _videoProvider.saveVideo(updatedVideo);

          return {
            'success': true,
            'data': _videoToJson(updatedVideo), // 返回完整的视频信息
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
          _cleanupUploadFile(fileId); // 使用清理方法
          return {'success': true};
        default:
          return {'success': false, 'error': '未知操作: $action'};
      }
    } catch (e, stackTrace) {
      // 捕获所有异常并返回错误信息，同时记录详细的错误日志
      print('处理请求时发生错误: $e\n堆栈跟踪: $stackTrace');
      return {'success': false, 'error': e.toString()};
    } finally {
      // 确保清理操作完成
      if (!_activeOperations[operationId]!.isCompleted) {
        _activeOperations[operationId]!.complete();
      }
      _activeOperations.remove(operationId);
    }
  }

  // 添加获取视频的方法
  Video? getVideoById(String videoId) {
    return _videoProvider.getVideoById(videoId);
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

    try {
      // 更新总块数
      final uploadFile = _uploadingFiles[fileId]!;
      uploadFile.totalChunks = totalChunks;

      // 通知客户端可以发送二进制数据
      return {'status': 'ready'};
    } catch (e, stackTrace) {
      print('处理二进制块元数据时发生错误: $e\n堆栈跟踪: $stackTrace');
      return {'success': false, 'error': '处理二进制块元数据失败'};
    }
  }

  // 处理二进制数据
  void handleBinaryData({
    required WebSocketChannel channel,
    required String fileId,
    required int chunkIndex,
    required Uint8List data,
    required String requestId,
  }) {
    try {
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
      channel.sink.add(json
          .encode({'id': requestId, 'success': true, 'progress': progress}));
    } catch (e, stackTrace) {
      print('处理二进制数据时发生错误: $e\n堆栈跟踪: $stackTrace');
      try {
        channel.sink.add(json
            .encode({'id': requestId, 'success': false, 'error': '处理二进制数据失败'}));
      } catch (sendError) {
        print('发送错误响应失败: $sendError');
      }
    }
  }

  // 完成二进制上传

  // 转换Tag为JSON格式

  Map<String, dynamic> _tagToJson(Tag tag) {
    return tag.toJson();
  }

  // 转换Video为JSON格式

  Map<String, dynamic> _videoToJson(Video video) {
    return video.toJson();
  }

  // 资源清理方法
  void _cleanupUploadFile(String fileId) {
    // 清理上传文件
    if (_uploadingFiles.containsKey(fileId)) {
      _uploadingFiles.remove(fileId);
    } else {
      // 检查是否有未合并的临时文件
      try {
        final tempDir = StorageUtils.getTempDirectory();
        final tempFile = File(p.join(tempDir, fileId));
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }
      } catch (e) {
        print('清理临时上传文件时出错: $e');
      }
    }
  }

  // 处理二进制上传完成
  Future<Map<String, dynamic>> _handleCompleteBinaryUpload(
      Map<String, dynamic> params) async {
    final String fileId = params['fileId'];

    final String name = params['name'];

    final int duration = params['duration'];

    final int fileSize = params['fileSize'];

    final String remark = params['remark'] ?? '';

    final List<String> tagIds = List<String>.from(params['tagIds'] ?? []);

    // 获取标题（如果没有提供则使用文件名，但去掉扩展名）
    final String title =
        params['title'] ?? name.replaceFirst(RegExp(r'\.[^.]+$'), '');

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
    final videosDir = StorageUtils.getVideosDirectory();

    try {
      await Directory(videosDir).create(recursive: true);

      final videoFilePath = p.join(videosDir,
          'unTransCode_${DateTime.now().millisecondsSinceEpoch}_$name');

      final File videoFile = File(videoFilePath);

      final IOSink sink = videoFile.openWrite();

      // 按顺序写入所有分片
      for (int i = 0; i < uploadingFile.totalChunks; i++) {
        if (uploadingFile.chunks[i] != null) {
          sink.add(uploadingFile.chunks[i]!);
        }
      }

      await sink.close();

      // 生成缩略图
      final thumbNailPath =
          await FileUtils.generateVideoThumbnail(videoFilePath);

      // 创建一个待处理的视频对象，先返回给前端
      final video = Video(
        id: 'video_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        remark: remark,
        filePath: videoFilePath, // 使用临时文件路径
        duration: duration,
        fileSize: fileSize, // 使用上传的文件大小
        uploadTime: DateTime.now(),
        tagIds: tagIds,
        thumbnailPath: thumbNailPath, // 暂时没有缩略图，将在后台生成
      );

      // 保存视频（先保存一个基础版本）
      await _videoProvider.saveVideo(video);

      // 从上传列表中移除（已完成上传部分）
      _uploadingFiles.remove(fileId);

      // 立即返回上传完成响应，不等待压缩操作
      return {'success': true, 'data': _videoToJson(video)};
    } catch (e, stackTrace) {
      print('合并上传文件时发生错误: $e\n堆栈跟踪: $stackTrace');
      // 清理部分写入的文件
      final videosDir = StorageUtils.getVideosDirectory();
      final videoFilePath = p.join(videosDir,
          'unTransCode_${DateTime.now().millisecondsSinceEpoch}_$name');
      final partialFile = File(videoFilePath);
      if (await partialFile.exists()) {
        await partialFile.delete();
      }
      return {'success': false, 'error': '合并上传文件失败: $e'};
    } finally {
      // 确保清理上传文件数据
      _uploadingFiles.remove(fileId);
    }
  }

  /// 清理所有活跃操作和上传文件，释放资源
  Future<void> dispose() async {
    // 取消所有活跃操作
    for (final completer in _activeOperations.values) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _activeOperations.clear();

    // 清理所有未完成的上传文件
    final List<String> fileIds = List.from(_uploadingFiles.keys);
    for (final fileId in fileIds) {
      _cleanupUploadFile(fileId);
    }

    print('WebApiHandler 资源已清理');
  }
}
