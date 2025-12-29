import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:convert' as convert;
import 'dart:convert' show base64;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:flutter/foundation.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'web_api_handler.dart';

import '../utils/storage_utils.dart'; // 新增导入
import '../utils/file_utils.dart'; // 新增导入
import 'database_export_service.dart'; // 新增导入
import '../repositories/video_repository.dart'; // 新增导入
import '../repositories/tag_repository.dart'; // 新增导入
import '../models/machine_part.dart'; // 新增导入
import '../models/part.dart'; // 新增导入
import '../models/temp_fee.dart'; // 新增导入
import '../models/temp_factor.dart'; // 新增导入

// import '../providers/tag_provider.dart';

// import '../providers/video_provider.dart';

// import 'package:provider/provider.dart';

// import 'package:video_manager_app/main.dart';

// import 'package:video_manager_app/models/video.dart';

class ServerService with ChangeNotifier {
  bool _isRunning = false;
  int _port = 8080;
  String? _localIp;
  HttpServer? _server;

  bool get isRunning => _isRunning;
  int get port => _port;
  String? get localIp => _localIp;
  // 移除WebSocket连接相关属性，因为不再使用WebSocket
  int get connectionCount => 0; // 现在不追踪WebSocket连接
  Map<String, String> get clientDevices => {}; // 现在不追踪WebSocket连接

  // 移除WebSocket相关的消息日志和客户端详情

  late WebApiHandler _webApiHandler;
  // bool _isInitialized = false; // 新增初始化标记
  // bool get isInitialized => _isInitialized;

  // 数据版本时间戳 - 追踪机器部件、部件、费用和系数的最后修改时间
  int _lastMachinePartsUpdate = DateTime.now().millisecondsSinceEpoch;
  int _lastPartsUpdate = DateTime.now().millisecondsSinceEpoch;
  int _lastFeesUpdate = DateTime.now().millisecondsSinceEpoch;
  int _lastFactorsUpdate = DateTime.now().millisecondsSinceEpoch;

  int get lastMachinePartsUpdate => _lastMachinePartsUpdate;
  int get lastPartsUpdate => _lastPartsUpdate;
  int get lastFeesUpdate => _lastFeesUpdate;
  int get lastFactorsUpdate => _lastFactorsUpdate;

  // 更新机器部件最后修改时间
  void updateMachinePartsTimestamp() {
    _lastMachinePartsUpdate = DateTime.now().millisecondsSinceEpoch;
    print(
        '机器部件数据版本已更新: ${DateTime.fromMillisecondsSinceEpoch(_lastMachinePartsUpdate)}');
  }

  // 更新部件最后修改时间
  void updatePartsTimestamp() {
    _lastPartsUpdate = DateTime.now().millisecondsSinceEpoch;
    print(
        '部件数据版本已更新: ${DateTime.fromMillisecondsSinceEpoch(_lastPartsUpdate)}');
  }

  // 更新费用最后修改时间
  void updateFeesTimestamp() {
    _lastFeesUpdate = DateTime.now().millisecondsSinceEpoch;
    print(
        '费用数据版本已更新: ${DateTime.fromMillisecondsSinceEpoch(_lastFeesUpdate)}');
  }

  // 更新系数最后修改时间
  void updateFactorsTimestamp() {
    _lastFactorsUpdate = DateTime.now().millisecondsSinceEpoch;
    print(
        '系数数据版本已更新: ${DateTime.fromMillisecondsSinceEpoch(_lastFactorsUpdate)}');
  }

  // void initApiHandler(TagProvider tagProvider, VideoProvider videoProvider) {
  //   _webApiHandler = WebApiHandler(
  //     tagProvider: tagProvider,
  //     videoProvider: videoProvider,
  //   );
  //   _isInitialized = true;
  // }

  // VideoProvider get _videoProvider =>
  //     Provider.of<VideoProvider>(navigatorKey.currentContext!, listen: false);

  // 移除WebSocket相关的客户端管理方法

  Future<void> _getLocalIp() async {
    final info = NetworkInfo();
    _localIp = await info.getWifiIP();
    notifyListeners();
  }

  Future<void> clearWebCache() async {
    final tempDir = StorageUtils.getTempDirectory();
    final webAssetsDir = Directory(p.join(tempDir, 'web'));

    if (await webAssetsDir.exists()) {
      await webAssetsDir.delete(recursive: true);
      print('Web资源缓存已清除');
    } else {
      print('没有可清除的Web资源缓存');
    }
    notifyListeners();
  }

