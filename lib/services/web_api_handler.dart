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

import '../utils/storage_utils.dart'; // 新增导入

import 'video_compression_service.dart'; // 视频压缩服务

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
        case 'updateVideo':
          // 处理视频更新
          final Map<String, dynamic> params = request['params']['video'] ?? {};
          final int duration = params['duration']; // 假设前端传入视频时长
          final String? filePath = params['filePath'];
          final int? fileSize = params['fileSize']; // 假设前端传入文件大小
          final String id = params['id'];
          final List<String> tagIds =
              List<String>.from(params['tagIds'] ?? []); // 标签ID列表
          final String? thumbnailPath = params['thumbnailPath'];
          final String title = params['title'];
          final String uploadTime = params['uploadTime'];
          final String remark = params['remark'] ?? ''; // 备注信息

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
            duration: duration,
            fileSize: fileSize ?? existingVideo.fileSize,
            uploadTime:
                DateTime.tryParse(uploadTime) ?? existingVideo.uploadTime,
            tagIds: tagIds,
            thumbnailPath: thumbnailPath ?? existingVideo.thumbnailPath,
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
          if (_uploadingFiles.containsKey(fileId)) {
            _uploadingFiles.remove(fileId);
          } else {
            // 检查是否有未合并的临时文件
            final tempDir = StorageUtils.getTempDirectory();
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
      'remark': video.remark
    };
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

    // 获取压缩参数，默认为完全压缩

    final String compressMode = params['compressMode'] ?? 'full';

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

    await Directory(videosDir).create(recursive: true);

    final tempVideoFilePath = p.join(
        videosDir, 'temp_${DateTime.now().millisecondsSinceEpoch}_$name');

    final File videoFile = File(tempVideoFilePath);

    final IOSink sink = videoFile.openWrite();

    // 按顺序写入所有分片

    for (int i = 0; i < uploadingFile.totalChunks; i++) {
      sink.add(uploadingFile.chunks[i]!);
    }

    await sink.close();

    // 创建一个待处理的视频对象，先返回给前端
    final pendingVideo = Video(
      id: 'video_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      remark: remark,
      filePath: tempVideoFilePath, // 使用临时文件路径
      duration: duration,
      fileSize: fileSize, // 使用上传的文件大小
      uploadTime: DateTime.now(),
      tagIds: tagIds,
      thumbnailPath: null, // 暂时没有缩略图，将在后台生成
    );

    // 保存视频（先保存一个基础版本）
    await _videoProvider.saveVideo(pendingVideo);

    // 从上传列表中移除（已完成上传部分）
    _uploadingFiles.remove(fileId);

    // 异步执行压缩和后续处理，不阻塞前端响应
    _processVideoInBackground(pendingVideo, compressMode).then((processedVideo) {
      if (processedVideo != null) {
        // 更新数据库中的视频信息
        _videoProvider.saveVideo(processedVideo).then((_) {
          print('视频后台处理完成: ${processedVideo.title}');
        }).catchError((error) {
          print('保存处理后的视频失败: $error');
        });
      }
    }).catchError((error) {
      print('视频后台处理失败: $error');
      // 即使后台处理失败，上传的文件仍然保留
    });

    // 立即返回上传完成响应，不等待压缩操作
    return {'success': true, 'data': _videoToJson(pendingVideo)};
  }

  // 异步处理视频压缩和生成缩略图等后台任务
  Future<Video?> _processVideoInBackground(Video pendingVideo, String compressMode) async {
    try {
      String finalVideoFilePath = pendingVideo.filePath!;

      // 根据压缩参数处理视频
      if (compressMode == 'full' || compressMode == 'original') {
        // 检查FFmpeg是否可用
        if (await VideoCompressionService.isFFmpegAvailable()) {
          print('开始对视频进行压缩，模式: $compressMode, 路径: $finalVideoFilePath');

          final compressedPath = await VideoCompressionService.compressVideo(
            inputPath: finalVideoFilePath,
            compressionMode: compressMode,
          );

          if (compressedPath != null) {
            // 压缩成功，使用压缩后的文件
            finalVideoFilePath = compressedPath;
            print('视频压缩完成，新文件路径: $compressedPath');
          } else {
            print('视频压缩失败，使用原始文件');
            // 如果压缩失败，确保原始文件仍然存在
            final originalFile = File(finalVideoFilePath);
            if (!await originalFile.exists()) {
              print('原始视频文件不存在或已被删除');
              return null;
            }
          }
        } else {
          print('FFmpeg不可用，跳过视频压缩');
        }
      }

      // 生成缩略图
      final thumbNailPath = await FileUtils.generateVideoThumbnail(finalVideoFilePath);

      // 获取最终文件大小
      final File finalVideoFile = File(finalVideoFilePath);
      final int finalFileSize = await finalVideoFile.length();

      // 创建处理完成的视频对象
      final processedVideo = Video(
        id: pendingVideo.id,
        title: pendingVideo.title,
        remark: pendingVideo.remark,
        filePath: finalVideoFilePath,
        duration: pendingVideo.duration,
        fileSize: finalFileSize,
        uploadTime: pendingVideo.uploadTime,
        tagIds: pendingVideo.tagIds,
        thumbnailPath: thumbNailPath,
      );

      return processedVideo;
    } catch (e) {
      print('后台处理视频时发生错误: $e');
      return null;
    }
  }
}
