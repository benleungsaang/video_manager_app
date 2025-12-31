import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:path/path.dart' as p;
import 'web_api_handler.dart';
import '../utils/storage_utils.dart';
import '../utils/file_utils.dart';

class FileUploadHandler {
  final WebApiHandler _webApiHandler;

  FileUploadHandler(this._webApiHandler);

  // 文件上传管理器 - 用于处理分块上传
  final Map<String, Map<String, dynamic>> _pendingUploads = {};

  // 优化文件上传处理
  Future<Response> handleFileUpload(Request request) async {
    try {
      final contentType = request.headers['content-type'];
      if (contentType == null) {
        return Response.badRequest(
          body: json.encode({'error': '缺少Content-Type'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // 检查是否为分块上传请求
      final userAgent = request.headers['user-agent'] ?? '';
      final isChunkedUpload =
          contentType.contains('application/json'); // 假设分块元数据是JSON
      final isMultipart = contentType.contains('multipart/form-data');

      if (isMultipart) {
        // 检查是否为分块数据上传（包含chunk字段）
        final multipartBoundary =
            RegExp(r'boundary=([^,;]+)').firstMatch(contentType);
        if (multipartBoundary != null) {
          final boundary = multipartBoundary.group(1)!;
          final boundaryBytes = utf8.encode('\r\n--$boundary');
          
          // 从请求中读取原始数据
          final bodyBytes = await request.read().toList();
          final flattenedBytes = <int>[];
          for (final byteList in bodyBytes) {
            flattenedBytes.addAll(byteList);
          }
          final body = Uint8List.fromList(flattenedBytes);

          // 解析multipart数据
          final parts = <Map<String, dynamic>>[];
          var start = 0;
          // 跳过开头的boundary
          final firstBoundary = utf8.encode('--$boundary');
          var pos = _findBytes(body, firstBoundary, start);
          if (pos == -1) {
            return Response.badRequest(
              body: json.encode({'error': '无效的multipart格式'}),
              headers: {'Content-Type': 'application/json'},
            );
          }
          pos += firstBoundary.length;

          while (pos < body.length - 2) {
            // 查找下一部分的开始
            final nextBoundary = _findBytes(body, boundaryBytes, pos);
            if (nextBoundary == -1) {
              // 最后一部分
              final partData =
                  body.sublist(pos, body.length - 2); // -2 for \r\n
              parts.add(_parseMultipartPart(partData));
              break;
            }

            final partData = body.sublist(pos, nextBoundary);
            parts.add(_parseMultipartPart(partData));
            pos = nextBoundary + boundaryBytes.length;

            // 如果遇到结束标记
            if (pos < body.length &&
                body[pos] == 45 &&
                pos + 1 < body.length &&
                body[pos + 1] == 45) {
              // '--' 结束标记
              break;
            }
          }

          // 检查是否是分块上传请求
          bool isChunkUpload = false;
          String? fileId;
          int? chunkIndex;

          for (final part in parts) {
            final headers = part['headers'] as Map<String, String>;
            final contentDisposition = headers['content-disposition'];
            if (contentDisposition != null) {
              final nameMatch =
                  RegExp(r'name="([^"}]+)"').firstMatch(contentDisposition);
              if (nameMatch != null) {
                final fieldName = nameMatch.group(1)!;
                if (fieldName == 'chunk') {
                  isChunkUpload = true;
                } else if (fieldName == 'fileId') {
                  fileId = utf8.decode(part['content'] as Uint8List);
                } else if (fieldName == 'chunkIndex') {
                  chunkIndex =
                      int.tryParse(utf8.decode(part['content'] as Uint8List));
                }
              }
            }
          }

          if (isChunkUpload && fileId != null && chunkIndex != null) {
            // 处理分块上传
            return await _handleUploadChunkMultipart(parts, fileId, chunkIndex);
          }
        }

        // 处理完整文件上传
        return await _handleMultipartUpload(request);
      } else if (isChunkedUpload) {
        // 处理分块上传请求
        final body = await request.readAsString();
        final requestData = json.decode(body);

        if (requestData['action'] == 'initUpload') {
          // 初始化分块上传
          return await _handleInitUpload(requestData);
        } else if (requestData['action'] == 'uploadChunk') {
          // 上传分块 - 从JSON中读取base64数据
          return await _handleUploadChunkJson(requestData);
        } else if (requestData['action'] == 'completeUpload') {
          // 完成分块上传
          return await _handleCompleteUpload(requestData);
        } else if (requestData['action'] == 'cancelUpload') {
          // 取消上传
          return await _handleCancelUpload(requestData);
        }
      } else {
        return Response.badRequest(
          body: json.encode({'error': '不支持的Content-Type'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.badRequest(
        body: json.encode({'error': '无效的请求'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('文件上传失败: $e');
      return Response.badRequest(
        body: json.encode({'error': '上传失败: ${e.toString()}'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 处理完整文件上传 (multipart/form-data)
  Future<Response> _handleMultipartUpload(Request request) async {
    final contentType = request.headers['content-type']!;

    // 从请求中读取原始数据
    final bodyBytes = await request.read().toList();
    final flattenedBytes = <int>[];
    for (final byteList in bodyBytes) {
      flattenedBytes.addAll(byteList);
    }
    final body = Uint8List.fromList(flattenedBytes);

    // 手动解析multipart数据
    final boundaryMatch = RegExp(r'boundary=([^,;]+)').firstMatch(contentType);
    if (boundaryMatch == null) {
      return Response.badRequest(
        body: json.encode({'error': '无法解析boundary'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final boundary = boundaryMatch.group(1)!;
    final boundaryBytes = utf8.encode('\r\n--$boundary');

    // 解析multipart数据
    final parts = <Map<String, dynamic>>[];
    var start = 0;
    // 跳过开头的boundary
    final firstBoundary = utf8.encode('--$boundary');
    var pos = _findBytes(body, firstBoundary, start);
    if (pos == -1) {
      return Response.badRequest(
        body: json.encode({'error': '无效的multipart格式'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    pos += firstBoundary.length;

    while (pos < body.length - 2) {
      // 查找下一部分的开始
      final nextBoundary = _findBytes(body, boundaryBytes, pos);
      if (nextBoundary == -1) {
        // 最后一部分
        final partData = body.sublist(pos, body.length - 2); // -2 for \r\n
        parts.add(_parseMultipartPart(partData));
        break;
      }

      final partData = body.sublist(pos, nextBoundary);
      parts.add(_parseMultipartPart(partData));
      pos = nextBoundary + boundaryBytes.length;

      // 如果遇到结束标记
      if (pos < body.length &&
          body[pos] == 45 &&
          pos + 1 < body.length &&
          body[pos + 1] == 45) {
        // '--' 结束标记
        break;
      }
    }

    // 处理解析出的各部分
    String? videoFileName;
    Uint8List? videoFileData;
    String title = '未命名视频';
    String remark = '';
    int duration = 0;
    List<String> tagIds = [];

    for (final part in parts) {
      final headers = part['headers'] as Map<String, String>;
      final content = part['content'] as Uint8List;

      // 检查Content-Disposition头部
      final contentDisposition = headers['content-disposition'];
      if (contentDisposition != null) {
        final nameMatch =
            RegExp(r'name="([^"}]+)"').firstMatch(contentDisposition);
        if (nameMatch != null) {
          final fieldName = nameMatch.group(1)!;

          if (fieldName == 'video') {
            // 这是视频文件
            final filenameMatch =
                RegExp(r'filename="([^"}]+)"').firstMatch(contentDisposition);
            videoFileName = filenameMatch?.group(1) ?? 'unnamed_video';
            videoFileData = content;
          } else if (fieldName == 'title') {
            title = utf8.decode(content);
          } else if (fieldName == 'remark') {
            remark = utf8.decode(content);
          } else if (fieldName == 'duration') {
            duration = int.tryParse(utf8.decode(content)) ?? 0;
          } else if (fieldName.startsWith('tagIds')) {
            tagIds.add(utf8.decode(content));
          }
        }
      }
    }

    if (videoFileData == null) {
      return Response.badRequest(
        body: json.encode({'error': '未找到视频文件'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // 保存视频到本地存储
    final videosDir = StorageUtils.getVideosDirectory();
    await Directory(videosDir).create(recursive: true);

    final videoFileNameClean =
        'unTransCode_${DateTime.now().millisecondsSinceEpoch}_${videoFileName ?? 'unnamed_video'}';
    final videoFilePath = p.join(videosDir, videoFileNameClean);

    // 写入文件
    final file = File(videoFilePath);
    await file.writeAsBytes(videoFileData);

    // 生成缩略图
    final thumbnailPath = await FileUtils.generateVideoThumbnail(videoFilePath);

    // 准备参数用于创建视频记录
    title =
        title.isNotEmpty ? title : (videoFileName?.split('.').first ?? '未命名视频');

    // 使用WebApiHandler创建视频记录
    final videoData = {
      'id': 'video_${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'remark': remark,
      'filePath': videoFilePath,
      'fileSize': await file.length(),
      'duration': duration,
      'tagIds': tagIds,
      'thumbnailPath': thumbnailPath,
      'uploadTime': DateTime.now().toIso8601String(),
    };

    final video = await _webApiHandler.createVideo(videoData);

    return Response.ok(
      json.encode({'success': true, 'data': video}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // 从multipart/form-data格式处理分块上传
  Future<Response> _handleUploadChunkMultipart(
      List<Map<String, dynamic>> parts, String fileId, int chunkIndex) async {
    try {
      Uint8List? chunkData;

      for (final part in parts) {
        final headers = part['headers'] as Map<String, String>;
        final content = part['content'] as Uint8List;

        // 检查Content-Disposition头部
        final contentDisposition = headers['content-disposition'];
        if (contentDisposition != null) {
          final nameMatch =
              RegExp(r'name="([^"}]+)"').firstMatch(contentDisposition);
          if (nameMatch != null) {
            final fieldName = nameMatch.group(1)!;

            if (fieldName == 'chunk') {
              chunkData = content; // 二进制分块数据
            }
          }
        }
      }

      if (chunkData == null) {
        return Response.badRequest(
          body: json.encode({'error': '缺少分块数据'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (!_pendingUploads.containsKey(fileId)) {
        return Response.badRequest(
          body: json.encode({'error': '上传会话不存在'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final uploadInfo = _pendingUploads[fileId]!;
      final chunkFile =
          File(p.join(uploadInfo['uploadDir'], 'chunk_$chunkIndex'));
      await chunkFile.writeAsBytes(chunkData);

      // 更新已接收大小
      uploadInfo['receivedChunks'][chunkIndex] = chunkData;
      uploadInfo['receivedSize'] += chunkData.length;

      final progress =
          (uploadInfo['receivedSize'] / uploadInfo['totalSize'] * 100).round();

      return Response.ok(
        json.encode(
            {'success': true, 'progress': progress, 'message': '分块上传成功'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('上传分块失败: $e');
      return Response.internalServerError(
        body: json.encode({'error': '上传分块失败: ${e.toString()}'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 从JSON中处理分块上传（base64格式）
  Future<Response> _handleUploadChunkJson(Map<String, dynamic> data) async {
    try {
      final fileId = data['fileId'] as String;
      final chunkIndex = data['chunkIndex'] as int;
      final chunkData = base64.decode(data['chunkData'] as String);

      if (!_pendingUploads.containsKey(fileId)) {
        return Response.badRequest(
          body: json.encode({'error': '上传会话不存在'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final uploadInfo = _pendingUploads[fileId]!;
      final chunkFile =
          File(p.join(uploadInfo['uploadDir'], 'chunk_$chunkIndex'));
      await chunkFile.writeAsBytes(chunkData);

      // 更新已接收大小
      uploadInfo['receivedChunks'][chunkIndex] = chunkData;
      uploadInfo['receivedSize'] += chunkData.length;

      final progress =
          (uploadInfo['receivedSize'] / uploadInfo['totalSize'] * 100).round();

      return Response.ok(
        json.encode(
            {'success': true, 'progress': progress, 'message': '分块上传成功'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('上传分块失败: $e');
      return Response.internalServerError(
        body: json.encode({'error': '上传分块失败: ${e.toString()}'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 完成分块上传
  Future<Response> _handleCompleteUpload(Map<String, dynamic> data) async {
    String? uploadDirPath; // 用于在异常处理中清理临时文件

    try {
      final fileId = data['fileId'] as String;
      final title = data['title'] as String? ?? '未命名视频';
      final remark = data['remark'] as String? ?? '';
      final duration = data['duration'] as int? ?? 0;
      final tagIds = List<String>.from(data['tagIds'] ?? <String>[]);
      final totalSize = data['totalSize'] as int? ?? 0; // 修复错误，使用totalSize而不是fileSize

      if (!_pendingUploads.containsKey(fileId)) {
        return Response.badRequest(
          body: json.encode({'error': '上传会话不存在'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final uploadInfo = _pendingUploads[fileId]!;
      uploadDirPath = uploadInfo['uploadDir'] as String?;

      if (uploadDirPath == null) {
        return Response.internalServerError(
          body: json.encode({'error': '上传目录路径未设置'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final uploadDir = Directory(uploadDirPath);

      // 验证所有分块是否都已上传
      final totalChunks = uploadInfo['totalChunks'] as int;
      for (int i = 0; i < totalChunks; i++) {
        final chunkFile = File(p.join(uploadDir.path, 'chunk_$i'));
        if (!await chunkFile.exists()) {
          return Response.badRequest(
            body: json.encode({'error': '分块文件缺失: chunk_$i'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // 合并分块文件
      final videosDir = StorageUtils.getVideosDirectory();
      await Directory(videosDir).create(recursive: true);

      final videoFileNameClean =
          'unTransCode_${DateTime.now().millisecondsSinceEpoch}_${uploadInfo['fileName']}';
      final videoFilePath = p.join(videosDir, videoFileNameClean);

      final outputFile = File(videoFilePath);
      final sink = outputFile.openWrite();

      for (int i = 0; i < totalChunks; i++) {
        final chunkFile = File(p.join(uploadDir.path, 'chunk_$i'));
        final chunkData = await chunkFile.readAsBytes();
        sink.add(chunkData);

        // 删除已合并的分块文件
        await chunkFile.delete();
      }

      await sink.close();

      // 生成缩略图 - 只有在完整视频文件准备好后才生成
      final thumbnailPath =
          await FileUtils.generateVideoThumbnail(videoFilePath);

      // 使用WebApiHandler创建视频记录
      final videoData = {
        'id': 'video_${DateTime.now().millisecondsSinceEpoch}',
        'title': title,
        'remark': remark,
        'filePath': videoFilePath,
        'fileSize': await outputFile.length(),
        'duration': duration,
        'tagIds': tagIds,
        'thumbnailPath': thumbnailPath,
        'uploadTime': DateTime.now().toIso8601String(),
      };

      final video = await _webApiHandler.createVideo(videoData);

      // 清理临时目录
      if (await uploadDir.exists()) {
        await uploadDir.delete(recursive: true);
      }
      _pendingUploads.remove(fileId);

      return Response.ok(
        json.encode({'success': true, 'data': video, 'message': '文件上传完成'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      // 在异常情况下清理临时文件
      if (uploadDirPath != null) {
        try {
          final uploadDir = Directory(uploadDirPath);
          if (await uploadDir.exists()) {
            await uploadDir.delete(recursive: true);
          }
        } catch (cleanupError) {
          print('清理临时文件失败: $cleanupError');
        }
      }

      // 从内存中移除上传记录
      final fileId = data['fileId'] as String?;
      if (fileId != null && _pendingUploads.containsKey(fileId)) {
        _pendingUploads.remove(fileId);
      }

      print('完成上传失败: $e');
      return Response.internalServerError(
        body: json.encode({'error': '完成上传失败: ${e.toString()}'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 初始化分块上传
  Future<Response> _handleInitUpload(Map<String, dynamic> data) async {
    try {
      final fileId = data['fileId'] as String;
      final fileName = data['fileName'] as String;
      final totalSize = data['totalSize'] as int;
      final totalChunks = data['totalChunks'] as int;
      final userAgent = data['userAgent'] as String? ?? '';

      // 根据浏览器类型和文件大小确定块大小
      final chunkSize = _getOptimalChunkSize(totalSize, userAgent);

      // 创建临时上传目录
      final tempDir = StorageUtils.getTempDirectory();
      final uploadDir = Directory(p.join(tempDir, 'uploads', fileId));
      await uploadDir.create(recursive: true);

      // 记录上传信息
      _pendingUploads[fileId] = {
        'fileName': fileName,
        'totalSize': totalSize,
        'totalChunks': totalChunks,
        'receivedChunks': <int, Uint8List>{},
        'uploadDir': uploadDir.path,
        'receivedSize': 0,
        'chunkSize': chunkSize,
      };

      return Response.ok(
        json.encode(
            {'success': true, 'chunkSize': chunkSize, 'message': '上传初始化成功'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'error': '初始化上传失败: ${e.toString()}'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 根据浏览器类型和文件大小确定最优分块大小
  int _getOptimalChunkSize(int totalSize, String userAgent) {
    // 对于Safari浏览器使用更小的块
    if (userAgent.toLowerCase().contains('safari') &&
        !userAgent.toLowerCase().contains('chrome')) {
      if (totalSize > 100 * 1024 * 1024) {
        // > 100MB
        return 2 * 1024 * 1024; // 2MB
      } else if (totalSize > 10 * 1024 * 1024) {
        // > 10MB
        return 1 * 1024 * 1024; // 1MB
      } else {
        return 512 * 1024; // 512KB
      }
    } else {
      // 对于其他浏览器（如Chrome）
      if (totalSize > 500 * 1024 * 1024) {
        // > 500MB
        return 10 * 1024 * 1024; // 10MB
      } else if (totalSize > 100 * 1024 * 1024) {
        // > 100MB
        return 5 * 1024 * 1024; // 5MB
      } else if (totalSize > 10 * 1024 * 1024) {
        // > 10MB
        return 2 * 1024 * 1024; // 2MB
      } else {
        return 1024 * 1024; // 1MB
      }
    }
  }

  // 辅助方法：查找字节数组中的子序列
  int _findBytes(Uint8List data, List<int> pattern, int startIndex) {
    for (int i = startIndex; i <= data.length - pattern.length; i++) {
      bool found = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) {
        return i;
      }
    }
    return -1;
  }

  // 辅助方法：解析multipart部分
  Map<String, dynamic> _parseMultipartPart(Uint8List data) {
    // 查找头部和内容的分界（\r\n\r\n）
    int headerEnd = -1;
    for (int i = 0; i < data.length - 3; i++) {
      if (data[i] == 13 &&
          data[i + 1] == 10 &&
          data[i + 2] == 13 &&
          data[i + 3] == 10) {
        headerEnd = i + 4;
        break;
      }
    }

    final headers = <String, String>{};
    Uint8List content;

    if (headerEnd != -1) {
      // 解析头部
      final headerData =
          utf8.decode(data.sublist(0, headerEnd - 2)); // -2 to remove \r\n
      final headerLines = headerData.split('\r\n');

      for (final line in headerLines) {
        if (line.contains(':')) {
          final parts = line.split(':');
          headers[parts[0].trim().toLowerCase()] =
              parts.sublist(1).join(':').trim();
        }
      }

      content = data.sublist(headerEnd);
    } else {
      content = data;
    }

    // 移除内容前后的\r\n
    int start = 0;
    while (start < content.length &&
        (content[start] == 13 || content[start] == 10)) {
      start++;
    }

    int end = content.length;
    while (end > start && (content[end - 1] == 13 || content[end - 1] == 10)) {
      end--;
    }

    return {
      'headers': headers,
      'content': content.sublist(start, end),
    };
  }

  // 处理取消上传请求
  Future<Response> _handleCancelUpload(Map<String, dynamic> data) async {
    try {
      final fileId = data['fileId'] as String;

      if (_pendingUploads.containsKey(fileId)) {
        final uploadInfo = _pendingUploads[fileId]!;
        final uploadDir = Directory(uploadInfo['uploadDir']);

        // 删除临时目录及所有分块文件
        if (await uploadDir.exists()) {
          await uploadDir.delete(recursive: true);
        }
        _pendingUploads.remove(fileId);
      }

      return Response.ok(
        json.encode({'success': true, 'message': '上传已取消'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'error': '取消上传失败: ${e.toString()}'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