  Future<void> _copyWebAssets() async {
    final tempDir = StorageUtils.getTempDirectory();
    final webAssetsDir = Directory(p.join(tempDir, 'web'));
    await webAssetsDir.create(recursive: true);

    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = await assetManifest.listAssets();

      final webAssetPaths = allAssets
          .where((path) =>
              path.startsWith('build/web/') || path.startsWith('packages/'))
          .toList();

      if (webAssetPaths.isEmpty) {
        throw Exception('未找到build/web目录下的资源，请检查pubspec.yaml配置');
      }

      print('开始复制Web资源（共 ${webAssetPaths.length} 个文件）...');

      for (final assetPath in webAssetPaths) {
        String relativePath;
        if (assetPath.startsWith('build/web/')) {
          relativePath = p.relative(assetPath, from: 'build/web');
        } else if (assetPath.startsWith('packages/')) {
          relativePath = 'assets/${assetPath}';
        } else {
          continue;
        }

        final targetFile = File(p.join(webAssetsDir.path, relativePath));

        print('复制文件: $relativePath');

        await targetFile.parent.create(recursive: true);

        final byteData = await rootBundle.load(assetPath);
        await targetFile.writeAsBytes(byteData.buffer.asUint8List());
      }

      print('Web资源复制完成，共 ${webAssetPaths.length} 个文件');
    } catch (e) {
      print('复制Web资源失败：$e');
      if (await webAssetsDir.exists()) {
        await webAssetsDir.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<void> startServer({int? customPort}) async {
    if (_isRunning) return;

    // // 新增检查：确保初始化完成
    // if (!_isInitialized) {
    //   throw Exception("startServer => ServerService未初始化，请先调用initApiHandler");
    // }
    // _webApiHandler = WebApiHandler(
    //   tagProvider:
    //       navigatorKey.currentState!.context.read<TagProvider>(),
    //   videoProvider:
    //       navigatorKey.currentState!.context.read<VideoProvider>(),
    // );
    _webApiHandler = WebApiHandler();

    if (customPort != null) {
      if (customPort < 1024 || customPort > 65535) {
        throw Exception("端口必须在1024-65535范围内");
      }
      _port = customPort;
    }

    await _getLocalIp();
    final router = _createRouter();

    // 1. 基础日志中间件
    // final logMiddleware = logRequests(
    //   logger: (message, isError) {
    //     if (isError) {
    //       print('[错误 ERROR] $message');
    //     } else {
    //       print('[正常 INFO] $message');
    //     }
    //   },
    // );

    // 2. CORS跨域中间件
    final corsMiddleware = corsHeaders(
      headers: {
        ACCESS_CONTROL_ALLOW_ORIGIN: '*',
        ACCESS_CONTROL_ALLOW_METHODS: 'GET, POST, PUT, DELETE, OPTIONS',
        ACCESS_CONTROL_ALLOW_HEADERS: 'Range, Content-Type, Origin',
        ACCESS_CONTROL_EXPOSE_HEADERS:
            'Content-Length, Accept-Ranges, Content-Type', // 显式声明暴露的头
        ACCESS_CONTROL_MAX_AGE: '86400', // 24小时缓存预检请求
      },
    );

    // final corsMiddleware = (Handler handler) {
    //   return (Request request) async {
    //     // Skip CORS for non-HTTP requests (e.g., WebSocket)
    //     if (request.method == 'OPTIONS' ||
    //         request.method == 'GET' ||
    //         request.method == 'HEAD') {
    //       final response = await handler(request);
    //       return response.change(headers: {
    //         'Access-Control-Allow-Origin': '*',
    //         'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
    //         'Access-Control-Allow-Headers': 'Range, Content-Type, Origin',
    //         'Access-Control-Expose-Headers':
    //             'Content-Length, Accept-Ranges, Content-Type',
    //       });
    //     }
    //     return handler(request);
    //   };
    // };

    // 3. 错误处理中间件
    final errorHandlerMiddleware = createMiddleware(
      errorHandler: (Object error, StackTrace stackTrace) {
        print('服务器错误: $error\n$stackTrace');
        return Response.internalServerError(
          body: json.encode({
            'error': '服务器内部错误',
            'message': kReleaseMode ? null : error.toString(),
          }),
          headers: {'Content-Type': 'application/json'},
        );
      },
    );

    // 4. 请求超时中间件
    // final timeoutMiddleware = createMiddleware(
    //   requestHandler: (Request request, PipelineHandler next) {
    //     return next(request).timeout(
    //       const Duration(seconds: 30),
    //       onTimeout: () => Response(
    //         HttpStatus.gatewayTimeout,
    //         body: json.encode({'error': '请求超时'}),
    //         headers: {'Content-Type': 'application/json'},
    //       ),
    //     );
    //   },
    // );

    // 组合中间件
    final middlewarePipeline = Pipeline()
        // .addMiddleware(logMiddleware)
        .addMiddleware(corsMiddleware)
        .addMiddleware(errorHandlerMiddleware);
    // .addMiddleware(timeoutMiddleware);

    _server = await serve(
      middlewarePipeline.addHandler(router.call),
      InternetAddress.anyIPv4,
      _port,
    );

    _isRunning = true;
    notifyListeners();
    print('服务器启动于 http://${_localIp}:${_port}');
  }

  Router _createRouter() {
    final router = Router();

    // HTTP API端点 - 视频相关
    router.get('/api/videos', _handleGetVideos);
    router.get('/api/videos/<limit>', _handleGetRecentVideos);
    router.get('/api/videos/<id>', _handleGetVideo);
    router.post('/api/videos', _handleCreateVideo);
    router.put('/api/videos/<id>', _handleUpdateVideo);
    router.delete('/api/videos/<id>', _handleDeleteVideo);

    // HTTP API端点 - 标签相关
    router.get('/api/tags', _handleGetTags);
    router.post('/api/tags', _handleCreateTag);
    router.delete('/api/tags/<id>', _handleDeleteTag);

    // HTTP API端点 - 文件上传
    router.post('/api/upload', _handleFileUpload);
    router.delete('/api/upload/<fileId>', _handleCancelUpload);

    // HTTP API端点 - 搜索
    router.get('/api/search', _handleSearch);

    // HTTP API端点 - 缩略图
    router.get('/api/thumbnails/<id>', _handleGetThumbnail);

    // HTTP API端点 - 价格计算器相关
    router.get('/api/machine-parts', _handleGetMachineParts);
    router.post('/api/machine-parts', _handleCreateMachinePart);
    router.put('/api/machine-parts/<id>', _handleUpdateMachinePart);
    router.delete('/api/machine-parts/<id>', _handleDeleteMachinePart);

    // HTTP API端点 - 视频信息
    router.get('/api/videos/<id>/url', _handleGetVideoUrl);
    router.get('/api/videos/<id>/size', _handleGetVideoSize);

    // HTTP API端点 - 机器部件相关（价格计算器）
    router.get('/api/machine-parts', _handleGetMachineParts);
    router.post('/api/machine-parts', _handleCreateMachinePart);
    router.put('/api/machine-parts/<id>', _handleUpdateMachinePart);
    router.delete('/api/machine-parts/<id>', _handleDeleteMachinePart);

    // HTTP API端点 - 部件相关（价格计算器）
    router.get('/api/parts', _handleGetParts);
    router.post('/api/parts', _handleCreatePart);
    router.put('/api/parts/<id>', _handleUpdatePart);
    router.delete('/api/parts/<id>', _handleDeletePart);

    // HTTP API端点 - 统计信息（价格计算器）
    router.get('/api/parts-stats', _handleGetPartsStats);

    // HTTP API端点 - 费用相关（价格计算器）
    router.get('/api/temp-fees', _handleGetTempFees);
    router.post('/api/temp-fees', _handleCreateTempFee);
    router.put('/api/temp-fees/<id>', _handleUpdateTempFee);
    router.delete('/api/temp-fees/<id>', _handleDeleteTempFee);
    
    // HTTP API端点 - 系数相关（价格计算器）
    router.get('/api/temp-factors', _handleGetTempFactors);
    router.post('/api/temp-factors', _handleCreateTempFactor);
    router.put('/api/temp-factors/<id>', _handleUpdateTempFactor);
    router.delete('/api/temp-factors/<id>', _handleDeleteTempFactor);

    // HTTP API端点 - 常用项目相关（价格计算器）
    router.get('/api/top-used/parts', _handleGetTopUsedParts);
    router.get('/api/top-used/fees', _handleGetTopUsedFees);
    router.get('/api/top-used/factors', _handleGetTopUsedFactors);

    // HTTP API端点 - 数据更新检查（价格计算器）
    router.get('/api/check-data-update', _handleCheckDataUpdate);

    // // 文件上传接口
    router.post('/upload', _handleFileUpload);

    // 视频流处理路由 - 支持Range和HEAD请求
    router.get('/videoStream/<videoId>', _handleVideoStream);

    router.options('/<path|.*>', (Request request) {
      return Response.ok('', headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
        'Access-Control-Allow-Headers': 'Range, Content-Type, Origin',
        'Access-Control-Expose-Headers': 'Content-Length, Accept-Ranges',
        'Access-Control-Max-Age': '86400', // 预检结果缓存24小时
        'Content-Length': '0', // OPTIONS请求无响应体
      });
    });

    // 配置静态资源服务
    router.all('/<path|.*>', _createStaticHandler());
    return router;
  }

  // 处理视频流式传输（支持断点续传和Range请求）
  Future<Response> _handleVideoStream(Request request, String videoId) async {
    try {
      // print('=' * 50);
      print('播放视频 ID=> ${videoId}');
      // print('=' * 50);
      // print('收到请求的完整 Header：');
      // print('=' * 50);
      // print(request.headers); // 直接打印 Headers 对象（会自动展开所有键值）

      final video = _webApiHandler.getVideoById(videoId);
      if (video == null || video.filePath == null) {
        return Response.notFound(json.encode({'error': '视频不存在'}));
      }
      final file = File(video.filePath!);
      if (!await file.exists()) {
        return Response.notFound(json.encode({'error': '视频文件不存在'}));
      }

      // 2. 处理HEAD请求（仅返回头信息）
      if (request.method == 'HEAD') {
        final _fileSize = video.fileSize.toString();
        print('fileSize inside: ${_fileSize}');
        // 根据文件扩展名确定Content-Type
        final fileExtension = file.path.split('.').last.toLowerCase();
        final contentType = _getVideoContentType(fileExtension);
        final headers = {
          'Content-Length': _fileSize,
          'Content-Type': contentType,
          'Accept-Ranges': 'bytes',
          'Cache-Control': 'public, max-age=3600',
          // 跨域配置
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
          // 补充暴露更多必要的头信息
          'Access-Control-Expose-Headers':
              'Content-Length, Accept-Ranges, Content-Type',
          // 允许前端读取的请求头
          'Access-Control-Allow-Headers': 'Range, Content-Type',
        };
        print('headers: ${headers}');
        return Response(200, headers: headers);
      }

      // 3. 处理GET请求和Range
      final fileLength = await file.length();
      // 从请求头中获取 Range（格式如：bytes=1024-2047 或 bytes=512-）
      final rangeHeader = request.headers['Range'];
      int start = 0; // 默认从文件开头开始
      int end = fileLength - 1; // 默认到文件末尾结束

      // 解析 Range 头（正则匹配字节范围）
      if (rangeHeader != null) {
        final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
        if (match != null) {
          start = int.parse(match.group(1)!); // 提取起始字节
          // 提取结束字节（若未指定，保持默认到文件末尾）
          if (match.group(2) != null && match.group(2)!.isNotEmpty) {
            end = int.parse(match.group(2)!);
          }
        }
      }

// 校验 Range 合法性（避免无效范围请求）
      if (start > end || start >= fileLength) {
        return Response(416, // 416 状态码：Range Not Satisfiable（范围不合法）
            headers: {
              'Content-Range': 'bytes */$fileLength',
              'Content-Length': '0',
            });
      }

// 调整 end 不超过文件长度（防止客户端请求超出文件大小）
      end = end > fileLength - 1 ? fileLength - 1 : end;
      final contentLength = end - start + 1;

      // 根据文件扩展名确定Content-Type
      final fileExtension = file.path.split('.').last.toLowerCase();
      final contentType = _getVideoContentType(fileExtension);

      // 打开文件为随机访问流（支持跳转到指定位置读取，避免加载整个文件）
      final raf = await file.open(mode: FileMode.read);
      await raf.setPosition(start); // 跳转到 Range 指定的起始位置

      // 创建 StreamController 手动控制流的生命周期（修复 Stream 无 whenComplete 的问题）
      final streamController = StreamController<List<int>>();

      // 读取指定长度的文件数据（contentLength 为当前分块的字节数）
      raf.read(contentLength).then((data) {
        streamController.add(data); // 向流中添加数据（发送给客户端）
        streamController.close(); // 数据发送完成，关闭控制器
      }).catchError((error) {
        print('文件读取错误: $error');
        raf.close(); // 出错时关闭文件，避免资源泄漏
        streamController.addError(error); // 向客户端返回错误
        streamController.close();
      }).whenComplete(() {
        raf.close(); // 无论成功失败，最终都关闭文件句柄
      });

// 监听流的错误事件，兜底关闭文件句柄
      final stream = streamController.stream.handleError((error) {
        print('流处理错误: $error');
        raf.close();
      });

      // 5. 返回响应
      return Response(
        rangeHeader != null ? 206 : 200, // 206：Partial Content（分块响应）；200：完整响应
        body: stream, // 响应体为流式数据（避免内存溢出）
        headers: {
          'Content-Type': contentType, // 使用根据文件扩展名确定的类型
          'Content-Length': contentLength.toString(), // 当前分块的字节数
          'Content-Range': 'bytes $start-$end/$fileLength', // 告知客户端当前分块的范围和总长度
          'Accept-Ranges': 'bytes', // 再次声明支持 Range 请求
          'Cache-Control': 'public, max-age=3600', // 分块数据缓存 1 小时
        },
      );
    } catch (e) {
      print('视频流处理错误: $e');
      return Response.internalServerError(
          body: json.encode({'error': '视频流处理失败'}));
    }
  }

  // 提取静态资源处理器
  Handler _createStaticHandler() {
    return (Request request) async {
      final tempDir = StorageUtils.getTempDirectory();
      final webAssetsDir = Directory('${tempDir}/web');
      // print('处理静态资源请求: ${request.url.path}');
      // print('静态资源目录: ${webAssetsDir.path}');

      if (!await webAssetsDir.exists()) {
        try {
          await _copyWebAssets();
        } catch (e) {
          return Response.internalServerError(
            body: json.encode({'error': '静态资源加载失败: ${e.toString()}'}),
          );
        }
      }

      return createStaticHandler(
        webAssetsDir.path,
        defaultDocument: 'entry.html',
        listDirectories: false,
      )(request);
    };
  }

  // 文件上传管理器 - 用于处理分块上传
  final Map<String, Map<String, dynamic>> _pendingUploads = {};

  // 优化文件上传处理
  Future<Response> _handleFileUpload(Request request) async {
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
          // 从请求中读取原始数据
          final bodyBytes = await request.read().toList();
          final flattenedBytes = <int>[];
          for (final byteList in bodyBytes) {
            flattenedBytes.addAll(byteList);
          }
          final body = Uint8List.fromList(flattenedBytes);

          // 解析multipart数据
          final boundary = multipartBoundary.group(1)!;
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
                  RegExp(r'name="([^"]+)"').firstMatch(contentDisposition);
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
              RegExp(r'name="([^"]+)"').firstMatch(contentDisposition);
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
            RegExp(r'name="([^"]+)"').firstMatch(contentDisposition);
        if (nameMatch != null) {
          final fieldName = nameMatch.group(1)!;

          if (fieldName == 'video') {
            // 这是视频文件
            final filenameMatch =
                RegExp(r'filename="([^"]+)"').firstMatch(contentDisposition);
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
      final fileSize = data['fileSize'] as int? ?? 0;

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

  Future<void> stopServer() async {
    if (!_isRunning) return;

    // 发送服务器关闭消息 - 现在使用HTTP API，无需广播

    // 使用连接池清理所有连接 - 现在已移除WebSocket连接池

    await _server?.close(force: true);
    _server = null;

    _isRunning = false;
    notifyListeners();
  }

  // 广播消息给所有连接的客户端
  // void _broadcastMessage(dynamic message) {
  //   for (final client in _connectedClients.values) {
  //     try {
  //       if (client.closeCode == null) {
  //         continue;
  //       }
  //       client.sink.add(message);
  //     } catch (e) {
  //       print('广播消息失败: $e');
  //     }
  //   }
  // }

  // 从User-Agent判断设备类型
  String _getDeviceType(String? userAgent) {
    try {
      if (userAgent == null) return '未知设备';
      if (userAgent.contains('Mobile')) {
        return '手机';
      } else if (userAgent.contains('Tablet')) {
        return '平板';
      } else {
        return '电脑';
      }
    } catch (e) {
      print('获取设备类型失败: $e');
      return '设备类型解析错误';
    }
  }

  void setPort(int newPort) {
    if (newPort < 1024 || newPort > 65535) {
      throw Exception("端口必须在1024-65535范围内");
    }

    _port = newPort;

    notifyListeners();
  }

  // 导出数据库

  Future<String> exportDatabase() async {
    // 导入需要的类

    final videoRepo = VideoRepository();

    final tagRepo = TagRepository();

    final exportService = DatabaseExportService(videoRepo, tagRepo);

    try {
      return await exportService.exportDatabaseToFile();
    } catch (e) {
      print('导出数据库失败: $e');

      rethrow;
    }
  }

  // 导入数据库

  Future<void> importDatabase(String filePath) async {
    // 导入需要的类

    final videoRepo = VideoRepository();

    final tagRepo = TagRepository();

    final exportService = DatabaseExportService(videoRepo, tagRepo);

    try {
      await exportService.importDatabaseFromFile(filePath);

      notifyListeners(); // 通知UI更新
    } catch (e) {
      print('导入数据库失败: $e');

      rethrow;
    }
  }

  // 根据文件扩展名获取视频的Content-Type
  String _getVideoContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'ogg':
        return 'video/ogg';
      case 'avi':
        return 'video/x-msvideo';
      case 'wmv':
        return 'video/x-ms-wmv';
      case 'flv':
        return 'video/x-flv';
      case 'm4v':
        return 'video/x-m4v';
      case '3gp':
        return 'video/3gpp';
      case 'mkv':
        return 'video/x-matroska';
      default:
        return 'application/octet-stream'; // 默认类型
    }
  }

  // HTTP API端点处理方法

  // 获取所有视频
  Future<Response> _handleGetVideos(Request request) async {
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
  Future<Response> _handleGetRecentVideos(Request request, String limit) async {
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
  Future<Response> _handleGetVideo(Request request, String id) async {
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
  Future<Response> _handleCreateVideo(Request request) async {
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
  Future<Response> _handleUpdateVideo(Request request, String id) async {
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
  Future<Response> _handleDeleteVideo(Request request, String id) async {
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
  Future<Response> _handleGetTags(Request request) async {
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
  Future<Response> _handleCreateTag(Request request) async {
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
  Future<Response> _handleDeleteTag(Request request, String id) async {
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
  Future<Response> _handleSearch(Request request) async {
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
  Future<Response> _handleGetThumbnail(Request request, String id) async {
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
  Future<Response> _handleGetVideoUrl(Request request, String id) async {
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
  Future<Response> _handleGetVideoSize(Request request, String id) async {
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

  // 处理取消上传请求（HTTP API）
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

  // 价格计算器相关API端点处理方法

  // 获取所有机器部件
  Future<Response> _handleGetMachineParts(Request request) async {
    try {
      // 从Hive数据库中获取机器部件数据
      final machinePartsBox = Hive.box<MachinePart>('machine_parts');
      final machineParts = machinePartsBox.values.toList();

      // 将MachinePart对象转换为Map格式
      final parts = <Map<String, dynamic>>[];
      for (final part in machineParts) {
        // 首先获取基本属性
        final partMap = <String, dynamic>{
          'Model': part.model,
          'OriginalModel': part.originalModel,
          'OriginalPrice': part.originalPrice,
          'ShowPrice': part.showPrice,
          'image': part.image,
          'addedCount': part.addedCount,
        };

        // 添加otherProperties中的所有属性
        part.otherProperties.forEach((key, value) {
          partMap[key] = value;
        });

        parts.add(partMap);
      }

      return Response.ok(
        json.encode({
          'success': true, 
          'data': parts,
          'timestamp': _lastMachinePartsUpdate  // 返回当前机器部件数据的时间戳
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取机器部件失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 创建机器部件
  Future<Response> _handleCreateMachinePart(Request request) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      // 需要实现实际的机器部件创建逻辑
      final machinePartsBox = Hive.box<MachinePart>('machine_parts');
      
      // 创建MachinePart对象
      final newPart = MachinePart(
        model: params['Model']?.toString() ?? params['model']?.toString() ?? '',
        originalModel: params['OriginalModel']?.toString() ?? '',
        originalPrice: (params['OriginalPrice'] as num?)?.toDouble() ?? 0.0,
        showPrice: (params['ShowPrice'] as num?)?.toDouble() ?? 0.0,
        image: params['image']?.toString() ?? '',
        addedCount: params['addedCount']?.toInt() ?? 0,
        otherProperties: _extractOtherProperties(params, {}),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'system',
        updatedBy: 'system',
      );
      
      // 保存到Hive数据库
      await machinePartsBox.add(newPart);
      
      // 更新机器部件数据版本时间戳
      updateMachinePartsTimestamp();
      
      // 返回成功响应，包括部件数据和时间戳信息
      return Response.ok(
        json.encode({
          'success': true, 
          'data': newPart.toJson(),
          'timestamp': _lastMachinePartsUpdate  // 返回当前机器部件数据的时间戳
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 更新机器部件

  Future<Response> _handleUpdateMachinePart(Request request, String id) async {
    try {
      final body = await request.readAsString();

      final params = json.decode(body);

      // 检查是否是incrementAddedCount操作

      if (params['action'] == 'incrementAddedCount' &&
          params['model'] != null) {
        final model = params['model'] as String;

        final machinePartsBox = Hive.box<MachinePart>('machine_parts');

        // 遍历box中的所有项目找到匹配的model

        for (final key in machinePartsBox.keys) {
          final part = machinePartsBox.get(key)!;

          if (part.model == model) {
            // 创建更新后的MachinePart对象，增加addedCount

            final updatedPart = MachinePart(
              model: part.model,

              originalModel: part.originalModel,

              originalPrice: part.originalPrice,

              showPrice: part.showPrice,

              image: part.image,

              addedCount: part.addedCount + 1, // 增加被添加次数

              otherProperties: part.otherProperties,

              createdAt: part.createdAt, // 保持原始创建时间

              updatedAt: DateTime.now(), // 更新最后修改时间

              createdBy: part.createdBy, // 保持原始创建人

              updatedBy: 'system', // 使用系统作为更新人
            );

            // 更新到Hive数据库

            await machinePartsBox.put(key, updatedPart);

            // 更新机器部件数据版本时间戳
            updateMachinePartsTimestamp();
            
            return Response.ok(
              json.encode({
                'success': true, 
                'message': 'addedCount已更新',
                'timestamp': _lastMachinePartsUpdate  // 返回当前机器部件数据的时间戳
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }

        // 如果没有找到对应的机器部件

        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的机器部件'}),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        // 处理普通的更新操作

        // 从URL参数获取ID（模型名称）

        final model = id; // URL中的id参数实际上是模型名称

        final machinePartsBox = Hive.box<MachinePart>('machine_parts');

        // 遍历box中的所有项目找到匹配的model

        for (final key in machinePartsBox.keys) {
          final part = machinePartsBox.get(key)!;

          if (part.model == model) {
            // 注意：如果只是addedCount变化，不更新时间戳；其他字段变化则更新时间戳

            bool isOnlyAddedCountChange =
                _isOnlyAddedCountChanged(part, params);

            // 根据参数创建更新后的MachinePart对象

            final updatedPart = MachinePart(
              model: params['Model'] ?? part.model,

              originalModel: params['OriginalModel'] ?? part.originalModel,

              originalPrice: (params['OriginalPrice'] as num)?.toDouble() ??
                  part.originalPrice,

              showPrice:
                  (params['ShowPrice'] as num)?.toDouble() ?? part.showPrice,

              image: params['image'] ?? part.image,

              addedCount: params['addedCount'] ?? part.addedCount,

              otherProperties:
                  _extractOtherProperties(params, part.otherProperties),

              createdAt: part.createdAt, // 保持原始创建时间

              updatedAt: DateTime.now(), // 更新最后修改时间

              createdBy: part.createdBy, // 保持原始创建人

              updatedBy: params['updatedBy'] ?? 'system', // 使用指定的更新人或默认为system
            );

            // 更新到Hive数据库

            await machinePartsBox.put(key, updatedPart);

            // 如果不是仅addedCount的变化，则更新数据版本时间戳

            if (!isOnlyAddedCountChange) {
              updateMachinePartsTimestamp();

              print('机器部件数据已更新: ${updatedPart.model}');
            } else {
              print('仅addedCount更新，不更新数据版本: ${updatedPart.model}');
            }

            // 返回更新后的数据

            final partMap = <String, dynamic>{
              'Model': updatedPart.model,
              'OriginalModel': updatedPart.originalModel,
              'OriginalPrice': updatedPart.originalPrice,
              'ShowPrice': updatedPart.showPrice,
              'image': updatedPart.image,
              'addedCount': updatedPart.addedCount,
              'createdAt': updatedPart.createdAt.toIso8601String(),
              'updatedAt': updatedPart.updatedAt.toIso8601String(),
              'createdBy': updatedPart.createdBy,
              'updatedBy': updatedPart.updatedBy,
            };

            updatedPart.otherProperties.forEach((key, value) {
              partMap[key] = value;
            });

            return Response.ok(
              json.encode({
                'success': true, 
                'data': partMap,
                'timestamp': _lastMachinePartsUpdate  // 返回当前机器部件数据的时间戳
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }

        // 如果没有找到对应的机器部件

        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的机器部件'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('更新机器部件失败: $e');

      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 删除机器部件
  Future<Response> _handleDeleteMachinePart(Request request, String id) async {
    try {
      // 这里应该调用_priceCalculatorProvider.deleteMachinePart()
      // 临时返回成功，但更新数据版本时间戳
      updateMachinePartsTimestamp();

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

  // 获取部件统计信息
  Future<Response> _handleGetPartsStats(Request request) async {
    try {
      // 从Hive数据库中获取机器部件和部件的数量
      final machinePartsBox = Hive.box<MachinePart>('machine_parts');
      final partsBox = Hive.box<Part>('temp_parts');

      final machinePartsCount = machinePartsBox.length;
      final partsCount = partsBox.length;

      return Response.ok(
        json.encode({
          'success': true,
          'data': {
            'machinePartsCount': machinePartsCount,
            'partsCount': partsCount,
          }
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取部件统计失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 检查数据是否有更新
  Future<Response> _handleCheckDataUpdate(Request request) async {
    try {
      // 获取查询参数（客户端上次更新时间）
      final queryParams = request.url.queryParameters;
      final lastUpdateStr = queryParams['lastUpdate'];

      // 使用服务器维护的数据版本时间戳
      final lastMachinePartsUpdate = _lastMachinePartsUpdate;
      final lastPartsUpdate = _lastPartsUpdate;
      final lastFeesUpdate = _lastFeesUpdate;
      final lastFactorsUpdate = _lastFactorsUpdate;

      bool hasUpdates = false;
      if (lastUpdateStr != null) {
        final lastUpdate = int.tryParse(lastUpdateStr) ?? 0;
        hasUpdates =
            lastMachinePartsUpdate > lastUpdate || 
            lastPartsUpdate > lastUpdate ||
            lastFeesUpdate > lastUpdate ||
            lastFactorsUpdate > lastUpdate;
      } else {
        hasUpdates = true; // 如果没有提供上次更新时间，则认为有更新
      }

      return Response.ok(
        json.encode({
          'success': true,
          'hasUpdates': hasUpdates,
          'lastMachinePartsUpdate': lastMachinePartsUpdate,
          'lastPartsUpdate': lastPartsUpdate,
          'lastFeesUpdate': lastFeesUpdate,
          'lastFactorsUpdate': lastFactorsUpdate,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('检查数据更新失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取所有部件
  Future<Response> _handleGetParts(Request request) async {
    try {
      // 从Hive数据库中获取部件数据
      final partsBox = Hive.box<Part>('temp_parts');
      final partsData = partsBox.values.toList();

      // 将Part对象转换为Map格式
      final parts = <Map<String, dynamic>>[];
      for (final part in partsData) {
        parts.add({
          'id': part.id,
          'model': part.model,
          'price': part.price,
          'remark': part.remark,
          'addedCount': part.addedCount,
        });
      }

      return Response.ok(
        json.encode({
          'success': true, 
          'data': parts,
          'timestamp': _lastPartsUpdate  // 返回当前部件数据的时间戳
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取部件失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 创建部件
  Future<Response> _handleCreatePart(Request request) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);
      
      // 从Hive数据库获取部件
      final partsBox = Hive.box<Part>('temp_parts');
      
      final model = params['model']?.toString() ?? '';
      final name = params['name']?.toString() ?? ''; // 保留name参数用于兼容性
      final price = (params['price'] as num?)?.toDouble() ?? (params['defaultPrice'] as num?)?.toDouble() ?? 0.0; // 兼容旧字段名
      final remark = params['remark']?.toString() ?? '';
      final addedCount = params['addedCount']?.toInt() ?? 1; // 默认为1，表示被添加1次
      
      // 检查是否已存在相同型号的部件，如果是则更新而不是创建新实例
      Part? existingPart = null;
      int? existingPartKey;  // 使用int类型，因为Hive的key通常是int
      
      // 遍历box中的所有项目查找匹配的model
      for (final key in partsBox.keys) {
        final part = partsBox.get(key)!;
        if (part.model == model) {
          existingPart = part;
          existingPartKey = key as int; // Hive的key是int类型
          break;
        }
      }
      
      Part resultPart;
      
      if (existingPart != null && existingPartKey != null) {
        // 更新现有部件，增加addedCount
        resultPart = Part(
          id: existingPart.id,
          model: model,
          price: price != 0.0 ? price : existingPart.price,
          remark: remark.isNotEmpty ? remark : existingPart.remark,
          addedCount: existingPart.addedCount + 1,  // 增加被添加次数（而不是使用传入的参数）
        );
        
        // 更新到Hive数据库
        await partsBox.put(existingPartKey, resultPart);
      } else {
        // 创建新部件
        final id = 'part_${DateTime.now().millisecondsSinceEpoch}_${model.isEmpty ? 'unknown' : model}';
        
        resultPart = Part(
          id: id,
          model: model,
          price: price,
          remark: remark,
          addedCount: addedCount,
        );
        
        // 保存到Hive数据库
        await partsBox.add(resultPart);
      }
      
      // 更新部件数据版本时间戳
      updatePartsTimestamp();
      
      // 返回成功响应，包括部件数据和时间戳信息
      return Response.ok(
        json.encode({
          'success': true, 
          'data': resultPart.toJson(),
          'timestamp': _lastPartsUpdate  // 返回当前部件数据的时间戳
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('创建部件失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 更新部件
  Future<Response> _handleUpdatePart(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      // 从Hive数据库获取部件
      final partsBox = Hive.box<Part>('temp_parts');
      
      // 检查是否是incrementAddedCount操作
      if (params['action'] == 'incrementAddedCount' &&
          params['model'] != null) {
        final model = params['model'] as String;

        // 遍历box中的所有项目找到匹配的model
        for (final key in partsBox.keys) {
          final part = partsBox.get(key)!;

          if (part.model == model) {
            // 创建更新后的Part对象，增加addedCount
            final updatedPart = Part(
              id: part.id,
              model: part.model,
              price: part.price,
              remark: part.remark,
              addedCount: part.addedCount + 1, // 增加被添加次数
            );

            // 更新到Hive数据库
            await partsBox.put(key, updatedPart);

            // 更新部件数据版本时间戳
            updatePartsTimestamp();
            
            print('部件使用次数已更新: ${updatedPart.model}, 次数: ${updatedPart.addedCount}');

            return Response.ok(
              json.encode({
                'success': true,
                'data': updatedPart.toJson(),
                'timestamp': _lastPartsUpdate // 返回当前部件数据的时间戳
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }

        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的部件'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // 遍历box中的所有项目找到匹配的id
      for (final key in partsBox.keys) {
        final part = partsBox.get(key)!;
        
        if (part.id == id) {
          // 创建更新后的Part对象
          final updatedPart = Part(
            id: part.id,
            model: params['model'] ?? part.model,
            price: (params['price'] as num?)?.toDouble() ?? (params['defaultPrice'] as num?)?.toDouble() ?? part.price, // 兼容旧字段名
            remark: params['remark'] ?? part.remark,
            addedCount: params['addedCount'] ?? part.addedCount,
          );
          
          // 更新到Hive数据库
          await partsBox.put(key, updatedPart);
          
          // 更新部件数据版本时间戳
          updatePartsTimestamp();
          
          return Response.ok(
            json.encode({
              'success': true, 
              'data': updatedPart.toJson(),
              'timestamp': _lastPartsUpdate  // 返回当前部件数据的时间戳
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }
      
      // 如果没有找到对应的部件
      return Response.notFound(
        json.encode({'success': false, 'error': '未找到对应的部件'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('更新部件失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 删除部件
  Future<Response> _handleDeletePart(Request request, String id) async {
    try {
      // 从Hive数据库删除部件
      final partsBox = Hive.box<Part>('temp_parts');
      
      // 遍历box中的所有项目找到匹配的id
      bool found = false;
      for (final key in partsBox.keys) {
        final part = partsBox.get(key)!;
        
        if (part.id == id) {
          await partsBox.delete(key);
          found = true;
          break;
        }
      }
      
      if (found) {
        // 更新部件数据版本时间戳
        updatePartsTimestamp();
        
        return Response.ok(
          json.encode({
            'success': true,
            'timestamp': _lastPartsUpdate  // 返回当前部件数据的时间戳
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的部件'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('删除部件失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取最常用的部件
  Future<Response> _handleGetTopUsedParts(Request request) async {
    try {
      final box = Hive.box<Part>('temp_parts');
      final parts = box.values.toList();

      // 按被添加次数排序并取前5个
      parts.sort((a, b) => b.addedCount.compareTo(a.addedCount));
      final topParts = parts.take(5).toList();

      final partsData = <Map<String, dynamic>>[];
      for (final part in topParts) {
        final partMap = <String, dynamic>{};
        partMap['id'] = part.id;
        partMap['model'] = part.model;
        partMap['price'] = part.price;
        partMap['remark'] = part.remark;
        partMap['addedCount'] = part.addedCount;
        partsData.add(partMap);
      }

      return Response.ok(
        json.encode({'success': true, 'data': partsData}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取最常用部件失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

    // 获取最常用的费用

    Future<Response> _handleGetTopUsedFees(Request request) async {

      try {

        // 从Hive数据库中获取临时费用数据

        final box = Hive.box<TempFee>('temp_fees');

        final fees = box.values.toList();

  

        // 按被添加次数排序并取前5个

        fees.sort((a, b) => b.addedCount.compareTo(a.addedCount));

        final topFees = fees.take(5).toList();

  

        final feesData = <Map<String, dynamic>>[];

        for (final fee in topFees) {

          final feeMap = <String, dynamic>{};

          feeMap['name'] = fee.name;

          feeMap['value'] = fee.value;

          feeMap['addedCount'] = fee.addedCount;

          feesData.add(feeMap);

        }

  

        return Response.ok(

          json.encode({

            'success': true, 

            'data': feesData,

            'timestamp': _lastPartsUpdate  // 使用parts的时间戳，因为费用也是价格计算器的一部分

          }),

          headers: {'Content-Type': 'application/json'},

        );

      } catch (e) {

        print('获取最常用费用失败: $e');

        return Response.internalServerError(

          body: json.encode({'success': false, 'error': e.toString()}),

          headers: {'Content-Type': 'application/json'},

        );

      }

    }

  // 获取最常用的系数
  Future<Response> _handleGetTopUsedFactors(Request request) async {
    try {
      // 从Hive数据库中获取临时系数数据
      final box = Hive.box<TempFactor>('temp_factors');
      final factors = box.values.toList();

      // 按被添加次数排序并取前5个
      factors.sort((a, b) => b.addedCount.compareTo(a.addedCount));
      final topFactors = factors.take(5).toList();

      final factorsData = <Map<String, dynamic>>[];
      for (final factor in topFactors) {
        final factorMap = <String, dynamic>{};
        factorMap['name'] = factor.name;
        factorMap['value'] = factor.value;
        factorMap['addedCount'] = factor.addedCount;
        factorsData.add(factorMap);
      }

      return Response.ok(
        json.encode({
          'success': true, 
          'data': factorsData,
          'timestamp': _lastPartsUpdate  // 使用parts的时间戳，因为系数也是价格计算器的一部分
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取最常用系数失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 检查是否仅仅是addedCount字段发生了变化
  bool _isOnlyAddedCountChanged(MachinePart part, Map<String, dynamic> params) {
    // 检查除了addedCount之外的其他字段是否发生变化
    if ((params['Model'] != null && params['Model'] != part.model) ||
        (params['OriginalModel'] != null &&
            params['OriginalModel'] != part.originalModel) ||
        (params['OriginalPrice'] != null &&
            (params['OriginalPrice'] as num).toDouble() !=
                part.originalPrice) ||
        (params['ShowPrice'] != null &&
            (params['ShowPrice'] as num).toDouble() != part.showPrice) ||
        (params['image'] != null && params['image'] != part.image) ||
        (params['createdAt'] != null &&
            params['createdAt'] != part.createdAt.toIso8601String()) ||
        (params['updatedAt'] != null &&
            params['updatedAt'] != part.updatedAt.toIso8601String()) ||
        (params['createdBy'] != null &&
            params['createdBy'] != part.createdBy) ||
        (params['updatedBy'] != null &&
            params['updatedBy'] != part.updatedBy)) {
      // 检查otherProperties中的字段是否发生变化
      for (final key in params.keys) {
        if (![
          'Model',
          'OriginalModel',
          'OriginalPrice',
          'ShowPrice',
          'image',
          'addedCount',
          'createdAt',
          'updatedAt',
          'createdBy',
          'updatedBy',
          'action'
        ].contains(key)) {
          if (part.otherProperties.containsKey(key) &&
              part.otherProperties[key] != params[key]) {
            return false; // 发现otherProperties中的字段变化
          } else if (!part.otherProperties.containsKey(key) &&
              params[key] != null) {
            return false; // 发现新增的otherProperties字段
          }
        }
      }
      return false; // 有其他字段变化
    }

    // 检查otherProperties的长度是否变化
    int paramsOtherPropsCount = 0;
    for (final key in params.keys) {
      if (![
        'Model',
        'OriginalModel',
        'OriginalPrice',
        'ShowPrice',
        'image',
        'addedCount',
        'createdAt',
        'updatedAt',
        'createdBy',
        'updatedBy',
        'action'
      ].contains(key)) {
        paramsOtherPropsCount++;
      }
    }

    if (part.otherProperties.length != paramsOtherPropsCount) {
      return false; // otherProperties的长度变化
    }

    return true; // 只有addedCount变化或没有变化
  }

  // 检查费用是否仅仅是addedCount字段发生了变化
  bool _isOnlyAddedCountChangedForFee(TempFee fee, Map<String, dynamic> params) {
    // 检查除了addedCount之外的其他字段是否发生变化
    if ((params['name'] != null && params['name'] != fee.name) ||
        (params['Model'] != null && params['Model'] != fee.name) ||
        (params['model'] != null && params['model'] != fee.name) ||
        (params['value'] != null && 
            (params['value'] as num).toDouble() != fee.value) ||
        (params['defaultAmount'] != null && 
            (params['defaultAmount'] as num).toDouble() != fee.value) ||
        (params['price'] != null && 
            (params['price'] as num).toDouble() != fee.value)) {
      return false; // 有其他字段变化
    }
    return true; // 只有addedCount变化或没有变化
  }

  // 检查系数是否仅仅是addedCount字段发生了变化
  bool _isOnlyAddedCountChangedForFactor(TempFactor factor, Map<String, dynamic> params) {
    // 检查除了addedCount之外的其他字段是否发生变化
    if ((params['name'] != null && params['name'] != factor.name) ||
        (params['Model'] != null && params['Model'] != factor.name) ||
        (params['model'] != null && params['model'] != factor.name) ||
        (params['value'] != null && 
            (params['value'] as num).toDouble() != factor.value) ||
        (params['defaultValue'] != null && 
            (params['defaultValue'] as num).toDouble() != factor.value) ||
        (params['price'] != null && 
            (params['price'] as num).toDouble() != factor.value)) {
      return false; // 有其他字段变化
    }
    return true; // 只有addedCount变化或没有变化
  }

  // 从参数中提取otherProperties
  Map<String, String> _extractOtherProperties(Map<String, dynamic> params,
      Map<String, String> existingOtherProperties) {
    final Map<String, String> otherProperties =
        Map.from(existingOtherProperties);

    // 添加或更新参数中提供的其他属性
    for (final key in params.keys) {
      if (![
        'Model',
        'OriginalModel',
        'OriginalPrice',
        'ShowPrice',
        'image',
        'addedCount',
        'createdAt',
        'updatedAt',
        'createdBy',
        'updatedBy',
        'action'
      ].contains(key)) {
        otherProperties[key] = params[key]?.toString() ?? '';
      }
    }

    return otherProperties;
  }
  
  // 获取费用
  Future<Response> _handleGetTempFees(Request request) async {
    try {
      final feesBox = Hive.box<TempFee>('temp_fees');
      final fees = feesBox.values.toList();

      final feesData = <Map<String, dynamic>>[];
      for (final fee in fees) {
        feesData.add({
          'name': fee.name,
          'value': fee.value,
          'addedCount': fee.addedCount,
        });
      }

      return Response.ok(
        json.encode({
          'success': true, 
          'data': feesData,
          'timestamp': _lastPartsUpdate  // 使用parts的时间戳
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取费用失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

      // 创建费用
      Future<Response> _handleCreateTempFee(Request request) async {
        try {
          final body = await request.readAsString();
          final params = json.decode(body);
    
          final feesBox = Hive.box<TempFee>('temp_fees');
          
          final name = params['name']?.toString() ?? params['Model']?.toString() ?? params['model']?.toString() ?? '';
          final value = (params['value'] as num?)?.toDouble() ?? (params['defaultAmount'] as num?)?.toDouble() ?? (params['price'] as num?)?.toDouble() ?? 0.0;
          final addedCount = params['addedCount']?.toInt() ?? params['usageCount']?.toInt() ?? 1; // 默认为1次添加
          final action = params['action']?.toString() ?? ''; // 操作类型
          
          // 检查是否已存在相同名称的费用，如果是则更新而不是创建新实例
          TempFee? existingFee = null;
          int? existingFeeKey;  // 使用int类型，因为Hive的key通常是int
          
          // 遍历box中的所有项目查找匹配的name
          for (final key in feesBox.keys) {
            final fee = feesBox.get(key)!;
            if (fee.name == name) {
              existingFee = fee;
              existingFeeKey = key as int; // Hive的key是int类型
              break;
            }
          }
          
          TempFee resultFee;
          
          if (existingFee != null && existingFeeKey != null) {
            // 更新现有费用，增加addedCount
            resultFee = TempFee(
              name: name,
              value: value != 0.0 ? value : existingFee.value,
              addedCount: existingFee.addedCount + 1,  // 增加被添加次数（而不是使用传入的参数）
            );
            
            // 更新到Hive数据库
            await feesBox.put(existingFeeKey, resultFee);
          } else {
            // 创建新费用
            resultFee = TempFee(
              name: name,
              value: value,
              addedCount: addedCount,
            );
            
            // 保存到Hive数据库
            await feesBox.add(resultFee);
          }
          
          // 更新费用数据版本时间戳
          updateFeesTimestamp();
          
          // 返回成功响应，包括费用数据和时间戳信息
          return Response.ok(
            json.encode({
              'success': true, 
              'data': resultFee.toJson(),
              'timestamp': _lastFeesUpdate,  // 返回当前费用数据的时间戳
              'action': action  // 返回操作类型
            }),
            headers: {'Content-Type': 'application/json'},
          );
    } catch (e) {
      print('创建费用失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 更新费用
  Future<Response> _handleUpdateTempFee(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      final feesBox = Hive.box<TempFee>('temp_fees');
      
      // 检查是否是incrementAddedCount操作
      if (params['action'] == 'incrementAddedCount' &&
          params['name'] != null) {
        final name = params['name'] as String;

        // 在Hive中，TempFee没有ID，所以我们需要通过name来匹配
        for (final key in feesBox.keys) {
          final fee = feesBox.get(key)!;

          if (fee.name == name) {
            // 创建更新后的TempFee对象，增加addedCount
            final updatedFee = TempFee(
              name: fee.name,
              value: fee.value,
              addedCount: fee.addedCount + 1, // 增加被添加次数
            );

            // 更新到Hive数据库
            await feesBox.put(key, updatedFee);

            // 更新费用数据版本时间戳
            updateFeesTimestamp();
            
            print('费用使用次数已更新: ${updatedFee.name}, 次数: ${updatedFee.addedCount}');

            return Response.ok(
              json.encode({
                'success': true,
                'data': updatedFee.toJson(),
                'timestamp': _lastFeesUpdate // 返回当前费用数据的时间戳
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }

        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的费用'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // 在Hive中，TempFee没有ID，所以我们需要通过name来匹配
      // 这里我们假设URL参数id实际上是name
      for (final key in feesBox.keys) {
        final fee = feesBox.get(key)!;
        
        // 检查name是否匹配（兼容多种可能的字段名）
        if (fee.name == id || 
            fee.name == params['name']?.toString() || 
            fee.name == params['Model']?.toString()) {
          final updatedFee = TempFee(
            name: params['name'] ?? params['Model'] ?? fee.name,
            value: (params['value'] as num?)?.toDouble() ?? (params['defaultAmount'] as num?)?.toDouble() ?? (params['price'] as num?)?.toDouble() ?? fee.value,
            addedCount: params['addedCount'] ?? params['usageCount'] ?? fee.addedCount,
          );
          
          await feesBox.put(key, updatedFee);
          
          // 检查是否是仅addedCount字段的变化
          bool isOnlyAddedCountChange = _isOnlyAddedCountChangedForFee(fee, params);
          
          // 如果不是仅addedCount的变化，则更新数据版本时间戳
          if (!isOnlyAddedCountChange) {
            updateFeesTimestamp();
            print('费用数据版本已更新（非addedCount字段变化）: ${updatedFee.name}');
          } else {
            print('仅addedCount更新，不更新费用数据版本: ${updatedFee.name}');
          }
          
          return Response.ok(
            json.encode({
              'success': true, 
              'data': updatedFee.toJson(),
              'timestamp': _lastFeesUpdate  // 返回当前费用数据的时间戳
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }
      
      return Response.notFound(
        json.encode({'success': false, 'error': '未找到对应的费用'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('更新费用失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 删除费用
  Future<Response> _handleDeleteTempFee(Request request, String id) async {
    try {
      final feesBox = Hive.box<TempFee>('temp_fees');
      
      bool found = false;
      for (final key in feesBox.keys) {
        final fee = feesBox.get(key)!;
        
        // 检查name是否匹配
        if (fee.name == id || 
            fee.name == Uri.decodeComponent(id)) {  // 解码URL参数
          await feesBox.delete(key);
          found = true;
          break;
        }
      }
      
      if (found) {
        // 更新费用数据版本时间戳
        updateFeesTimestamp();
        
        return Response.ok(
          json.encode({
            'success': true,
            'timestamp': _lastFeesUpdate  // 返回当前费用数据的时间戳
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的费用'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('删除费用失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取系数
  Future<Response> _handleGetTempFactors(Request request) async {
    try {
      final factorsBox = Hive.box<TempFactor>('temp_factors');
      final factors = factorsBox.values.toList();

      final factorsData = <Map<String, dynamic>>[];
      for (final factor in factors) {
        factorsData.add({
          'name': factor.name,
          'value': factor.value,
          'addedCount': factor.addedCount,
        });
      }

      return Response.ok(
        json.encode({
          'success': true, 
          'data': factorsData,
          'timestamp': _lastPartsUpdate  // 使用parts的时间戳
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取系数失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

      // 创建系数
      Future<Response> _handleCreateTempFactor(Request request) async {
        try {
          final body = await request.readAsString();
          final params = json.decode(body);
    
          final factorsBox = Hive.box<TempFactor>('temp_factors');
          
          final name = params['name']?.toString() ?? params['Model']?.toString() ?? params['model']?.toString() ?? '';
          final value = (params['value'] as num?)?.toDouble() ?? (params['defaultValue'] as num?)?.toDouble() ?? (params['price'] as num?)?.toDouble() ?? 0.0;
          final addedCount = params['addedCount']?.toInt() ?? params['usageCount']?.toInt() ?? 1; // 默认为1次添加
          final action = params['action']?.toString() ?? ''; // 操作类型
          
          // 检查是否已存在相同名称的系数，如果是则更新而不是创建新实例
          TempFactor? existingFactor = null;
          int? existingFactorKey;  // 使用int类型，因为Hive的key通常是int
          
          // 遍历box中的所有项目查找匹配的name
          for (final key in factorsBox.keys) {
            final factor = factorsBox.get(key)!;
            if (factor.name == name) {
              existingFactor = factor;
              existingFactorKey = key as int; // Hive的key是int类型
              break;
            }
          }
          
          TempFactor resultFactor;
          
          if (existingFactor != null && existingFactorKey != null) {
            // 更新现有系数，增加addedCount
            resultFactor = TempFactor(
              name: name,
              value: value != 0.0 ? value : existingFactor.value,
              addedCount: existingFactor.addedCount + 1,  // 增加被添加次数（而不是使用传入的参数）
            );
            
            // 更新到Hive数据库
            await factorsBox.put(existingFactorKey, resultFactor);
          } else {
            // 创建新系数
            resultFactor = TempFactor(
              name: name,
              value: value,
              addedCount: addedCount,
            );
            
            // 保存到Hive数据库
            await factorsBox.add(resultFactor);
          }
          
          // 更新系数数据版本时间戳
          updateFactorsTimestamp();
          
          // 返回成功响应，包括系数数据和时间戳信息
          return Response.ok(
            json.encode({
              'success': true, 
              'data': resultFactor.toJson(),
              'timestamp': _lastFactorsUpdate,  // 返回当前系数数据的时间戳
              'action': action  // 返回操作类型
            }),
            headers: {'Content-Type': 'application/json'},
          );
    } catch (e) {
      print('创建系数失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 更新系数
  Future<Response> _handleUpdateTempFactor(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      final factorsBox = Hive.box<TempFactor>('temp_factors');
      
      // 检查是否是incrementAddedCount操作
      if (params['action'] == 'incrementAddedCount' &&
          params['name'] != null) {
        final name = params['name'] as String;

        // 在Hive中，TempFactor没有ID，所以我们需要通过name来匹配
        for (final key in factorsBox.keys) {
          final factor = factorsBox.get(key)!;

          if (factor.name == name) {
            // 创建更新后的TempFactor对象，增加addedCount
            final updatedFactor = TempFactor(
              name: factor.name,
              value: factor.value,
              addedCount: factor.addedCount + 1, // 增加被添加次数
            );

            // 更新到Hive数据库
            await factorsBox.put(key, updatedFactor);

            // 更新系数数据版本时间戳
            updateFactorsTimestamp();
            
            print('系数使用次数已更新: ${updatedFactor.name}, 次数: ${updatedFactor.addedCount}');

            return Response.ok(
              json.encode({
                'success': true,
                'data': updatedFactor.toJson(),
                'timestamp': _lastFactorsUpdate // 返回当前系数数据的时间戳
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }

        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的系数'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // 在Hive中，TempFactor没有ID，所以我们需要通过name来匹配
      for (final key in factorsBox.keys) {
        final factor = factorsBox.get(key)!;
        
        // 检查name是否匹配（兼容多种可能的字段名）
        if (factor.name == id || 
            factor.name == params['name']?.toString() || 
            factor.name == params['Model']?.toString()) {
          final updatedFactor = TempFactor(
            name: params['name'] ?? params['Model'] ?? factor.name,
            value: (params['value'] as num?)?.toDouble() ?? (params['defaultValue'] as num?)?.toDouble() ?? (params['price'] as num?)?.toDouble() ?? factor.value,
            addedCount: params['addedCount'] ?? params['usageCount'] ?? factor.addedCount,
          );
          
          await factorsBox.put(key, updatedFactor);
          
          // 检查是否是仅addedCount字段的变化
          bool isOnlyAddedCountChange = _isOnlyAddedCountChangedForFactor(factor, params);
          
          // 如果不是仅addedCount的变化，则更新数据版本时间戳
          if (!isOnlyAddedCountChange) {
            updateFactorsTimestamp();
            print('系数数据版本已更新（非addedCount字段变化）: ${updatedFactor.name}');
          } else {
            print('仅addedCount更新，不更新系数数据版本: ${updatedFactor.name}');
          }
          
          return Response.ok(
            json.encode({
              'success': true, 
              'data': updatedFactor.toJson(),
              'timestamp': _lastFactorsUpdate  // 返回当前系数数据的时间戳
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }
      
      return Response.notFound(
        json.encode({'success': false, 'error': '未找到对应的系数'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('更新系数失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 删除系数
  Future<Response> _handleDeleteTempFactor(Request request, String id) async {
    try {
      final factorsBox = Hive.box<TempFactor>('temp_factors');
      
      bool found = false;
      for (final key in factorsBox.keys) {
        final factor = factorsBox.get(key)!;
        
        // 检查name是否匹配
        if (factor.name == id || 
            factor.name == Uri.decodeComponent(id)) {  // 解码URL参数
          await factorsBox.delete(key);
          found = true;
          break;
        }
      }
      
      if (found) {
        // 更新系数数据版本时间戳
        updateFactorsTimestamp();
        
        return Response.ok(
          json.encode({
            'success': true,
            'timestamp': _lastFactorsUpdate  // 返回当前系数数据的时间戳
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的系数'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('删除系数失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
