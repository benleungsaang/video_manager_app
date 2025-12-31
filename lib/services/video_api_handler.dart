import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'web_api_handler.dart';
import '../utils/storage_utils.dart';
import '../utils/file_utils.dart';

class VideoApiHandler {
  final WebApiHandler _webApiHandler;

  VideoApiHandler(this._webApiHandler);

  // 获取所有视频
  Future<Response> handleGetVideos(Request request) async {
    try {
      final videos = await _webApiHandler.getAllVideos();
      return Response.ok(
        json.encode({'success': true, 'data': videos}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取最近上传的视频
  Future<Response> handleGetRecentVideos(Request request, String limit) async {
    try {
      final limitNum = int.tryParse(limit) ?? 5;
      final videos = await _webApiHandler.getRecentVideos(limitNum);
      return Response.ok(
        json.encode({'success': true, 'data': videos}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取单个视频
  Future<Response> handleGetVideo(Request request, String id) async {
    try {
      final video = await _webApiHandler.getVideoById(id);
      if (video != null) {
        return Response.ok(
          json.encode({'success': true, 'data': video}),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          json.encode({'success': false, 'error': '视频不存在'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 创建视频
  Future<Response> handleCreateVideo(Request request) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      final video = await _webApiHandler.createVideo(params);

      return Response.ok(
        json.encode({'success': true, 'data': video}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 更新视频
  Future<Response> handleUpdateVideo(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      final updatedVideo = await _webApiHandler.updateVideo(id, params);

      return Response.ok(
        json.encode({'success': true, 'data': updatedVideo}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 删除视频
  Future<Response> handleDeleteVideo(Request request, String id) async {
    try {
      await _webApiHandler.deleteVideo(id);

      return Response.ok(
        json.encode({'success': true}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取所有标签
  Future<Response> handleGetTags(Request request) async {
    try {
      final tags = await _webApiHandler.getAllTags();
      return Response.ok(
        json.encode({'success': true, 'data': tags}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 创建标签
  Future<Response> handleCreateTag(Request request) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      final tag = await _webApiHandler.createTag(params['name']);

      return Response.ok(
        json.encode({'success': true, 'data': tag}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 删除标签
  Future<Response> handleDeleteTag(Request request, String id) async {
    try {
      await _webApiHandler.deleteTag(id);

      return Response.ok(
        json.encode({'success': true}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 搜索视频
  Future<Response> handleSearch(Request request) async {
    try {
      final query = request.url.queryParameters['q'] ?? '';
      final results = await _webApiHandler.searchVideos(query);
      return Response.ok(
        json.encode({'success': true, 'data': results}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取缩略图
  Future<Response> handleGetThumbnail(Request request, String id) async {
    try {
      final thumbnail = await _webApiHandler.getThumbnail(id);
      if (thumbnail != null) {
        return Response.ok(
          json.encode({'success': true, 'data': thumbnail}),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          json.encode({'success': false, 'error': '缩略图不存在'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取视频URL
  Future<Response> handleGetVideoUrl(Request request, String id) async {
    try {
      final video = _webApiHandler.getVideoById(id);
      if (video != null && video.filePath != null) {
        return Response.ok(
          json.encode({
            'success': true,
            'data': {'videoUrl': video.filePath}
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          json.encode({'success': false, 'error': '视频文件不存在'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取视频大小
  Future<Response> handleGetVideoSize(Request request, String id) async {
    try {
      final video = _webApiHandler.getVideoById(id);
      if (video != null) {
        return Response.ok(
          json.encode({
            'success': true,
            'data': {'videoSize': video.fileSize}
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          json.encode({'success': false, 'error': '视频不存在'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}